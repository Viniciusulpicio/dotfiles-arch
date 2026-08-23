import json
import os
import re
import subprocess
from pathlib import Path

CONFIG_DIR = Path.home() / ".config" / "system-tray"
FAVORITES_FILE = CONFIG_DIR / "favorites.json"

DEV_KEYWORDS = {
    "database": ["maria", "mysql", "postgres", "redis", "mongo", "cockroach", "memcached", "couchdb", "cassandra", "clickhouse", "sqlite"],
    "web": ["httpd", "apache", "nginx", "caddy", "lighttpd", "php", "gunicorn", "uvicorn", "tomcat", "node", "pm2"],
    "containers": ["docker", "containerd", "podman", "k3s", "minikube", "microk8s", "crio"],
    "ai_ml": ["ollama", "vllm", "localai", "comfyui", "jupyter", "torch"],
    "network": ["sshd", "ssh", "openvpn", "wireguard", "tailscale", "zerotier", "dnsmasq", "samba", "wsdd", "smb", "nfs"],
    "dev_tools": ["jenkins", "gitlab", "gitea", "code-server", "cockpit", "pgadmin", "rabbitmq", "kafka", "elasticsearch", "grafana", "prometheus"]
}

KNOWN_PORTS = {
    "mariadb": "3306",
    "mysql": "3306",
    "mysqld": "3306",
    "postgresql": "5432",
    "postgres": "5432",
    "httpd": "80, 443",
    "apache2": "80, 443",
    "nginx": "80, 443",
    "caddy": "80, 443",
    "redis": "6379",
    "redis-server": "6379",
    "mongodb": "27017",
    "mongod": "27017",
    "ollama": "11434",
    "sshd": "22",
    "ssh": "22",
    "cockpit": "9090",
    "jenkins": "8080",
    "gitea": "3000",
    "gitlab": "80, 443",
    "rabbitmq": "5672, 15672",
    "kafka": "9092",
    "elasticsearch": "9200",
    "grafana": "3000",
    "prometheus": "9090",
    "dnsmasq": "53",
    "cups": "631",
    "smbd": "445, 139",
    "nmbd": "137, 138"
}

PTBR_DESCRIPTIONS = {
    # Desenvolvimento PHP, Node.js & Web
    "httpd": "Servidor Web Apache (HTTPD) para hospedar sites e APIs em PHP.",
    "apache2": "Servidor Web Apache para hospedar sites e aplicações em PHP.",
    "php-fpm": "Gerenciador de Processos FastCGI para executar scripts PHP no servidor Web.",
    "nginx": "Servidor Web e Proxy Reverso de alta performance para aplicações Node.js e PHP.",
    "caddy": "Servidor Web moderno com suporte automático a certificados HTTPS para Node.js e PHP.",
    
    # Bancos de Dados para Node.js e PHP
    "mariadb": "Banco de Dados Relacional SQL (MariaDB/MySQL) para aplicações PHP e Node.js.",
    "mysql": "Banco de Dados Relacional MySQL para desenvolvimento PHP e Node.js.",
    "mysqld": "Daemon do Servidor de Banco de Dados Relacional MySQL.",
    "postgresql": "Banco de Dados Relacional PostgreSQL de alto desempenho para Node.js e PHP.",
    "postgres": "Servidor de Banco de Dados Objeto-Relacional PostgreSQL.",
    "redis": "Banco de dados NoSQL em memória para cache rápido e filas em Node.js e PHP.",
    "redis-server": "Servidor de Cache e Banco de Dados em Memória Redis.",
    "mongodb": "Banco de dados NoSQL orientado a documentos JSON para aplicações Node.js.",
    "mongod": "Serviço principal do Banco de Dados MongoDB.",
    "memcached": "Sistema de cache de objetos em memória de alto desempenho.",
    "cassandra": "Banco de dados NoSQL distribuído para grandes volumes de dados.",
    "clickhouse-server": "Banco de dados colunar orientado a alta performance e analytics.",

    # Containers & Virtualização
    "docker": "Gerenciador de Containers Docker (para rodar instâncias de Node, PHP, Redis e Mongo).",
    "docker.socket": "Socket de ativação e comunicação com o daemon do Docker.",
    "containerd": "Mecanismo de baixo nível para execução de containers Docker.",
    "podman": "Gerenciador de containers sem necessidade de root (alternativa ao Docker).",
    "libvirtd": "Gerenciador de Máquinas Virtuais (KVM, QEMU).",
    "virtlogd": "Serviço de registro de logs para máquinas virtuais.",
    "vboxweb": "Serviço de gerenciamento web do VirtualBox.",

    # Inteligência Artificial & Ferramentas Dev
    "ollama": "Servidor local para execução de Inteligência Artificial e Modelos LLM (Llama, Deepseek).",
    "jenkins": "Servidor de automação de integração contínua (CI/CD).",
    "gitlab-runner": "Executor de pipelines automatizadas do GitLab CI.",
    "gitea": "Servidor Git self-hosted leve para repositórios de código.",
    "rabbitmq": "Servidor de mensageria e filas de mensagens (Message Broker).",
    "kafka": "Plataforma de streaming de eventos e mensageria distribuída.",
    "elasticsearch": "Motor de busca distribuído e análise de dados em tempo real.",
    "grafana": "Plataforma de dashboards visuais e monitoramento de métricas.",
    "prometheus": "Sistema de coleta de métricas e monitoramento de sistemas.",

    # Rede, Acesso Remoto & Compartilhamento
    "sshd": "Servidor SSH para acesso remoto seguro via terminal ou VS Code Remote.",
    "ssh": "Serviço de Conexão Segura SSH.",
    "sshdgenkeys": "Geração automática de chaves criptográficas para o servidor SSH.",
    "tailscale": "VPN de rede privada mesh para acessar a máquina remotamente de qualquer lugar.",
    "tailscaled": "Daemon de gerenciamento da rede privada Tailscale.",
    "wireguard": "Protocolo e túnel de VPN seguro, moderno e ultrarrápido.",
    "openvpn": "Servidor e cliente de conexões de túnel VPN OpenVPN.",
    "samba": "Serviço de compartilhamento de arquivos e pastas com máquinas Windows e Linux na rede.",
    "smbd": "Daemon de compartilhamento de arquivos SMB / Samba na rede local.",
    "nmbd": "Servidor de nomes NetBIOS do Samba para identificação na rede.",
    "wsdd": "Descoberta automática de computadores Linux no Windows Explorer da rede local.",
    "wsdd-discovery": "Serviço de descoberta WSD para visualização em redes Windows.",
    "dnsmasq": "Servidor DNS e DHCP leve para redes locais e containers.",
    "avahi-daemon": "Descoberta automática de dispositivos e serviços na rede local (mDNS/Zeroconf).",
    "cups": "Sistema de gerenciamento e fila de impressão (impressoras locais e de rede).",
    "cups-browsed": "Descoberta de impressoras compartilhadas na rede local.",

    # Segurança & Sistema Operacional
    "ufw": "Firewall de segurança simples (Uncomplicated Firewall) para proteção de portas.",
    "firewalld": "Gerenciador dinâmico de firewall do Linux.",
    "cronie": "Agendador de tarefas periódicas e scripts automatizados (Cron).",
    "crond": "Daemon do agendador de tarefas automatizadas Cron.",
    "bluetooth": "Gerenciador de conexões, pareamento e dispositivos Bluetooth (fones, teclados).",
    "NetworkManager": "Gerenciador principal de conexões de rede Wi-Fi, Ethernet e VPN do sistema.",
    "wpa_supplicant": "Autenticador de segurança para redes sem fio Wi-Fi (WPA/WPA2/WPA3).",
    "accounts-daemon": "Gerenciador de contas, perfis e fotos de usuários do sistema operacional.",
    "upower": "Serviço de monitoramento de bateria e gerenciamento de energia.",
    "udisks2": "Gerenciador de montagem e leitura de discos, pendrives e partições.",
    "ananicy-cpp": "Otimizador automático de prioridade de CPU para jogos e aplicações pesadas.",
    "auto-cpufreq": "Otimizador automático de frequência de CPU para economia de bateria e performance.",
    "auto-power-profile": "Ajuste automático de perfil de energia (conectado na tomada vs bateria).",
    "archlinux-keyring-wkd-sync": "Sincronizador automático de chaves de assinatura do Arch Linux.",
    "alsa-restore": "Restauração e salvamento dos níveis de volume de áudio da placa de som.",
    "alsa-state": "Gerenciador do estado dos canais de som do ALSA.",
    "auditd": "Serviço de auditoria e monitoramento de eventos de segurança do kernel.",
    "audit-rules": "Carregamento de regras de auditoria de segurança.",
    "systemd-resolved": "Resolução de nomes de domínio DNS e navegação na internet.",
    "systemd-timesyncd": "Sincronizador automático do relógio do sistema com servidores NTP na internet.",
    "systemd-journald": "Coletor e gravador de logs de todo o sistema operacional.",
    "systemd-logind": "Gerenciador de sessões de login de usuários, suspensão e desligamento.",
    "systemd-networkd": "Gerenciador leve de interfaces de rede do systemd.",
    "systemd-oomd": "Monitor de memória que previne travamentos matando processos com vazamento de RAM.",
    "systemd-udevd": "Gerenciador de eventos e detecção de novos dispositivos de hardware (USB, placas).",
    "systemd-homed": "Gerenciador de diretórios pessoais e criptografia de usuários.",
    "systemd-userdbd": "Mecanismo de consulta de usuários e grupos do sistema.",
    "systemd-zram-setup": "Configuração de memória SWAP compactada na RAM (ZRAM).",
    "usbmuxd": "Comunicação USB com dispositivos Apple (iPhone/iPad).",
    "cockpit": "Painel de controle web para administração visual do Linux.",
    "plymouth-start": "Tela de inicialização gráfica e animação de boot (Splash screen).",
    "plymouth-quit": "Encerramento da animação gráfica de boot ao carregar a tela de login.",
    "plymouth-quit-wait": "Aguardando encerramento da tela de splash de inicialização.",
    "tlp": "Otimizador avançado de economia de bateria para notebooks.",
    "tuned": "Ajuste dinâmico de performance e economia de energia do sistema.",
    "syslog": "Serviço padrão de registro de logs do sistema operacional.",
    "system76-power": "Gerenciamento de gráficos híbridos e perfis de energia System76.",
    "rc-local": "Script de inicialização personalizada do sistema."
}

SYSTEM_PREFIXES = ("systemd-", "dbus-", "user-", "alsa-", "archlinux-", "kmod-")

DEFAULT_DEV_FAVORITES = [
    "httpd.service",
    "mariadb.service",
    "postgresql.service",
    "docker.service",
    "php-fpm.service",
    "nginx.service",
    "redis.service",
    "mongodb.service",
    "ollama.service",
    "sshd.service"
]

def ensure_config_dir():
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    if not FAVORITES_FILE.exists():
        FAVORITES_FILE.write_text(json.dumps(DEFAULT_DEV_FAVORITES, indent=2))

def get_favorites():
    ensure_config_dir()
    try:
        raw = json.loads(FAVORITES_FILE.read_text())
        return [x if x.endswith(".service") else f"{x}.service" for x in raw]
    except Exception:
        return DEFAULT_DEV_FAVORITES

def save_favorites(favorites):
    ensure_config_dir()
    normalized = list(set([x if x.endswith(".service") else f"{x}.service" for x in favorites]))
    FAVORITES_FILE.write_text(json.dumps(normalized, indent=2))

def toggle_favorite(service_name):
    clean_name = service_name if service_name.endswith(".service") else f"{service_name}.service"
    favs = set(get_favorites())
    if clean_name in favs:
        favs.remove(clean_name)
        is_fav = False
    else:
        favs.add(clean_name)
        is_fav = True
    save_favorites(list(favs))
    return is_fav

def get_port_for_service(name):
    clean = name.replace(".service", "").replace(".socket", "").lower()
    if clean in KNOWN_PORTS:
        return KNOWN_PORTS[clean]
    for k, v in KNOWN_PORTS.items():
        if k in clean:
            return v
    return "-"

def get_portuguese_description(name, raw_desc=""):
    clean_name = name.replace(".service", "").replace(".socket", "").strip()
    name_lower = clean_name.lower()
    
    if name_lower in PTBR_DESCRIPTIONS:
        return PTBR_DESCRIPTIONS[name_lower]
    if clean_name in PTBR_DESCRIPTIONS:
        return PTBR_DESCRIPTIONS[clean_name]
    
    base_prefix = clean_name.split("@")[0].split("-")[0].lower()
    if base_prefix in PTBR_DESCRIPTIONS:
        return PTBR_DESCRIPTIONS[base_prefix]

    for key, pt_desc in PTBR_DESCRIPTIONS.items():
        if key.lower() == name_lower or (len(key) > 3 and key.lower() in name_lower):
            return pt_desc

    if raw_desc and raw_desc != name:
        d = raw_desc
        translations = [
            ("database server", "servidor de banco de dados"),
            ("Database Server", "Servidor de Banco de Dados"),
            ("database", "banco de dados"),
            ("Application Container Engine", "Mecanismo de Execução de Containers"),
            ("Save/Restore Sound Card State", "Salva e Restaura o Estado da Placa de Som"),
            ("Security Audit Logging Service", "Serviço de Registro de Auditoria de Segurança"),
            ("Load Audit Rules", "Carrega as Regras de Auditoria de Segurança"),
            ("Disk Manager", "Gerenciador de Discos e Partições"),
            ("User Login Management", "Gerenciamento de Login e Sessão de Usuários"),
            ("Network Management", "Gerenciamento de Conexões de Rede"),
            ("Network Name Resolution", "Resolução de Nomes de Domínio DNS"),
            ("Bluetooth service", "Serviço de Gerenciamento de Bluetooth"),
            ("Daemon for power management", "Serviço de Gerenciamento de Energia e Bateria"),
            ("WPA supplicant", "Autenticador de Redes Wi-Fi WPA"),
            ("Refresh existing keys", "Atualização de Chaves de Segurança"),
            ("Rule-based Manager for Device Events and Files", "Gerenciador de Dispositivos e Hardware (udev)"),
            ("Virtual Machine and Container Registration Service", "Registro de Máquinas Virtuais e Containers"),
            ("Journal Service", "Serviço de Coleta de Logs do Sistema (Journal)"),
            ("Load Kernel Modules", "Carregamento de Módulos e Drivers do Kernel"),
            ("Apply Kernel Variables", "Aplicação de Parâmetros do Kernel (sysctl)"),
            ("Create System Users", "Criação Automática de Usuários do Sistema"),
            ("Create Static Device Nodes", "Criação de Nós de Dispositivos em /dev"),
            ("Create System Files and Directories", "Criação de Arquivos e Diretórios Temporários do Sistema"),
            ("Coldplug All udev Devices", "Detecção e Inicialização de Dispositivos Conectados"),
            ("Flush Journal to Persistent Storage", "Gravação de Logs no Disco Rígido"),
            ("Remount Root and Kernel File Systems", "Remontagem de Sistemas de Arquivos do Sistema"),
            ("User Manager for UID", "Gerenciador de Sessão do Usuário UID"),
            ("User Runtime Directory", "Diretório de Execução Temporário do Usuário"),
            ("Daemon for", "Serviço em segundo plano para"),
            ("daemon for", "serviço em segundo plano para"),
            ("Service for", "Serviço para"),
            ("service for", "serviço para"),
            ("Manager", "Gerenciador"),
            ("Service", "Serviço")
        ]
        for eng, pt in translations:
            d = d.replace(eng, pt)
        return d

    return f"Serviço do sistema ({name})."

def categorize_service(name, description=""):
    name_lower = name.lower()
    desc_lower = description.lower()
    
    if any(name_lower.startswith(prefix) for prefix in SYSTEM_PREFIXES):
        return "system", False

    for category, keywords in DEV_KEYWORDS.items():
        for kw in keywords:
            if kw in name_lower or kw in desc_lower:
                return category, True
    return "system", False

def get_companion_units(service_name):
    clean_name = service_name if service_name.endswith(".service") else f"{service_name}.service"
    base = clean_name.rsplit(".", 1)[0]
    units = [clean_name]

    socket_name = f"{base}.socket"
    try:
        proc = subprocess.run(["systemctl", "list-unit-files", socket_name, "--no-legend"], capture_output=True, text=True)
        if proc.returncode == 0 and socket_name in proc.stdout:
            units.append(socket_name)
    except Exception:
        pass

    return units

def run_cmd(cmd, timeout=20):
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        if res.returncode == 0:
            return True, res.stdout.strip()
        
        err_msg = res.stderr.strip() or res.stdout.strip()
        if "interactive authentication" in err_msg.lower() or "permission" in err_msg.lower() or "access denied" in err_msg.lower():
            pk_cmd = ["pkexec"] + cmd
            pk_res = subprocess.run(pk_cmd, capture_output=True, text=True, timeout=timeout)
            if pk_res.returncode == 0:
                return True, pk_res.stdout.strip()
            return False, pk_res.stderr.strip() or pk_res.stdout.strip()
        return False, err_msg
    except subprocess.TimeoutExpired:
        return False, "Tempo limite esgotado ao executar o comando."
    except Exception as e:
        return False, str(e)

def list_all_services():
    favorites = set(get_favorites())
    
    unit_files = {}
    try:
        proc = subprocess.run(["systemctl", "list-unit-files", "--type=service", "-o", "json"], capture_output=True, text=True)
        if proc.returncode == 0:
            for item in json.loads(proc.stdout):
                unit_name = item.get("unit_file")
                if unit_name:
                    unit_files[unit_name] = {
                        "unit_file": unit_name,
                        "boot_state": item.get("state", "disabled"),
                        "preset": item.get("preset", "")
                    }
    except Exception:
        pass

    runtime_units = {}
    try:
        proc = subprocess.run(["systemctl", "list-units", "--type=service", "--all", "-o", "json"], capture_output=True, text=True)
        if proc.returncode == 0:
            for item in json.loads(proc.stdout):
                unit_name = item.get("unit")
                if unit_name:
                    runtime_units[unit_name] = {
                        "active": item.get("active", "inactive"),
                        "sub": item.get("sub", "dead"),
                        "load": item.get("load", "loaded"),
                        "description": item.get("description", "")
                    }
    except Exception:
        pass

    all_names = set(unit_files.keys()).union(set(runtime_units.keys()))
    services = []

    for name in all_names:
        if name.endswith("@.service"):
            continue
            
        uf = unit_files.get(name, {})
        ru = runtime_units.get(name, {})
        
        raw_description = ru.get("description") or name.replace(".service", "")
        description_pt = get_portuguese_description(name, raw_description)
        category, is_dev = categorize_service(name, f"{raw_description} {description_pt}")
        
        boot_state = uf.get("boot_state", "disabled")
        is_boot_enabled = boot_state in ("enabled", "enabled-runtime")
        
        active_state = ru.get("active", "inactive")
        sub_state = ru.get("sub", "dead")
        
        is_running = active_state == "active" and sub_state == "running"
        is_active = active_state == "active"
        
        is_favorite = name in favorites or name.replace(".service", "") in favorites
        port = get_port_for_service(name)
        
        services.append({
            "name": name,
            "display_name": name.replace(".service", ""),
            "description": description_pt,
            "raw_description": raw_description,
            "active_state": active_state,
            "sub_state": sub_state,
            "is_running": is_running,
            "is_active": is_active,
            "boot_state": boot_state,
            "is_boot_enabled": is_boot_enabled,
            "category": category,
            "is_dev": is_dev,
            "is_favorite": is_favorite,
            "port": port,
            "memory_bytes": 0,
            "memory_mb": 0,
            "pid": 0
        })

    def sort_key(s):
        fav_rank = 0 if s["is_favorite"] else 1
        dev_rank = 0 if s["is_dev"] else 1
        active_rank = 0 if s["is_active"] else 1
        return (fav_rank, dev_rank, active_rank, s["name"].lower())

    services.sort(key=sort_key)
    return services

def get_service_details(name):
    clean_name = name if name.endswith(".service") else f"{name}.service"
    cmd = [
        "systemctl", "show", clean_name,
        "--property=MemoryCurrent,CPUUsageNSec,ActiveState,SubState,UnitFileState,Description,MainPID,ExecMainStartTimestamp"
    ]
    proc = subprocess.run(cmd, capture_output=True, text=True)
    details = {
        "name": clean_name,
        "memory_bytes": 0,
        "memory_mb": 0,
        "active_state": "inactive",
        "sub_state": "dead",
        "boot_state": "disabled",
        "description": "",
        "pid": 0,
        "started_at": "",
        "port": get_port_for_service(clean_name)
    }
    
    raw_description = ""
    if proc.returncode == 0:
        for line in proc.stdout.splitlines():
            if "=" in line:
                k, v = line.split("=", 1)
                k, v = k.strip(), v.strip()
                if k == "MemoryCurrent" and v.isdigit():
                    b = int(v)
                    if b < 18446744073709551615:
                        details["memory_bytes"] = b
                        details["memory_mb"] = round(b / (1024 * 1024), 1)
                elif k == "ActiveState":
                    details["active_state"] = v
                elif k == "SubState":
                    details["sub_state"] = v
                elif k == "UnitFileState":
                    details["boot_state"] = v
                elif k == "Description":
                    raw_description = v
                elif k == "MainPID" and v.isdigit():
                    details["pid"] = int(v)
                elif k == "ExecMainStartTimestamp":
                    details["started_at"] = v
                    
    details["description"] = get_portuguese_description(clean_name, raw_description)
    details["is_active"] = details["active_state"] == "active"
    details["is_running"] = details["active_state"] == "active" and details["sub_state"] == "running"
    details["is_boot_enabled"] = details["boot_state"] in ("enabled", "enabled-runtime")
    return details

def execute_action(service_name, action):
    valid_actions = ["start", "stop", "restart", "enable", "disable"]
    if action not in valid_actions:
        return False, f"Ação inválida: {action}"
    
    clean_name = service_name if service_name.endswith(".service") else f"{service_name}.service"
    
    if not re.match(r"^[a-zA-Z0-9_\-\.@]+$", clean_name):
        return False, "Nome de serviço inválido."

    companions = get_companion_units(clean_name)
    
    if action in ("stop", "disable"):
        cmd = ["systemctl", action] + companions
    elif action == "enable":
        cmd = ["systemctl", "enable"] + companions
    else:
        cmd = ["systemctl", action, clean_name]

    success, msg = run_cmd(cmd)
    return success, msg or f"Serviço {clean_name} {action} executado com sucesso."

def get_service_logs(service_name, lines=50):
    clean_name = service_name if service_name.endswith(".service") else f"{service_name}.service"
    cmd = ["journalctl", "-u", clean_name, "-n", str(lines), "--no-pager"]
    proc = subprocess.run(cmd, capture_output=True, text=True)
    return proc.stdout if proc.returncode == 0 else proc.stderr
