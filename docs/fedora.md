# instalar-fedora.sh — Guia detalhado

Script de provisionamento para uma instalação limpa do **Fedora Workstation (x86_64)**.

## Arquivo principal

- `instalar-fedora.sh` — instala e configura os programas.

```bash
chmod +x instalar-fedora.sh
./instalar-fedora.sh              # modo interativo (pergunta cada etapa)
./instalar-fedora.sh -y           # sem perguntas
./instalar-fedora.sh -n           # dry-run (simula, não altera nada)
./instalar-fedora.sh --only dnf   # executa só um grupo
```

Grupos disponíveis em `--only`:
`dnf`, `repos`, `rpm`, `flatpak`, `dev`, `cleanup`.

Opções extras:
- `--no-upgrade` — pula o `dnf upgrade` (só instala o que falta)
- `--no-self-update` — não tenta atualizar o script pelo Git
- `--no-color` — desativa cores ANSI (útil para logs de CI/CD)
- `-v, --verbose` — mostra a saída do dnf em tempo real (sem redirecionar)
- `-h, --help` — mostra ajuda completa

## Estratégia de instalação

Para cada aplicativo, a preferência é:

1. **Repositórios oficiais do Fedora** (`dnf`) — atualizam via dnf.
2. **Repositórios RPM oficiais de terceiros** — também atualizam via dnf (VS Code, Edge).
3. **Pacotes RPM diretos** — quando o próprio RPM instala o repositório (Chrome) ou não há repositório (Zoom).
4. **Flatpak/Flathub** — só quando não há pacote RPM confiável (Postman, WinBox, FDM, DBeaver, AnyDesk, Ferdium, Extension Manager).

### Repositórios RPM de terceiros configurados

| Aplicativo          | Origem                                        |
| ------------------- | --------------------------------------------- |
| Visual Studio Code  | `packages.microsoft.com/yumrepos/vscode`      |
| Microsoft Edge      | `packages.microsoft.com/yumrepos/edge`        |
| Google Chrome       | RPM direto instala repositório (`google-chrome-stable`) |

### RPMs diretos

| Aplicativo | Origem                                          |
| ---------- | ----------------------------------------------- |
| Zoom       | `zoom.us/client/latest/zoom_x86_64.rpm`         |

### Flatpak (Flathub)

| Aplicativo             | ID                                |
| ---------------------- | --------------------------------- |
| Extension Manager      | `com.mattjakeman.ExtensionManager` |
| Postman                | `com.getpostman.Postman`           |
| MikroTik WinBox        | `com.mikrotik.WinBox`              |
| Free Download Manager  | `org.freedownloadmanager.Manager`   |
| DBeaver Community      | `io.dbeaver.DBeaverCommunity`       |
| AnyDesk                | `com.anydesk.Anydesk`              |
| Ferdium                | `org.ferdium.Ferdium`              |

## Ferramentas de desenvolvimento

Instaladas no grupo `dev`, com as variáveis de ambiente persistidas em `~/.config/instalar-fedora/env.sh` (carregado pelo `~/.bashrc`, `~/.zshrc`, `~/.profile`):

| Ferramenta | Versão/configuração                                    |
| ---------- | ------------------------------------------------------ |
| opencode   | `~/.opencode/bin`; instalador `https://opencode.ai/install` |
| nvm        | `NVM_VERSION` (padrão `v0.40.8`) + Node LTS            |
| .NET SDK   | `DOTNET_CHANNELS` (padrão `10.0` e `8.0`) em `~/.dotnet` |

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

## Mudanças em relação à versão original

- **Removido** o Azure Data Studio (descontinuado em 2026) → aviso para usar VS Code + extensões.
- **Removido** `remmina-plugins-vnc` → VNC/RDP/SSH são **built-in** no `remmina` moderno.
- **Adicionado** `ulauncher` (launcher de apps) via repositório oficial.
- **Adicionado** Flatpaks: Extension Manager, Postman, WinBox, FDM, DBeaver, AnyDesk, Ferdium.
- **Corrigido** ID Flatpak do AnyDesk: `com.anydesk.Anydesk` (case correto do Flathub).
- Logs e cache de RPM movidos para `~/.local` (fora do repositório).
- Tratamento de erro real, contagem de falhas e resumo final.
- Script **idempotente** (pode ser reexecutado sem quebrar).
- `set -uo pipefail`, verificações de ambiente e correção de dependências.
- Suporte a **auto-atualização** via Git (defina `REPO_RAW_URL` no topo).
- Flags CLI completas: `--dry-run`, `-y`, `--no-upgrade`, `--no-self-update`, `--only`, `--no-color`, `-v`.

## Auto-atualização

No topo do script, defina:

```bash
REPO_RAW_URL="https://raw.githubusercontent.com/lzuhuo/Tool-Scripts/main/instalar-fedora.sh"
```

Assim, o script se atualiza sozinho a partir do repositório antes de executar (desative com `--no-self-update`).

## Logs

Ficam em `~/.local/share/instalar-fedora/logs/` (resumo em `summary.log`, um `.log` por etapa).

## Idempotência e segurança

- Verifica se pacote RPM já está instalado (`rpm -q`) antes de tentar instalar.
- Verifica se app Flatpak já instalado (`flatpak info`).
- `dnf install --setopt=install_weak_deps=False --setopt=tsflags=nodocs --allowerasing` evita prompts e instala limpo.
- Repositórios terceiros configurados com `gpgcheck=1`, `repo_gpgcheck=1`, `metadata_expire=6h`.
- `dnf clean all` ao final limpa cache.

## Exemplos de uso avançado

```bash
# Só instalar ferramentas de desenvolvimento (opencode, nvm, .NET)
./instalar-fedora.sh --only dev

# Modo CI/CD: sem cor, sem perguntas, verbose
./instalar-fedora.sh -y --no-color -v

# Simular tudo sem alterar o sistema
./instalar-fedora.sh -n

# Pular upgrade do sistema (mais rápido em máquinas já atualizadas)
./instalar-fedora.sh --no-upgrade

# Atualizar o script do Git antes de rodar
REPO_RAW_URL="https://raw.githubusercontent.com/lzuhuo/Tool-Scripts/main/instalar-fedora.sh" ./instalar-fedora.sh

# Instalar só pacotes oficiais e repositórios terceiros
./instalar-fedora.sh --only dnf --only repos
```