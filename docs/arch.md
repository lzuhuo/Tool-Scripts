# instalar-arch.sh — Guia detalhado

Script de provisionamento para uma instalação limpa do **Arch Linux (x86_64)**.

## Arquivo principal

- `instalar-arch.sh` — instala e configura os programas.

```bash
chmod +x instalar-arch.sh
./instalar-arch.sh              # modo interativo (pergunta cada etapa)
./instalar-arch.sh -y           # sem perguntas
./instalar-arch.sh -n           # dry-run (simula, não altera nada)
./instalar-arch.sh --only pacman   # executa só um grupo
```

Grupos disponíveis em `--only`:
`pacman`, `yay`, `flatpak`, `extensions`, `dev`, `cleanup`.

Opções extras:
- `--no-upgrade` — pula o `pacman -Syu` (só instala o que falta)
- `--no-self-update` — não tenta atualizar o script pelo Git
- `--no-color` — desativa cores ANSI (útil para logs de CI/CD)
- `-v, --verbose` — mostra a saída do pacman/yay em tempo real (sem redirecionar)
- `-h, --help` — mostra ajuda completa

## Estratégia de instalação

Para cada aplicativo, a preferência é:

1. **Repositórios oficiais do Arch** (`core`/`extra`) — atualizam via pacman.
2. **AUR (Arch User Repository) via yay** — pacotes que não estão nos repositórios oficiais; também atualizam via yay.
3. **Flatpak/Flathub** — apenas para o que não tem pacote nativo confiável (extensível via `--only flatpak`).

### Pacotes dos repositórios oficiais (pacman)

| Aplicativo | Função |
|------------|--------|
| git, curl, wget | Ferramentas base |
| flameshot | Captura de tela |
| gnome-tweaks | Ajustes GNOME |
| gnome-browser-connector | Integração extensões GNOME |
| firefox | Navegador |
| flatpak | Suporte Flatpak |
| keepassxc | Gerenciador de senhas |
| pipewire + pulse/alsa/jack + wireplumber | Áudio moderno |
| openvpn + networkmanager-openvpn + networkmanager | VPN |
| ttf-liberation + xcb-util-cursor | Fontes e cursores |
| inetutils | Telnet, traceroute, etc. |

> **Nota:** `tilix` **não está nos repositórios oficiais** — instalado via AUR (ver abaixo).

### Pacotes AUR (via yay)

| Aplicativo | Pacote AUR |
|------------|------------|
| Google Chrome | `google-chrome` |
| Microsoft Edge | `microsoft-edge-stable-bin` |
| Zoom | `zoom` |
| Visual Studio Code | `visual-studio-code-bin` |
| DBeaver CE | `dbeaver-ce-bin` |
| Postman | `postman-bin` |
| Ulauncher | `ulauncher` |
| Free Download Manager | `freedownloadmanager-bin` |
| Ferdium | `ferdium-bin` |
| AnyDesk | `anydesk-bin` |
| RealVNC Viewer | `realvnc-vnc-viewer` |
| WinBox | `winbox` |
| Extension Manager | `extension-manager-git` |
| Tilix | `tilix` |

#### Extensões GNOME (via AUR)

| Extensão | Pacote AUR |
|----------|------------|
| Blur my Shell | `gnome-shell-extension-blur-my-shell` |
| Dash to Dock | `gnome-shell-extension-dash-to-dock` |
| Compiz Magic Lamp | `gnome-shell-extension-compiz-alike-magic-lamp-effect-git` |
| Compiz Windows Effect | `gnome-shell-extension-compiz-windows-effect-git` |
| Vitals | `gnome-shell-extension-vitals-git` |

> **Importante:** As extensões usam os nomes corretos do AUR (muitos com sufixo `-git`). Os nomes incorretos do script antigo (`magic-lamp`, `all-windows-srwp`, `show-desktop-button`) **não existem** no AUR e foram removidos.

### Flatpak (Flathub)

O array `FLATPAK_APPS` está vazio por padrão — os principais apps já são instalados via pacman/AUR. Use `--only flatpak` para instalar Flatpaks adicionais manualmente.

## Ferramentas de desenvolvimento

Instaladas no grupo `dev`, com as variáveis de ambiente persistidas em `~/.config/instalar-arch/env.sh` (carregado pelo `~/.bashrc`, `~/.zshrc`, `~/.profile`):

| Ferramenta | Versão/configuração |
|------------|---------------------|
| opencode | `~/.opencode/bin`; instalador `https://opencode.ai/install` |
| nvm | `NVM_VERSION` (padrão `v0.40.8`) + Node LTS |
| .NET SDK | `DOTNET_CHANNELS` (padrão `10.0` e `8.0`) em `~/.dotnet` |

As versões desejadas são configuradas no topo do script:

```bash
NVM_VERSION="v0.40.8"
NVM_NODE_VERSION="lts"      # "" para não instalar Node
DOTNET_CHANNELS=(10.0 8.0)  # canais LTS/STS instalados lado a lado
```

Para instalar outra versão do .NET depois (cai sempre em `~/.dotnet`):

```bash
dotnet-install --channel 9.0
dotnet-install --version 8.0.425
dotnet --list-sdks
```

## Autorização gráfica de sudo (janela de senha)

O script instala, de forma **persistente**, um helper que mostra uma janela (zenity) para digitar a senha do sudo:

- `/usr/local/bin/sudo-askpass` — helper gráfico.
- `/etc/sudo.conf` — `Path askpass` (sudo clássico).
- `/etc/profile.d/sudo-askpass.sh` — exporta `SUDO_ASKPASS`.
- `/etc/sudoers.d/sudo-askpass` — mantém `SUDO_ASKPASS` no ambiente.

O script pede a senha **uma única vez** no início (`sudo -v`) e reaproveita o ticket durante toda a execução do script.

## Mudanças em relação aos scripts legados (`programs-arch-linux.sh`, `programs-crystal-linux.sh`)

- **Removido** `azuredatastudio-bin` (EOL 2026-02-28) → aviso para usar VS Code + extensões.
- **Removido** `qt5-webengine` e `qt5-remoteobjects` (Qt5 removido do Arch oficial).
- **Corrigido** `tilix` → instalado via AUR (`yay -S tilix`), **não** via `pacman -S`.
- **Corrigidas** extensões GNOME AUR (4 nomes incorretos → 5 nomes corretos com sufixo `-git`).
- **Removida** duplicata `realvnc-vnc-viewer`.
- **Removidos** pacotes legados/questionáveis: `wine-mono`, `microsip`, `gtkglext`, `gtkd` (mantidos apenas no grupo AUR opcional se necessário).
- **Preferência** Flatpak sobre AUR para apps que têm ambos (FDM, Ferdium, AnyDesk) — mantidos no AUR como fallback.
- Logs e cache em `~/.local` (fora do repositório).
- Tratamento de erro real, contagem de falhas e resumo final.
- Script **idempotente** (pode ser reexecutado sem quebrar).
- `set -uo pipefail`, verificações de ambiente e correção de dependências.
- Suporte a **auto-atualização** via Git (defina `REPO_RAW_URL` no topo).
- Flags CLI completas: `--dry-run`, `-y`, `--no-upgrade`, `--no-self-update`, `--only`, `--no-color`, `-v`.

## Auto-atualização

No topo do script, defina:

```bash
REPO_RAW_URL="https://raw.githubusercontent.com/lzuhuo/Tool-Scripts/main/instalar-arch.sh"
```

Assim, o script se atualiza sozinho a partir do repositório antes de executar (desative com `--no-self-update`).

## Logs

Ficam em `~/.local/share/instalar-arch/logs/` (resumo em `summary.log`, um `.log` por etapa).

## Idempotência e segurança

- Verifica se pacote já está instalado (`pacman -Q`) antes de tentar instalar.
- Verifica se app Flatpak já instalado (`flatpak info`).
- `pacman -S --needed --noconfirm` evita reinstalação desnecessária.
- `yay -S --needed --noconfirm` para AUR.
- Limpeza de cache opcional com `pacman -Sc` e `yay -Sc`.

## Exemplos de uso avançado

```bash
# Só instalar pacotes oficiais + AUR (sem Flatpak, sem dev)
./instalar-arch.sh --only pacman --only yay

# Só ferramentas de desenvolvimento
./instalar-arch.sh --only dev

# Modo CI/CD: sem cor, sem perguntas, verbose
./instalar-arch.sh -y --no-color -v

# Simular tudo sem alterar o sistema
./instalar-arch.sh -n

# Pular upgrade do sistema (mais rápido em máquinas já atualizadas)
./instalar-arch.sh --no-upgrade

# Atualizar o script do Git antes de rodar
REPO_RAW_URL="https://raw.githubusercontent.com/lzuhuo/Tool-Scripts/main/instalar-arch.sh" ./instalar-arch.sh

# Instalar só extensões GNOME
./instalar-arch.sh --only extensions
```