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
            # We pass SUDO_PASS via stdin
    
    print(f"--> Running: {cmd if isinstance(cmd, str) else ' '.join(cmd)}")
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
    if not SUDO_PASS:
        print("ERROR: SUDO_PASS environment variable is not set.")
        sys.exit(1)

    print("=== STARTING FULL ARCH RICE & DEV RESTORATION ===")
    
    # 1. Enable multilib in /etc/pacman.conf if disabled
    print("\n--- 1. Enabling multilib repository ---")
    pacman_conf = "/etc/pacman.conf"
    with open(pacman_conf, 'r') as f:
        content = f.read()
    if "#[multilib]" in content:
        print("Uncommenting [multilib] section in /etc/pacman.conf...")
        run_cmd("sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf", use_sudo=True)
    
    # 2. Update pacman keyring and database
    print("\n--- 2. Updating pacman keyring & system database ---")
    run_cmd("pacman -Sy --noconfirm archlinux-keyring", use_sudo=True)
    
    # 3. Ensure yay is installed
    print("\n--- 3. Checking AUR helper (yay) ---")
    if shutil.which("yay") is None:
        print("Installing base-devel, git, python-pipx, wget, unzip...")
        run_cmd("pacman -S --needed --noconfirm base-devel git python-pipx wget unzip", use_sudo=True)
        print("Building yay from AUR...")
        run_cmd("rm -rf /tmp/yay && git clone https://aur.archlinux.org/yay.git /tmp/yay && cd /tmp/yay && makepkg -si --noconfirm")

    # 4. Get currently installed packages
    res_inst = subprocess.run(['pacman', '-Qq'], capture_output=True, text=True)
    installed_pkgs = set(res_inst.stdout.splitlines())

    # Get available repo packages
    res_repo = subprocess.run(['pacman', '-Slq'], capture_output=True, text=True)
    repo_pkgs = set(res_repo.stdout.splitlines())

    dotfiles_dir = "/home/vinicius/dotfiles-arch"
    pkg_lists_dir = os.path.join(dotfiles_dir, "pkg-lists")

    native_list_1 = read_pkg_list(os.path.join(pkg_lists_dir, "pacman_native.txt"))
    native_list_2 = read_pkg_list(os.path.join(pkg_lists_dir, "native_list.txt"))
    aur_list_1 = read_pkg_list(os.path.join(pkg_lists_dir, "aur_packages.txt"))
    aur_list_2 = read_pkg_list(os.path.join(pkg_lists_dir, "aur_list.txt"))

    all_requested = native_list_1 | native_list_2 | aur_list_1 | aur_list_2
    missing_all = sorted(list(all_requested - installed_pkgs))

    missing_pacman = [p for p in missing_all if p in repo_pkgs]
    missing_aur = [p for p in missing_all if p not in repo_pkgs and not p.endswith("-debug")]

    print(f"\nFound {len(missing_pacman)} missing pacman packages and {len(missing_aur)} missing AUR packages.")

    # 5. Install Pacman Packages
    if missing_pacman:
        print("\n--- 4. Installing Native Pacman Packages ---")
        # Install in batches to avoid command length limits
        batch_size = 40
        for i in range(0, len(missing_pacman), batch_size):
            chunk = missing_pacman[i:i+batch_size]
            print(f"Installing pacman chunk {i//batch_size + 1}: {' '.join(chunk)}")
            run_cmd(f"pacman -S --needed --noconfirm {' '.join(chunk)}", use_sudo=True)

    # 6. Install AUR Packages
    if missing_aur:
        print("\n--- 5. Installing AUR Packages via yay ---")
        for pkg in missing_aur:
            print(f"Installing AUR package: {pkg}")
            # Note: yay shouldn't run directly as root, it uses sudo internally
            cmd = f"echo '{SUDO_PASS}' | yay -S --needed --noconfirm {pkg}"
            subprocess.run(cmd, shell=True)

    # 7. Install Flatpaks
    flatpak_list = read_pkg_list(os.path.join(pkg_lists_dir, "flatpak_list.txt")) | read_pkg_list(os.path.join(pkg_lists_dir, "flatpaks.txt"))
    if flatpak_list and shutil.which("flatpak"):
        print("\n--- 6. Installing Flatpaks ---")
        run_cmd("flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo")
        for fp in flatpak_list:
            print(f"Installing flatpak: {fp}")
            subprocess.run(f"flatpak install -y flathub {fp}", shell=True)

    # 8. Restore Configs and Files
    print("\n--- 7. Restoring Dotfiles & Config Files ---")
    home = "/home/vinicius"
    
    # .config
    os.makedirs(f"{home}/.config", exist_ok=True)
    subprocess.run(f"cp -rf {dotfiles_dir}/.config/* {home}/.config/", shell=True)

    # .local/bin
    os.makedirs(f"{home}/.local/bin", exist_ok=True)
    subprocess.run(f"cp -rf {dotfiles_dir}/.local/bin/* {home}/.local/bin/", shell=True)
    subprocess.run(f"chmod +x {home}/.local/bin/*", shell=True)

    # Pictures/Wallpaper
    os.makedirs(f"{home}/Pictures", exist_ok=True)
    if os.path.exists(f"{dotfiles_dir}/Pictures"):
        subprocess.run(f"cp -rf {dotfiles_dir}/Pictures/* {home}/Pictures/", shell=True)

    # Home files
    for dotf in [".zshrc", ".p10k.zsh", ".bashrc", ".profile"]:
        if os.path.exists(f"{dotfiles_dir}/{dotf}"):
            shutil.copy(f"{dotfiles_dir}/{dotf}", f"{home}/{dotf}")

    if os.path.exists(f"{dotfiles_dir}/.rion-dotfiles"):
        subprocess.run(f"cp -rf {dotfiles_dir}/.rion-dotfiles {home}/", shell=True)

    if os.path.exists(f"{dotfiles_dir}/grub2-themes"):
        subprocess.run(f"cp -rf {dotfiles_dir}/grub2-themes {home}/", shell=True)

    # Oh-my-zsh custom
    if os.path.exists(f"{dotfiles_dir}/.oh-my-zsh/custom") and os.path.exists(f"{home}/.oh-my-zsh"):
        subprocess.run(f"cp -rf {dotfiles_dir}/.oh-my-zsh/custom/* {home}/.oh-my-zsh/custom/", shell=True)

    # 9. Restore GNOME Settings (dconf)
    print("\n--- 8. Restoring GNOME dconf settings & enabling extensions ---")
    gnome_dir = f"{dotfiles_dir}/gnome-settings"
    if os.path.exists(f"{gnome_dir}/full-backup.dconf"):
        print("Loading full dconf backup...")
        subprocess.run(f"dconf load / < {gnome_dir}/full-backup.dconf", shell=True)
    elif os.path.exists(f"{gnome_dir}/org-gnome.dconf"):
        print("Loading org-gnome dconf backup...")
        subprocess.run(f"dconf load /org/gnome/ < {gnome_dir}/org-gnome.dconf", shell=True)
    
    if os.path.exists(f"{gnome_dir}/github-extensions.dconf"):
        subprocess.run(f"dconf load /com/github/ < {gnome_dir}/github-extensions.dconf", shell=True)

    # Enable GNOME extensions
    ext_list = read_pkg_list(os.path.join(pkg_lists_dir, "gnome_extensions_enabled.txt"))
    for ext in ext_list:
        subprocess.run(f"gnome-extensions enable '{ext}' 2>/dev/null", shell=True)

    # 10. Install VS Code Extensions
    print("\n--- 9. Installing VS Code Extensions ---")
    vscode_exts = read_pkg_list(os.path.join(pkg_lists_dir, "vscode_extensions.txt"))
    code_bin = shutil.which("code") or shutil.which("visual-studio-code")
    if code_bin and vscode_exts:
        for ext in vscode_exts:
            subprocess.run(f"{code_bin} --install-extension '{ext}' --force 2>/dev/null", shell=True)

    # 11. System Services Setup
    print("\n--- 10. Enabling & starting system services ---")
    run_cmd("npm install -g typescript", use_sudo=True)
    run_cmd("systemctl enable --now docker.service", use_sudo=True)
    run_cmd("usermod -aG docker vinicius", use_sudo=True)
    
    run_cmd("test -d /var/lib/mysql || mariadb-install-db --user=mysql --basedir=/usr --datadir=/var/lib/mysql", use_sudo=True)
    run_cmd("systemctl enable --now mariadb.service", use_sudo=True)
    run_cmd("systemctl enable --now postgresql.service", use_sudo=True)

    # Apply Pywal / WPG wallpaper if wpg is installed
    if shutil.which("wpg") and os.path.exists(f"{home}/Pictures/Wallpaper"):
        print("\n--- 11. Applying Wallpaper & Pywal theme ---")
        subprocess.run(f"wpg -s $(find {home}/Pictures/Wallpaper -type f | head -n 1) 2>/dev/null", shell=True)

    print("\n=== RESTORATION COMPLETE! REBOOT RECOMMENDED. ===")

if __name__ == "__main__":
    main()
