# instalar_zorin.sh — Guia detalhado

Script de provisionamento para uma instalação limpa do **Zorin OS 18.x** (baseado em Ubuntu 24.04 LTS "noble").

## Arquivo principal

- `instalar_zorin.sh` — instala e configura os programas.

```bash
chmod +x instalar_zorin.sh
./instalar_zorin.sh              # modo interativo (pergunta cada etapa)
./instalar_zorin.sh -y           # sem perguntas
./instalar_zorin.sh -n           # dry-run (simula, não altera nada)
./instalar_zorin.sh --only apt   # executa só um grupo
```

Grupos disponíveis em `--only`:
`apt`, `repos`, `ppa`, `deb`, `flatpak`, `extensions`, `dev`, `manual`, `cleanup`.

Opções extras:
- `--no-upgrade` — pula o `apt upgrade` (só instala o que falta)
- `--no-self-update` — não tenta atualizar o script pelo Git
- `--live-log` — mostra o log em tempo real numa janela separada (tilix/terminal)
- `--no-color` — desativa cores ANSI (útil para logs de CI/CD)
- `-v, --verbose` — mostra a saída do apt em tempo real (sem redirecionar)
- `-h, --help` — mostra ajuda completa

## Estratégia de instalação

Para cada aplicativo, a preferência é:

1. **Repositórios oficiais do Zorin/Ubuntu** (`main`/`universe`) — atualizam via apt.
2. **PPAs do Launchpad e repositórios APT oficiais de terceiros** — também atualizam via apt.
3. **Pacotes `.deb` diretos** — quando não há repositório (ex.: Zoom, FDM, Ferdium, WiFiman).
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

### Flatpak (Flathub)

| Aplicativo   | ID                          |
| ------------ | --------------------------- |
| Postman      | `com.getpostman.Postman`    |
| MikroTik WinBox | `com.mikrotik.WinBox`    |

### Download manual (modal de navegador)

Alguns sites bloqueiam download automático (anti-bot/login). Para esses, o script **abre uma janela do navegador** na página exata no **final da execução**, aguarda o arquivo aparecer em `~/Downloads` e, ao detectar o download concluído, **fecha a janela** e instala sozinho.

| Aplicativo | Página                                                    |
| ---------- | --------------------------------------------------------- |
| Zoiper 5   | `zoiper.com/.../zoiper5/for/linux-deb`                    |

É a única etapa do script que exige um clique do usuário. Para executar somente essa parte: `./instalar_zorin.sh --only manual`.

### Extensões GNOME

Instaladas de `extensions.gnome.org` em `~/.local/share/gnome-shell/extensions`:

`blur-my-shell`, `dash-to-dock`, `Vitals`, `show-desktop-button`, `compiz-alike-magic-lamp-effect`, `compiz-windows-effect`.

Algumas só ficam ativas após sair e entrar novamente na sessão.

## Ferramentas de desenvolvimento

Instaladas no grupo `dev`, com as variáveis de ambiente persistidas em `~/.config/instalar-zorin/env.sh` (carregado pelo `~/.bashrc`, `~/.zshrc`, `~/.profile`):

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
- `/etc/sudoers.d/00-timestamp-timeout` — cache da senha por **60 minutos**.

O script pede a senha **uma única vez** no início (`sudo -v`) e reaproveita o ticket durante toda a execução do script.

## Interface de progresso em tempo real

O script implementa três camadas simultâneas de feedback visual:

1. **Cabeçalho global** — mostra `Etapa X/N [XX%]` + mini-barra de progresso global.
2. **Barra por-etapa** — contagem de itens (ex.: pacotes), porcentagem e **ETA** baseado no tempo decorrido.
3. **Spinner** — indica a ação atual enquanto o comando roda, para nunca parecer travado.

Flags de controle:
- `--live-log` — abre `tail -f` do log principal + log da etapa atual numa janela Tilix/terminal separada.
- `--no-color` — desativa todas as cores ANSI (saída limpa para CI/CD).
- `-v, --verbose` — mostra `stdout`/`stderr` do `apt` em tempo real (desativa spinner e barras).

## Mudanças em relação a scripts antigos

- **Removido** o RealVNC Viewer (links diretos extintos) → substituído por **Remmina** (VNC/RDP/SSH), agora via apt.
- **Removido** o Azure Data Studio (descontinuado em 2026).
- Adicionados, vindos de outros scripts do repositório: **OpenVPN + plugins**, **inetutils** (telnet/traceroute), **Ulauncher**, **WiFiman**, **Zoiper 5**, **extensões GNOME**, **nvm**, **.NET SDK** e **opencode**.
- Logs e cache de `.deb` movidos para `~/.local` (fora do repositório).
- Tratamento de erro real, contagem de falhas e resumo final.
- Script **idempotente** (pode ser reexecutado sem quebrar).
- `set -uo pipefail`, verificações de ambiente e correção de dependências.
- Suporte a **auto-atualização** via Git (defina `REPO_RAW_URL` no topo).
- **Barra de progresso com ETA**, `--live-log`, `--no-color`, `-v/--verbose` — recursos não presentes no script Ubuntu original.

## Auto-atualização

No topo do script, defina:

```bash
REPO_RAW_URL="https://raw.githubusercontent.com/lzuhuo/Tool-Scripts/main/instalar_zorin.sh"
```

Assim, o script se atualiza sozinho a partir do repositório antes de executar (desative com `--no-self-update`).

## Logs

Ficam em `~/.local/share/instalar-zorin/logs/` (resumo em `summary.log`, um `.log` por etapa).

## Idempotência e segurança

- Verifica se pacote já está instalado (`dpkg -s`) antes de tentar instalar.
- Verifica se extensão GNOME já existe no diretório antes de baixar.
- Verifica se app Flatpak já instalado (`flatpak info`).
- `apt-get install --no-install-recommends` + `Dpkg::Options::=--force-confdef --force-confold` evita prompts de config.
- `DEBIAN_FRONTEND=noninteractive` + `debconf-set-selections` pré-responde diálogos teimosos (ex.: `code`, `microsoft-edge-stable`).
- `apt -f install` ao final das instalações `.deb` corrige dependências quebradas.

## Exemplos de uso avançado

```bash
# Só instalar ferramentas de desenvolvimento (opencode, nvm, .NET)
./instalar_zorin.sh --only dev

# Modo CI/CD: sem cor, sem perguntas, verbose, live-log
./instalar_zorin.sh -y --no-color -v --live-log

# Simular tudo sem alterar o sistema
./instalar_zorin.sh -n

# Pular upgrade do sistema (mais rápido em máquinas já atualizadas)
./instalar_zorin.sh --no-upgrade

# Atualizar o script do Git antes de rodar
REPO_RAW_URL="https://raw.githubusercontent.com/lzuhuo/Tool-Scripts/main/instalar_zorin.sh" ./instalar_zorin.sh
```