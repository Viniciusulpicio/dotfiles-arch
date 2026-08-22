#!/usr/bin/env python3
import os
import sys
import subprocess
import shutil

SUDO_PASS = os.environ.get("SUDO_PASS", "")

def run_cmd(cmd, use_sudo=False, check=False):
    if use_sudo:
        if isinstance(cmd, str):
            cmd = f"echo '{SUDO_PASS}' | sudo -S {cmd}"
        else:
            cmd = ["sudo", "-S"] + cmd
    
    print(f"--> Executing: {cmd if isinstance(cmd, str) else ' '.join(cmd)}")
    if use_sudo and isinstance(cmd, list):
        proc = subprocess.run(cmd, input=f"{SUDO_PASS}\n", text=True, capture_output=True)
    elif use_sudo and isinstance(cmd, str):
        proc = subprocess.run(cmd, shell=True, text=True, capture_output=True)
    else:
        if isinstance(cmd, str):
            proc = subprocess.run(cmd, shell=True, text=True, capture_output=True)
        else:
            proc = subprocess.run(cmd, text=True, capture_output=True)
            
    if proc.returncode != 0 and check:
        print(f"❌ Command failed: {proc.stderr}")
    else:
        if proc.stdout.strip():
            print(proc.stdout.strip())
    return proc

def read_pkg_list(filepath):
    if not os.path.exists(filepath):
        return set()
    with open(filepath, 'r') as f:
        return set(line.strip() for line in f if line.strip() and not line.startswith('#'))

def main():
    print("=== STARTING FULL ARCH RICE & DEV RESTORATION ===")
    
    # 1. Enable multilib in /etc/pacman.conf if disabled
    pacman_conf = "/etc/pacman.conf"
    if os.path.exists(pacman_conf):
        with open(pacman_conf, 'r') as f:
            content = f.read()
        if "#[multilib]" in content:
            print("Enabling multilib...")
            run_cmd("sed -i '/^#\\[multilib\\]/,/^#Include/ s/^#//' /etc/pacman.conf", use_sudo=bool(SUDO_PASS))
    
    # 2. Update keyring & yay
    if shutil.which("pacman"):
        run_cmd("pacman -Sy --noconfirm archlinux-keyring", use_sudo=bool(SUDO_PASS))
    
    if shutil.which("yay") is None and shutil.which("pacman"):
        run_cmd("pacman -S --needed --noconfirm base-devel git python-pipx wget unzip", use_sudo=bool(SUDO_PASS))
        run_cmd("rm -rf /tmp/yay && git clone https://aur.archlinux.org/yay.git /tmp/yay && cd /tmp/yay && makepkg -si --noconfirm")

    dotfiles_dir = os.path.dirname(os.path.abspath(__file__))
    pkg_lists_dir = os.path.join(dotfiles_dir, "pkg-lists")
    home = os.path.expanduser("~")

    # 3. Packages installation
    if shutil.which("pacman"):
        res_inst = subprocess.run(['pacman', '-Qq'], capture_output=True, text=True)
        installed_pkgs = set(res_inst.stdout.splitlines())
        res_repo = subprocess.run(['pacman', '-Slq'], capture_output=True, text=True)
        repo_pkgs = set(res_repo.stdout.splitlines())

        native_pkgs = read_pkg_list(os.path.join(pkg_lists_dir, "pacman_native.txt"))
        aur_pkgs = read_pkg_list(os.path.join(pkg_lists_dir, "aur_packages.txt"))

        missing_pacman = [p for p in sorted(list(native_pkgs - installed_pkgs)) if p in repo_pkgs]
        missing_aur = [p for p in sorted(list(aur_pkgs - installed_pkgs)) if p not in repo_pkgs and not p.endswith("-debug")]

        if missing_pacman:
            print(f"Installing {len(missing_pacman)} native packages...")
            batch_size = 40
            for i in range(0, len(missing_pacman), batch_size):
                chunk = missing_pacman[i:i+batch_size]
                run_cmd(f"pacman -S --needed --noconfirm {' '.join(chunk)}", use_sudo=bool(SUDO_PASS))

        if missing_aur and shutil.which("yay"):
            print(f"Installing {len(missing_aur)} AUR packages...")
            for pkg in missing_aur:
                cmd = f"echo '{SUDO_PASS}' | yay -S --needed --noconfirm {pkg}" if SUDO_PASS else f"yay -S --needed --noconfirm {pkg}"
                subprocess.run(cmd, shell=True)

    # 4. Restore Configs and Files
    print("\n--- Restoring Rice, Assets and Configs ---")
    os.makedirs(f"{home}/.config", exist_ok=True)
    subprocess.run(f"cp -rf {dotfiles_dir}/.config/* {home}/.config/", shell=True)

    os.makedirs(f"{home}/.local/bin", exist_ok=True)
    if os.path.exists(f"{dotfiles_dir}/.local/bin"):
        subprocess.run(f"cp -rf {dotfiles_dir}/.local/bin/* {home}/.local/bin/", shell=True)
        subprocess.run(f"chmod +x {home}/.local/bin/* 2>/dev/null", shell=True)

    os.makedirs(f"{home}/.local/share", exist_ok=True)
    if os.path.exists(f"{dotfiles_dir}/.local/share"):
        subprocess.run(f"cp -rf {dotfiles_dir}/.local/share/* {home}/.local/share/", shell=True)

    if os.path.exists(f"{dotfiles_dir}/Pictures"):
        os.makedirs(f"{home}/Pictures", exist_ok=True)
        subprocess.run(f"cp -rf {dotfiles_dir}/Pictures/* {home}/Pictures/", shell=True)

    for dotf in [".zshrc", ".p10k.zsh", ".bashrc", ".bash_profile", ".profile", ".imwheelrc", ".gitconfig", ".nvidia-settings-rc"]:
        if os.path.exists(f"{dotfiles_dir}/{dotf}"):
            shutil.copy(f"{dotfiles_dir}/{dotf}", f"{home}/{dotf}")

    if os.path.exists(f"{dotfiles_dir}/.rion-dotfiles"):
        subprocess.run(f"cp -rf {dotfiles_dir}/.rion-dotfiles {home}/", shell=True)

    if os.path.exists(f"{dotfiles_dir}/grub2-themes"):
        subprocess.run(f"cp -rf {dotfiles_dir}/grub2-themes {home}/", shell=True)

    if os.path.exists(f"{dotfiles_dir}/.oh-my-zsh/custom") and os.path.exists(f"{home}/.oh-my-zsh"):
        subprocess.run(f"cp -rf {dotfiles_dir}/.oh-my-zsh/custom/* {home}/.oh-my-zsh/custom/", shell=True)

    # 5. GNOME dconf
    print("\n--- Restoring GNOME dconf settings ---")
    gnome_dir = f"{dotfiles_dir}/gnome-settings"
    if os.path.exists(f"{gnome_dir}/full-backup.dconf"):
        subprocess.run(f"dconf load / < {gnome_dir}/full-backup.dconf", shell=True)
    if os.path.exists(f"{gnome_dir}/github-extensions.dconf"):
        subprocess.run(f"dconf load /com/github/ < {gnome_dir}/github-extensions.dconf", shell=True)
    if os.path.exists(f"{gnome_dir}/gnome-extensions.dconf"):
        subprocess.run(f"dconf load /org/gnome/shell/extensions/ < {gnome_dir}/gnome-extensions.dconf", shell=True)

    # Enable GNOME extensions
    ext_list = read_pkg_list(os.path.join(pkg_lists_dir, "gnome_extensions_enabled.txt"))
    for ext in ext_list:
        subprocess.run(f"gnome-extensions enable '{ext}' 2>/dev/null", shell=True)

    print("\n=== RESTORATION COMPLETE! ===")

if __name__ == "__main__":
    main()
