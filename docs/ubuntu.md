# instalar-ubuntu-26-04.sh — Guia detalhado

Script de provisionamento para uma instalação limpa do **Ubuntu 26.04 LTS
("resolute")**.

## Arquivo principal

- `instalar-ubuntu-26-04.sh` — instala e configura os programas.

```bash
chmod +x instalar-ubuntu-26-04.sh
./instalar-ubuntu-26-04.sh              # modo interativo (pergunta cada etapa)
./instalar-ubuntu-26-04.sh -y           # sem perguntas
./instalar-ubuntu-26-04.sh -n           # dry-run (simula, não altera nada)
./instalar-ubuntu-26-04.sh --only apt   # executa só um grupo
```

Grupos disponíveis em `--only`:
`apt`, `repos`, `ppa`, `deb`, `flatpak`, `extensions`, `dev`, `manual`,
`cleanup`.

## Estratégia de instalação

Para cada aplicativo, a preferência é:

1. **Repositórios oficiais do Ubuntu** (`main`/`universe`) — atualizam via apt.
2. **PPAs do Launchpad e repositórios APT oficiais de terceiros** — também
   atualizam via apt.
3. **Pacotes `.deb` diretos** — quando não há repositório (ex.: Zoom, FDM,
   WiFiman, Zoiper).
4. **Flatpak/Flathub** — só quando não há pacote APT confiável (Postman, WinBox).

### PPAs e repositórios de terceiros configurados

| Aplicativo          | Origem                                        |
| ------------------- | --------------------------------------------- |
| Ulauncher           | `ppa:agornostal/ulauncher`                    |
| Google Chrome       | `dl.google.com/linux/chrome/deb`              |
| Visual Studio Code  | `packages.microsoft.com/repos/code`           |
| Microsoft Edge      | `packages.microsoft.com/repos/edge`           |
| DBeaver CE          | `dbeaver.io/debs/dbeaver-ce`                  |
| AnyDesk             | `deb.anydesk.com`                             |

### `.deb` diretos

| Aplicativo           | Origem                                          |
| -------------------- | ----------------------------------------------- |
| Zoom                 | `zoom.us/client/latest/zoom_amd64.deb`          |
| Free Download Manager| `files2.freedownloadmanager.org`                |
| Ferdium              | release amd64 mais recente no GitHub (via API)  |
| WiFiman Desktop      | `desktop.wifiman.com`                           |
| Zoiper 5             | página de download da Zoiper (sessão/cookies)   |

### Flatpak (Flathub)

| Aplicativo   | ID                          |
| ------------ | --------------------------- |
| Postman      | `com.getpostman.Postman`    |
| MikroTik WinBox | `com.mikrotik.WinBox`    |

### Download manual (modal de navegador)

Alguns sites bloqueiam download automático (anti-bot/login). Para esses, o
script **abre uma janela do navegador** na página exata no **final da
execução**, aguarda o arquivo aparecer em `~/Downloads` e, ao detectar o
download concluído, **fecha a janela** e instala sozinho.

| Aplicativo | Página                                                    |
| ---------- | --------------------------------------------------------- |
| Zoiper 5   | `zoiper.com/.../zoiper5/for/linux-deb`                    |

É a única etapa do script que exige um clique do usuário. Para executar
somente essa parte: `./instalar-ubuntu-26-04.sh --only manual`.

### Extensões GNOME

Instaladas de `extensions.gnome.org` em
`~/.local/share/gnome-shell/extensions`:

`blur-my-shell`, `dash-to-dock`, `Vitals`, `show-desktop-button`,
`compiz-alike-magic-lamp-effect`, `compiz-windows-effect`.
Algumas só ficam ativas após sair e entrar novamente na sessão.

## Ferramentas de desenvolvimento

Instaladas no grupo `dev`, com as variáveis de ambiente persistidas em
`~/.config/instalar-ubuntu/env.sh` (carregado pelo `~/.bashrc`):

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

O script instala, de forma **persistente**, um helper que mostra uma janela
(zenity) para digitar a senha do sudo:

- `/usr/local/bin/sudo-askpass` — helper gráfico.
- `/etc/sudo.conf` — `Path askpass` (sudo clássico).
- `/etc/profile.d/sudo-askpass.sh` — exporta `SUDO_ASKPASS`.
- `/etc/sudoers.d/sudo-askpass` — mantém `SUDO_ASKPASS` no ambiente.
- `/etc/sudoers.d/00-timestamp-timeout` — cache da senha por **60 minutos**.

O script pede a senha **uma única vez** no início (`sudo -v`) e reaproveita o
ticket durante toda a execução do script.

## Mudanças em relação à versão original

- **Removido** o RealVNC Viewer (links diretos extintos) → substituído por
  **Remmina** (VNC/RDP/SSH), agora via apt.
- **Removido** o Azure Data Studio (descontinuado em 2026).
- Adicionados, vindos de outros scripts do repositório: **OpenVPN + plugins**,
  **inetutils** (telnet/traceroute), **Ulauncher**, **WiFiman**, **Zoiper 5**,
  **extensões GNOME**, **nvm**, **.NET SDK** e **opencode**.
- Logs e cache de `.deb` movidos para `~/.local` (fora do repositório).
- Tratamento de erro real, contagem de falhas e resumo final.
- Script **idempotente** (pode ser reexecutado sem quebrar).
- `set -uo pipefail`, verificações de ambiente e correção de dependências.
- Suporte a **auto-atualização** via Git (defina `REPO_RAW_URL` no topo).

## Auto-atualização

No topo do script, defina:

```bash
REPO_RAW_URL="https://raw.githubusercontent.com/lzuhuo/Tool-Scripts/main/instalar-ubuntu-26-04.sh"
```

Assim, o script se atualiza sozinho a partir do repositório antes de executar
(desative com `--no-self-update`).

## Logs

Ficam em `~/.local/share/instalar-ubuntu/logs/` (resumo em `summary.log`).
