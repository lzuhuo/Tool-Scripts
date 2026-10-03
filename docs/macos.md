# instalar-macos.sh — Guia detalhado

Script de provisionamento para macOS, **incluindo Intel x86_64**. Não depende
do Homebrew (que oficialmente encerrou o suporte a Intel: Tier 3, sem novas
bottles, e o instalador oficial **já recusa** o Intel). Em vez disso, usa:

1. **Download direto** de `.dmg`/`.pkg`/`.zip` para apps com URL estável.
2. **MacPorts** (suporte a Intel) para ferramentas de linha de comando.
3. **Dev tooling** próprio (opencode, nvm, .NET).
4. **Download manual** (modal de navegador) para o que não tem URL estável.

## Uso

```bash
./instalar-macos.sh              # modo interativo (pergunta cada etapa)
./instalar-macos.sh -y           # sem perguntas
./instalar-macos.sh -n           # simulação, não altera nada
./instalar-macos.sh --only direct
```

Grupos em `--only`: `direct`, `macports`, `dev`, `config`, `manual`, `cleanup`.

## Download direto (`--only direct`)

Instalados automaticamente a partir de URLs estáveis:

| App | Fonte |
|---|---|
| Visual Studio Code | `update.code.visualstudio.com/.../latest/darwin-universal/stable` (`.zip`) |
| DBeaver CE | `dbeaver.io` (latest `macos` `.dmg`) |
| Postman | `dl.pstmn.io/download/latest/osx_64` (`.zip`) |
| Ferdium | release mais recente no GitHub (`Ferdium-mac-*-x64.dmg`, via API) |

Instalação por tipo de arquivo:
- `.pkg` → `sudo installer -pkg <arquivo> -target /` (pede senha no terminal).
- `.dmg` → monta com `hdiutil`, copia o `.app` para `/Applications`, desmonta.
- `.zip` → extrai o `.app` para `/Applications`.

> Uma falha nessa etapa é registrada como `[FALHA]` e o script continua com os
> demais; não interrompe a execução.

## Alterna tiva ao brew para x64: MacPorts (`--only macports`)

O MacPorts tem suporte oficial a macOS 26 Tahoe em Intel (`MacPorts-*-26-Tahoe.pkg`).
O script:

1. Baixa o instalador `.pkg` do MacPorts e o instala (`sudo installer`).
2. Roda `sudo port install` sobre a lista `MACPORTS_CLI`.

Portas (`MACPORTS_CLI` no topo do script): `git`, `wget`, `gh`, `git-lfs`,
`openvpn`. (`git`/`curl` do macOS já vem do Xcode CLT; `telnet`/`traceroute`
não são tratados por este grupo hoje — use `darwin`/BSD nativo ou adicione
meu port desejado.)

> Se não quiser o MacPorts, deixar `MACPORTS_CLI=()` vazio pula o grupo.

## Dev tooling (`--only dev`)

| Ferramenta | Origem |
|---|---|
| `opencode` | `https://opencode.ai/install` |
| `nvm` + Node LTS | instalador oficial do nvm |
| `.NET SDK` | `dot.net/v1/dotnet-install.sh` em `~/.dotnet` (canais `10.0` + `8.0`) |

Persistidos em `~/.config/instalar-macos/env.sh`, carregado por
`~/.zprofile`, `~/.zshrc` e `~/.profile` (marcador idempotente).

## Download manual (`--only manual`)

Para apps cujo site bloqueia automação, o script abre o navegador na página,
e espera o arquivo aparecer em `~/Downloads`; ao detectar, fecha a janela e
instala.

| App | Página |
|---|---|
| Zoiper 5 | `zoiper.com/.../zoiper5/for/macos` |
| Google Chrome | `google.com/chrome` |
| Microsoft Edge | `microsoft.com/edge/download` |
| Zoom | `zoom.us/download` |
| AnyDesk | `anydesk.com/en/downloads/mac-os` |
| KeePassXC | `keepassxc.org/download.html` |
| WiFiman Desktop | `wifiman.com` |
| WinBox | `winbox.mikrotik.com` |

É a única etapa que exige um clique do usuário. Rode só ela com
`./instalar-macos.sh --only manual`.

## Notas de plataforma

- **Arquitetura**: o script não assume `/opt/homebrew` como a versão anterior;
  usa MacPorts/`/opt/local` (Intel) e não precisa de brew.
- **Auth gráfica**: para o `.pkg` do MacPorts o script usa senha nativa do
  macOS via `ask_admin()`/`osascript` quando não há TTY; de outra forma,
  `sudo` no terminal.
- **Zoiper/Chrome/AnyDesk/KeePassXC/WiFiman/WinBox** não têm URL estável
  automática confiável — por isso o grupo `manual`.

## Mudanças em relação ao `install_macos.sh` original

- **Removido** `flameshot` (HTTP 404 no macOS) → wrapper `screenshot`
  (`screencapture` nativo).
- **Removido** cask `vnc-viewer` (404) da lista → orientação ao acesso remoto
  nativo (Screen Sharing) e RDP via app.
- **Removido** `azure-data-studio` (app descontinuado).
- **wifiman corrigido**: antes o script dizia que não existia — o app existe,
  instalado via download/assistente manual.
- **Todas as partes que dependiam do brew foram trocadas** por download direto
  e MacPorts (o Homebrew não suporta mais Intel).
- `brew update`/`upgrade` e nomes mudaram → grupos novos `direct` e
  `macports`.

## Logs

`~/.local/share/instalar-macos/logs/` (`summary.log` + um `.log` por etapa).

## Auto-atualização

Defina `REPO_RAW_URL` no topo do script para atualizar sozinho
(desative com `--no-self-update`).
