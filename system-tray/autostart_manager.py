import configparser
import os
import re
import shutil
from pathlib import Path

USER_AUTOSTART_DIR = Path.home() / ".config" / "autostart"
SYS_AUTOSTART_DIR = Path("/etc/xdg/autostart")
SYS_APPS_DIRS = [
    Path.home() / ".local" / "share" / "applications",
    Path("/usr/share/applications")
]

def ensure_autostart_dir():
    USER_AUTOSTART_DIR.mkdir(parents=True, exist_ok=True)

def parse_desktop_file(filepath):
    try:
        config = configparser.ConfigParser(interpolation=None, strict=False)
        config.read(filepath, encoding="utf-8")
        if "Desktop Entry" not in config:
            return None
        
        entry = config["Desktop Entry"]
        name = entry.get("Name", filepath.stem)
        exec_cmd = entry.get("Exec", "")
        comment = entry.get("Comment", "")
        icon = entry.get("Icon", "application-x-executable")
        
        hidden = entry.get("Hidden", "false").lower() == "true"
        no_display = entry.get("NoDisplay", "false").lower() == "true"
        gnome_enabled = entry.get("X-GNOME-Autostart-enabled", "true").lower() != "false"
        
        is_enabled = (not hidden) and gnome_enabled and (not no_display)
        
        return {
            "filename": filepath.name,
            "path": str(filepath),
            "name": name,
            "exec": exec_cmd,
            "comment": comment,
            "icon": icon,
            "is_enabled": is_enabled,
            "is_user": filepath.parent == USER_AUTOSTART_DIR
        }
    except Exception:
        return None

def list_autostart_apps():
    ensure_autostart_dir()
    apps_dict = {}

    # 1. Read System autostart apps (/etc/xdg/autostart)
    if SYS_AUTOSTART_DIR.exists():
        for f in SYS_AUTOSTART_DIR.glob("*.desktop"):
            parsed = parse_desktop_file(f)
            if parsed:
                apps_dict[f.name] = parsed

    # 2. Read User autostart apps (~/.config/autostart) - overrides system
    for f in USER_AUTOSTART_DIR.glob("*.desktop"):
        parsed = parse_desktop_file(f)
        if parsed:
            apps_dict[f.name] = parsed

    apps_list = list(apps_dict.values())
    apps_list.sort(key=lambda x: (not x["is_enabled"], x["name"].lower()))
    return apps_list

def toggle_autostart_app(filename, enabled):
    ensure_autostart_dir()
    user_file = USER_AUTOSTART_DIR / filename
    sys_file = SYS_AUTOSTART_DIR / filename

    if not user_file.exists() and sys_file.exists():
        # Copy system file to user folder to override
        shutil.copy2(sys_file, user_file)

    if user_file.exists():
        try:
            config = configparser.ConfigParser(interpolation=None, strict=False)
            config.read(user_file, encoding="utf-8")
            if "Desktop Entry" not in config:
                config["Desktop Entry"] = {}
            
            config["Desktop Entry"]["Hidden"] = "false" if enabled else "true"
            config["Desktop Entry"]["X-GNOME-Autostart-enabled"] = "true" if enabled else "false"
            
            with open(user_file, "w", encoding="utf-8") as f:
                config.write(f, space_around_delimiters=False)
            return True, f"Aplicativo {'ativado' if enabled else 'desativado'} com sucesso."
        except Exception as e:
            return False, str(e)
            
    return False, "Arquivo não encontrado."

def delete_autostart_app(filename):
    ensure_autostart_dir()
    user_file = USER_AUTOSTART_DIR / filename
    sys_file = SYS_AUTOSTART_DIR / filename

    if user_file.exists():
        if sys_file.exists():
            # If it's overriding a system file, set Hidden=true instead of deleting
            return toggle_autostart_app(filename, False)
        else:
            try:
                user_file.unlink()
                return True, "Aplicativo removido da inicialização."
            except Exception as e:
                return False, str(e)
    elif sys_file.exists():
        return toggle_autostart_app(filename, False)
        
    return False, "Arquivo não encontrado."

def add_autostart_app(name, exec_cmd, comment="", icon="application-x-executable"):
    ensure_autostart_dir()
    safe_name = re.sub(r"[^a-zA-Z0-9_\-]", "_", name.lower()).strip("_") or "app"
    filename = f"{safe_name}.desktop"
    target_path = USER_AUTOSTART_DIR / filename
    
    # Avoid overwriting unexpected files
    counter = 1
    while target_path.exists():
        filename = f"{safe_name}_{counter}.desktop"
        target_path = USER_AUTOSTART_DIR / filename
        counter += 1

    content = f"""[Desktop Entry]
Type=Application
Version=1.0
Name={name}
Comment={comment}
Exec={exec_cmd}
Icon={icon or 'application-x-executable'}
Terminal=false
Hidden=false
X-GNOME-Autostart-enabled=true
"""
    try:
        target_path.write_text(content, encoding="utf-8")
        return True, "Aplicativo adicionado à inicialização com sucesso.", filename
    except Exception as e:
        return False, str(e), None

def list_installed_system_apps():
    installed = []
    seen_execs = set()

    for app_dir in SYS_APPS_DIRS:
        if not app_dir.exists():
            continue
        for f in app_dir.glob("*.desktop"):
            parsed = parse_desktop_file(f)
            if parsed and parsed["exec"] and parsed["name"]:
                clean_exec = parsed["exec"].split()[0]
                if clean_exec not in seen_execs:
                    seen_execs.add(clean_exec)
                    installed.append({
                        "name": parsed["name"],
                        "exec": parsed["exec"],
                        "comment": parsed["comment"],
                        "icon": parsed["icon"],
                        "filename": f.name
                    })

    installed.sort(key=lambda x: x["name"].lower())
    return installed
