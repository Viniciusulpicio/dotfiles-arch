# Arch Linux GNOME Rice (Dotfiles)

Bem-vindo ao meu repositório de **Dotfiles**. Este projeto automatiza a configuração do meu ambiente de desenvolvimento e personalização (Rice) no **Arch Linux com GNOME**.

Ele configura um ambiente completo com **Tiling Shell**, tema dinâmico (**Pywal/Rion**), terminal ZSH e toda a minha stack de desenvolvimento.

![Arch Linux](https://img.shields.io/badge/Arch_Linux-1793D1?style=for-the-badge&logo=arch-linux&logoColor=white)
![GNOME](https://img.shields.io/badge/GNOME-4a86cf?style=for-the-badge&logo=gnome&logoColor=white)
![Shell Script](https://img.shields.io/badge/Shell_Script-121011?style=for-the-badge&logo=gnu-bash&logoColor=white)

---

## Demonstração (Showcase)

https://github.com/user-attachments/assets/0997c15e-19ce-4ad6-a97d-360dcdf87058


> **Destaques Visuais:**
> *  **WPGTK/Pywal:** Cores geradas automaticamente pelo wallpaper.
> *  **ZSH Powerlevel10k:** Terminal rápido e informativo.
> *  **Tiling Window:** Organização automática de janelas.
> *  **Monitoramento:** Conky e Fastfetch integrados.

---

##  Stack de Softwares

O script de instalação baixa e configura automaticamente as seguintes ferramentas:

###  DevTools (Desenvolvimento)
| Ferramenta | Descrição |
| :--- | :--- |
| **VS Code** | Editor principal (Extensões + Settings sincronizados). |
| **Docker** | Containerização (com Docker Compose). |
| **Node.js** | Ambiente JavaScript (`npm` + `typescript` global). |
| **Git** | Controle de versão. |
| **MariaDB** | Servidor de Banco de Dados (MySQL drop-in replacement). |
| **PostgreSQL** | Servidor de Banco de Dados Relacional. |
| **Workbench** | MySQL Workbench (via AUR). |
| **Postman** | Teste de APIs. |
| **Notion** | Organização e notas (via AUR `notion-app-electron`). |
| **Terminal** | **ZSH** + **Oh-My-Zsh** + Tema Powerlevel10k. |

###  Games (Launchers)
* **Steam** (Nativo)
* **Heroic Games Launcher** (Epic/GOG)
* *(Jogos não são baixados automaticamente, apenas os launchers)*

###  Comunicação & Mídia
* **Discord**
* **TeamSpeak 3**
* **Spotify** (com Spicetify)
* **OBS Studio** (Streaming/Gravação)
* **VLC** (Player de Vídeo)

###  Navegação
* **Google Chrome**
* **Firefox**
* **Tor**

---

## Atalhos de Teclado (Keybindings)

Estes são os atalhos personalizados configurados no GNOME (`dconf`):

| Ação | Atalho | Comando |
| :--- | :--- | :--- |
| **File Manager** | `Super + E` | `nautilus` |
| **Terminal** | `Alt + Q` | *(Terminal Padrão)* |
| **WezTerm** | `Super + T` | `wezterm` |
| **Launcher (Menu)** | `Alt + F` | `wofi --show drun` |
| **Menu de Saída** | `Alt + L` | `wlogout` |
| **Wallpaper Picker** | `Alt + W` | `~/.local/bin/wallpaper-picker.sh` |
| **Tiling (Janelas)** | *Mouse* | Arraste para as bordas (Tiling Assistant) |
| **Notas** | `Super + N` | Abre um Bloco de notas para rapida anotacao |

> **Nota:** `Super` é a tecla "Windows".

---

##  Instalação

Para replicar este ambiente em uma instalação limpa do Arch Linux (com GNOME):

1. **Instale o `git` (se não tiver):**
    ```bash
    sudo pacman -S git
    ```

2. **Clone o repositório:**
    ```bash
    git clone [https://github.com/Viniciusulpicio/dotfiles-arch.git](https://github.com/Viniciusulpicio/dotfiles-arch.git)
    cd dotfiles-arch
    ```

3. **Execute o Instalador:**
    ```bash
    chmod +x install.sh
    ./install.sh
    ```

☕ **Vá tomar um café!** O script irá:
* Atualizar o sistema.
* Instalar `yay` (AUR Helper).
* Baixar todos os pacotes listados acima.
* Restaurar configurações (`.config`, `.zshrc`, etc).
* Configurar temas, ícones e extensões do GNOME.

---

##  Pós-Instalação (Importante)

Após o script finalizar e você reiniciar o computador, verifique:

1. **Configurar Clima (Conky):**
    * Edite o arquivo `~/.config/conky/weather.conf` (ou `.sh`).
    * Insira sua **API Key** do OpenWeatherMap e o ID da sua cidade.

2. **Docker (Permissões):**
    * O script já adiciona seu usuário ao grupo docker, mas pode ser necessário fazer **Logout/Login** para funcionar sem `sudo`.
    * Teste com: `docker run hello-world`.

3. **Bancos de Dados:**
    * Os serviços (`mariadb`, `postgresql`) foram ativados.
    * Para o MariaDB, rode `sudo mysql_secure_installation` para definir a senha de root se necessário.

---
