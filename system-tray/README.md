# System Tray — Gerenciador Dinâmico de Serviços Linux

Painel de controle visual e dinâmico para serviços do Linux (estilo XAMPP, mas moderno e para todo o sistema).

---

## 🎯 Principais Funcionalidades

1. **Varredura 100% Dinâmica:**
   - Detecta todos os serviços instalados na sua máquina via `systemd` em tempo real.
   - Sem serviços fixos/hardcoded: novos bancos, servidores ou containers instalados aparecem automaticamente.

2. **Economia de Recursos & Memória:**
   - Chave seletora **"Iniciar com o PC"** (`enable`/`disable`): desative bancos e servidores do boot para ligar o computador voando baixo sem gastar RAM.
   - Ligue o **MariaDB, Docker, PostgreSQL, Apache ou Ollama** com 1 clique apenas quando for usar, e desligue ao terminar.

3. **Bandeja do Sistema (System Tray):**
   - Ícone na barra do GNOME com menu de acesso rápido para ligar/desligar seus serviços favoritos e abrir o painel completo.

4. **Monitoramento & Produtividade:**
   - Consumo de memória RAM em tempo real de cada serviço.
   - Visualizador de logs com 1 clique direto na interface.
   - Busca instantânea e sistema de Favoritos (⭐).
   - Botão para parar todos os serviços de desenvolvimento com um clique.

---

## 🚀 Como Executar

### Opção 1: Pelo Menu de Aplicativos
Basta pesquisar por **"System Tray"** no menu de aplicativos do seu sistema (GNOME/KDE/Rofi).

### Opção 2: Pelo Terminal
```bash
python3 ~/system-tray/app.py
```

### Opção 3: Iniciar Automaticamente com o Sistema (Opcional)
Se você quiser que o **System Tray** fique sempre aberto na sua barra perto do relógio:
1. Abra o aplicativo **Aplicativos de Inicialização** (*Startup Applications*) do GNOME.
2. Adicione um novo item com o comando:
   ```bash
   python3 /home/vinicius/system-tray/app.py --no-browser
   ```

---

## 🛠️ Comandos Úteis

* **Modo Apenas Web:** `python3 app.py --web-only`
* **Definir porta:** `python3 app.py --port 5000`
* **Configurar permissões sem senha:** `bash setup-permissions.sh`
