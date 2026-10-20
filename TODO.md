# TODO — pendências dos scripts

Itens obsoletos ou frágeis identificados nos scripts deste repositório.
O script `instalar-ubuntu-26-04.sh` já foi revisado; os demais ainda têm
pendências. Nada aqui foi corrigido ainda — é só um levantamento.

> Última verificação de nomes/estado dos pacotes: **2026-10-02**, consultando
> `packages.fedoraproject.org`, `archlinux.org/packages`, `aur.archlinux.org`
> e `formulae.brew.sh`. Os estados mudam — reconfirmar antes de corrigir.

---

## Transversais (afetam vários scripts)

### Azure Data Studio — descontinuado
A Microsoft **aposentou o Azure Data Studio em 28/02/2026**. O substituto é o
**VS Code** com extensões de SQL/Azure (já instalado nos scripts).
- `programs.sh` — link de versão antiga (EOL).
- `programs-arch-linux.sh` / `programs-crystal-linux.sh` — AUR
  `azuredatastudio-bin` **ainda existe** (1.52.0-3), mas instala software EOL.
- `instalar-macos.sh` — cask `azure-data-studio` **removido** (app descontinuado).

> `instalar-fedora.sh` já foi ajustado (removeu o Azure DS e avisa o usuário).

### RealVNC Viewer
Os links diretos oficiais foram extintos (hoje exige login no portal); URLs
fixas como `VNC-Viewer-7.15.1-Linux-x64.deb` retornam **404**.
- `programs.sh` — URL fixa morta.
- `programs-arch-linux.sh` / `programs-crystal-linux.sh` — AUR
  `realvnc-vnc-viewer` **existe e está atualizado** (8.3.0-1), então funciona
  no Arch; só remover a **duplicata** e decidir se vale manter.
- `instalar-macos.sh` — cask `vnc-viewer` **removido** (HTTP 404);
  substituído por `windows-app` (RDP) + `rustdesk`.

> `instalar-ubuntu-26-04.sh` resolveu com **Remmina** (VNC/RDP/SSH) via apt.

### MicroSIP — só existe para Windows
`microsip` não tem pacote Linux nativo. No Arch/AUR existe `microsip`
(3.22.16-1), mas é um wrapper que roda via Wine.
- `programs-arch-linux.sh`, `programs-crystal-linux.sh`, `install_omarchy.sh`

### Zoiper — download não automatizável
O site redireciona para a versão antiga (Zoiper 3) e bloqueia automação.
Abordagem recomendada: modal de navegador com detecção em `~/Downloads`
(implementado no `instalar-ubuntu-26-04.sh`).
- `programs.sh` (wget baixa HTML, não o `.deb`)
- `instalar-macos.sh` (modal de navegador, mesmo modelo do Ubuntu)
- `instalar-fedora.sh` (só aviso)

---

## `programs.sh` (Debian/Ubuntu)

Script antigo, sem tratamento de erro. Pendências específicas:

- [ ] `chrome-gnome-shell` está **renomeado** → usar `gnome-browser-connector`.
- [ ] `inetutils-*` como glob é frágil (depende da expansão) → listar
      explicitamente (`inetutils-telnet`, `inetutils-traceroute`).
- [ ] URL fixa do RealVNC retorna **404**.
- [ ] Link do Azure Data Studio é de versão antiga e está **EOL**.
- [ ] WiFiman fixado na **1.2.8**; a atual é **1.3.0**.
- [ ] `wget` do Zoiper baixa página HTML, não o `.deb`.
- [ ] `sudo rm -r programas` sem confirmação e com `sudo` desnecessário.
- [ ] Sem `set -euo pipefail`, sem resumo/contagem de falhas.
- [ ] Poderia seguir a mesma arquitetura do `instalar-ubuntu-26-04.sh`.

---

## `programs-arch-linux.sh` (Arch)

Nomes verificados nos repositórios oficiais e no AUR:

- [ ] `azuredatastudio-bin` — AUR existe, mas software **EOL**.
- [ ] `qt5-webengine` e `qt5-remoteobjects` **não estão mais** nos repositórios
      oficiais do Arch (foram removidos junto com o Qt5). Linha 18 quebra.
      Verificar substitutos (provavelmente qt6-*) ou remover.
- [ ] `tilix` **não é** pacote oficial — está no **AUR** (`tilix`). Em
      `pacman -S` vai falhar; usar `yay -S`.
- [ ] `gtkd` está no **AUR** (3.11.0-4), não nos oficiais; usar `yay`.
- [ ] `realvnc-vnc-viewer` aparece **duplicado** (linhas 59 e 62).
- [ ] **Extensões GNOME com nomes errados no AUR** (verificado):
      - `gnome-shell-extension-all-windows-srwp` → **não existe**.
      - `gnome-shell-extension-magic-lamp` → correto é
        `gnome-shell-extension-compiz-alike-magic-lamp-effect-git`.
      - `gnome-shell-extension-compiz-windows-effect` → correto é
        `...compiz-windows-effect-git`.
      - `gnome-shell-extension-show-desktop-button` → **não existe**.
      - `gnome-shell-extension-vitals` → correto é
        `gnome-shell-extension-vitals-git`.
      - `gnome-shell-extension-blur-my-shell` e
        `gnome-shell-extension-dash-to-dock` existem e estão corretos.
- [ ] Confirmar nomes oficiais já existentes (verificados OK): `firefox`,
      `gnome-browser-connector`, `extension-manager`, `keepassxc`, `remmina`,
      `inetutils` (core), `xcb-util-cursor`, `ttf-liberation`.
- [ ] `wine-mono microsip gtkglext` — dependências legadas/opcionais; revisar.
- [ ] `yay` sem `--needed` consistente; revisar idempotência.
- [ ] Sem tratamento de erro nem resumo final.

---

## `programs-crystal-linux.sh` (Crystal Linux)

- [ ] `azuredatastudio-bin` — AUR existe, mas software **EOL**.
- [ ] `keepass` — provável **typo**; no Arch/AUR o correto é `keepassxc`.
- [ ] `realvnc-vnc-viewer` aparece **duplicado** (linhas 28 e 31).
- [ ] `winbox3` — conferir; no AUR o pacote atual chama-se `winbox` (4.4-1).
- [ ] `qt5-webengine`/Qt5 — mesma questão dos oficiais removidos (se aplicável).
- [ ] `microsip`, `gtkglext`, `wine-mono` — revisar necessidade.
- [ ] Usa `ame` (helper do Crystal); confirmar que ainda é o padrão da distro.

---

## `instalar-macos.sh` (macOS) — ✅ revisado e reescrito (sem brew)

O antigo `install_macos.sh` foi substituído por `instalar-macos.sh`
(arquitetura alinhada ao `instalar-ubuntu-26-04.sh`). Após a descoberta de
que o Homebrew parou de suportar Intel (Tier 3, instalador recusa x86_64),
o fluxo foi trocado para **download direto + MacPorts**.

- [x] brew/cask/mas — removidos como dependência: Homebrew não suporta mais
      Intel (Tier 3; instalador oficial recusa). Grupo agora é
      `direct` (downloads) + `macports` (CLI).
- [x] cask `vnc-viewer` / `azure-data-studio` / `flameshot` — removidos
      (HTTP 404 / app EOL / só Linux). VNC nativo = Screen Sharing; wrapper
      `screenshot` em `~/.local/bin`.
- [x] Zoiper/GnuPG/Chrome/AnyDesk/KeePassXC/WiFiman/WinBox — apenas via
      modal de download manual (`--only manual`).
- [x] CLI que eram via brew (`git`, `wget`, `gh`, `git-lfs`, `openvpn`)
      agora via **MacPorts** (`--only macports`), que tem suporte ao Intel.
- [x] Dev tooling mantido: `opencode`, `nvm` + Node LTS, `.NET SDK` (10/8).
- [x] Logs em `~/.local/share/instalar-macos/logs/`; contadores OK/SKIP/FALHA.
- [ ] Confirmar nomes de port do MacPorts (`git`, `wget`, `gh`, `git-lfs`,
      `openvpn`) com `port search` na máquina-alvo antes de confiar no grupo.
- [ ] Confirmar URLs diretas (Edge/Zoom/Postman/VS Code) na máquina-alvo —
      o script registra FALHA por app sem abortar o restante.

---

## `instalar_zorin.sh` (Zorin OS 18.x) — ✅ revisado e completo

Script alinhado à arquitetura de referência (`instalar-ubuntu-26-04.sh`) com melhorias:
- [x] `set -uo pipefail`, `run_cmd`, `record`, contadores OK/SKIP/FAIL, resumo final.
- [x] Idempotente (verifica `dpkg -s`, `flatpak info`, diretórios de extensões).
- [x] Autorização gráfica persistente (`sudo-askpass` via zenity, cache 60 min).
- [x] Logs/cache em `~/.local` (fora do repo).
- [x] Preferência: repos oficiais → PPAs/repos terceiros → `.deb` direto → Flatpak.
- [x] Auto-atualização opcional via `REPO_RAW_URL`.
- [x] **Interface de progresso avançada:** cabeçalho global `Etapa X/N [XX%]`, barra por-etapa com contagem + ETA, spinner de ação atual.
- [x] Flags: `--live-log`, `--no-color`, `-v/--verbose`, `--no-upgrade`.
- [x] Grupos `--only`: `apt|repos|ppa|deb|flatpak|extensions|dev|manual|cleanup`.
- [x] Dev tooling: opencode, nvm + Node LTS, .NET SDK (10.0, 8.0) com env em `~/.config/instalar-zorin/env.sh`.
- [x] Extensões GNOME de `extensions.gnome.org` (6 extensões).
- [x] Download manual modal para Zoiper 5.
- [x] Documentação detalhada em `docs/zorin.md`.
- [ ] Confirmar URLs diretas (Zoom, FDM, WiFiman, Ferdium) na máquina-alvo — o script registra FALHA por app sem abortar o restante.

---

## `install_omarchy.sh` (Arch/Omarchy)

Script mínimo para Omarchy (Arch-based). Estrutura simples mas funcional.

### ✅ Pacotes oficiais
- `git`, `curl`, `wget`, `flameshot`, `inetutils` — ✅ todos no core/extra

### ✅ AUR packages (verificados)
| Pacote | Versão | Status |
|--------|--------|--------|
| `microsoft-edge-stable-bin` | 155.0.4283.62-1 | ✅ |
| `dbeaver-ce-bin` | 26.2.2-1 | ✅ |
| `postman-bin` | 12.32.4-1 | ✅ |
| `ferdium-bin` | 7.2.3-1 | ✅ |
| `keepassxc` | Existe no AUR e oficial | ✅ |
| `wine-mono` | ⚠️ Legado | Revisar |
| `microsip` | 3.22.18-1 (Wine wrapper) | Avaliar remoção |
| `gtkglext` | 1.2.0-20 (GTK2 legado) | Revisar |
| `anydesk-bin` | 8.1.0-1 | ✅ |
| `freedownloadmanager-bin` | 6.33.1.6648-1 | ✅ (FDM tem Flatpak oficial) |

### ⚠️ Problemas
- [ ] `microsip` — Wine wrapper só Windows; avaliar remoção
- [ ] `gtkglext` — GTK2/OpenGL legado; avaliar remoção
- [ ] `wine-mono` — dependência legada; revisar necessidade
- [ ] `freedownloadmanager-bin` — tem Flatpak oficial, preferir Flatpak
- [ ] `ferdium-bin` — tem Flatpak oficial, preferir Flatpak
- [ ] `anydesk-bin` — tem Flatpak oficial, preferir Flatpak
- [ ] `omarchy plugin add` — comando específico do Omarchy; verificar se ainda válido
- [ ] Sem `set -euo pipefail`, sem tratamento de erro, sem resumo
- [ ] Sem idempotência, sem logs, sem `--dry-run`, sem `--only`
- [ ] Autorização gráfica para sudo sem TTY
- [ ] `omarchy` command pode não existir em Arch puro

---

## `instalar_simplay.sh` (Ubuntu + Wine)

Instalador gráfico (Zenity) para app Windows 'SimPlay' via Wine.

### Problemas identificados
- [ ] **Versão hardcoded**: ZIP URL fixa na 1.3.6 — verificar se continua atual
- [ ] `curl -L` sem `--fail`/`--retry`; sem validação do ZIP (checksum/tamanho)
- [ ] `winetricks -q dotnet48 vcrun2015 directx9 directplay dxvk` — baixa muito, pode falhar; sem checagem de sucesso
- [ ] `eval "$INSTALAR ..."` com string de comando — frágil (injeção, expansão)
- [ ] `detectar_gerenciador` define `INSTALAR` como string com `&&` — `eval` problemático
- [ ] Sem shebang robusto / `set -euo pipefail`
- [ ] Sem `--dry-run`, sem logs estruturados, sem resumo OK/SKIP/FAIL
- [ ] `zenity` usado antes de instalar dependências (linha 121 chama `instalar_dependencias` mas linha 52 já usa zenity em `escolher_resolucao`)
- [ ] `RESOLUCAO` definida duas vezes (linha 52 e 83) — lógica confusa
- [ ] Bom candidato a padronizar com arquitetura de referência
- [ ] URL do ZIP em `pub-624c1898dc4040e2aa0cae1c31bfab7e.r2.dev` — endpoint R2 (Cloudflare), verificar longevidade

---

## `sql-2008.sh` (compatibilidade SQL Server 2008) — ⚠️ **PERIGOSO**

Script solto, sem shebang, sem tratamento de erro e **quebra o sistema**.

### Problemas críticos
- [ ] Sem `#!/bin/bash` e sem `set -e`
- [ ] `sed -i` em `/etc/ssl/openssl.cnf` sem backup e sem `sudo` explícito
- [ ] Compila OpenSSL **1.1.1h** (2019, **sem patches de segurança**) e sobrescreve `/usr/bin/openssl` com symlink → **pode quebrar crypto do sistema todo**
- [ ] `sudo ln -s ... /usr/bin/openssl` falha se já existir (sem `-f`)
- [ ] `./config` com `sudo make install` fora do diretório (falta `cd`)
- [ ] Não instala deps antes do `./config` (make/gcc vêm depois na linha 11)
- [ ] **Recomendado**: checar se o sistema atual aceita `seclevel=1` no `/etc/ssl/openssl.cnf` **sem** compilar OpenSSL, que quase sempre basta
- [ ] OpenSSL 1.1.1 EOL desde 2023-09-11 — não deve ser instalado

### Ação recomendada
- [ ] **NÃO MIGRAR** para arquitetura de referência como instalador
- [ ] Reescrever como **script de verificação apenas**: testa se `openssl.cnf` com `SECLEVEL=1` funciona
- [ ] Documentar alternativa segura (configuração openssl.cnf sem compilar)
- [ ] Marcar como **DEPRECADO/PERIGOSO** no README

---

## `lvm-free-ubuntu-server.sh` (⚠️ **DESTRUTIVO**)

Redimensiona LVM para usar espaço livre. **Pode destruir dados**.

### Problemas críticos
- [ ] Sem shebang e sem `set -e`
- [ ] `pvresize /dev/sda3` e LVM device **hardcoded** — pode destruir dados em outra máquina
- [ ] `sudo su` no topo (interativo) quebra execução não interativa
- [ ] Faltam confirmações e checagens (`vgs`, `lvs`, `df -h` antes/depois)
- [ ] Deveria exigir confirmação explícita e avisar sobre backup
- [ ] Detectar devices dinamicamente (`lsblk`, `findmnt`, `pvs`)

### Ação recomendada
- [ ] **NÃO MIGRAR** como instalador genérico
- [ ] Reescrever como **ferramenta interativa segura**: detecta VG/LV, mostra preview, exige confirmação, faz backup
- [ ] Ou mover para `docs/` como exemplo educacional com avisos

---

## `programs.sh` (Debian/Ubuntu — Legacy)

Script antigo, sem tratamento de erro, sem `set -euo pipefail`. Pendências específicas:

### ❌ Pacotes apt com problemas
- [ ] `chrome-gnome-shell` → **renomeado** para `gnome-browser-connector`
- [ ] `inetutils-*` glob frágil → listar explicitamente (`inetutils-telnet`, `inetutils-traceroute`)
- [ ] `tilix`, `flameshot`, `git`, `curl`, `gnome-tweaks` — verificar se existem no Ubuntu 24.04+

### ❌ Downloads diretos (URLs mortas/erradas)
| URL | Problema | Correção |
|-----|----------|----------|
| `zoiper.com/.../linux-deb` | wget baixa HTML, não .deb (anti-bot) | Modal navegador (como Ubuntu/Zorin) |
| `realvnc.com/.../VNC-Viewer-7.15.1-Linux-x64.deb` | **404** (links diretos extintos) | Remmina via apt |
| `microsoft.com/.../azuredatastudio-linux-1.52.0.deb` | **EOL** (Azure Data Studio descontinuado 2026-02-28) | VS Code + extensões |
| `desktop.wifiman.com/wifiman-desktop-1.2.8-amd64.deb` | Versão fixa 1.2.8 (atual 1.3.0) | URL genérica ou Flatpak |

### ⚠️ Flatpaks — verificar IDs
| App | ID usado | ID correto Flathub | Status |
|-----|----------|-------------------|--------|
| Extension Manager | `com.mattjakeman.ExtensionManager` | ✅ | OK |
| Postman | `com.getpostman.Postman` | ✅ | OK |
| WinBox | `com.mikrotik.WinBox` | ✅ | OK |
| KeePassXC | `org.keepassxc.KeePassXC` | ❌ **ID errado** | `org.keepassxc.KeePassXC` não existe; usar `org.keepassxc.KeePassXC` ou apt `keepassxc` |
| Zoom | `us.zoom.Zoom` | ❌ **ID errado** | Flathub não tem Zoom oficial; usar `.deb` direto |
| Chrome | `com.google.Chrome` | ❌ **ID errado** | Flathub não tem Chrome oficial; usar repo Google |
| Edge | `com.microsoft.Edge` | ❌ **ID errado** | Flathub não tem Edge oficial; usar repo Microsoft |
| DBeaver | `io.dbeaver.DBeaverCommunity` | ✅ | OK |
| AnyDesk | `com.anydesk.Anydesk` | ⚠️ Case | Verificar `com.anydesk.AnyDesk` |
| Ferdium | `org.ferdium.Ferdium` | ✅ | OK |
| FDM | `org.freedownloadmanager.Manager` | ✅ | OK |
| VS Code | `com.visualstudio.code` | ✅ | Existe (mas repo Microsoft é melhor) |

### Problemas de estrutura
- [ ] `sudo rm -r programas` sem confirmação e com `sudo` desnecessário
- [ ] Sem `set -euo pipefail`, sem error handling
- [ ] Sem resumo/contagem de falhas
- [ ] Poderia seguir mesma arquitetura do `instalar-ubuntu-26-04.sh`
- [ ] `cd programas` sem `|| exit` — se falhar, instala no diretório errado

---

## Priorização sugerida para migração

### 🔥 **Alta prioridade** (scripts funcionais mas com bugs conhecidos)
1. `instalar-fedora.sh` — bem estruturado, só correções de pacotes
2. `programs-arch-linux.sh` — muito usado, muitos bugs AUR
3. `programs-crystal-linux.sh` — bugs críticos (tilix, keepass, extension-manager)

### 🟡 **Média prioridade** (precisam reescrita completa)
4. `install_omarchy.sh` — simples mas incompleto
5. `programs.sh` — legado total, reescrever do zero

### 🟢 **Baixa prioridade / Não migrar como instaladores**
6. `instalar_simplay.sh` — caso específico Wine, padronizar
7. `sql-2008.sh` — **PERIGOSO**, reescrever como verificação apenas
8. `lvm-free-ubuntu-server.sh` — **DESTRUTIVO**, reescrever como ferramenta segura

---

## `programs-arch-linux.sh` (Arch Linux)

Script antigo, sem `set -euo pipefail`, sem tratamento de erro, sem resumo. Estrutura flat (tudo no main).

### ✅ Pacotes oficiais verificados (existem no repositório `extra`/`core`)
- `git`, `curl`, `wget`, `flameshot`, `gnome-tweaks`, `gnome-browser-connector`, `firefox`
- `pipewire`, `pipewire-pulse`, `pipewire-alsa`, `pipewire-jack`, `wireplumber`
- `openvpn`, `networkmanager-openvpn` (verificar `network-manager-applet` vs `nm-applet`)
- `ttf-liberation`, `xcb-util-cursor`

### ❌ Pacotes oficiais com problemas
- [ ] `inetutils` → **não existe** como pacote único no Arch; usar `inetutils` (core, provê telnet/traceroute/ping etc.) — o script usa `inetutils` na linha 7, que **existe** no core
- [ ] `qt5-remoteobjects` + `qt5-webengine` → **REMOVIDOS** do Arch oficial (Qt5 EOL); migrar para Qt6 ou remover

### ❌ AUR packages com nomes incorretos / inexistentes
| Usado no script | Status AUR | Correção |
|-----------------|------------|----------|
| `gnome-shell-extension-all-windows-srwp` | **NÃO EXISTE** | Remover ou achar alternativa |
| `gnome-shell-extension-magic-lamp` | **NÃO EXISTE** | `gnome-shell-extension-compiz-alike-magic-lamp-effect-git` |
| `gnome-shell-extension-compiz-windows-effect` | **NÃO EXISTE** | `gnome-shell-extension-compiz-windows-effect-git` |
| `gnome-shell-extension-show-desktop-button` | **NÃO EXISTE** | Remover ou achar alternativa |
| `gnome-shell-extension-vitals` | Nome errado | `gnome-shell-extension-vitals-git` |
| `gnome-shell-extension-blur-my-shell` | ✅ Existe | OK |
| `gnome-shell-extension-dash-to-dock` | ✅ Existe | OK |

### ❌ AUR packages duplicados
- `realvnc-vnc-viewer` aparece **duas vezes** (linha 47 e 62)

### ⚠️ AUR packages legados/questionáveis
- `azuredatastudio-bin` 1.52.0-3 — **EOL** (Azure Data Studio descontinuado 2026-02-28), remover
- `wine-mono` — dependência legada; revisar necessidade
- `microsip` — Wine wrapper (só Windows); avaliar remoção
- `gtkglext` — GTK2/OpenGL legado; avaliar remoção
- `gtkd` — D bindings para GTK+; confirmar necessidade
- `freedownloadmanager-bin` — existe, mas FDM tem Flatpak oficial
- `ferdium-bin` — existe, mas Ferdium tem Flatpak oficial
- `anydesk-bin` — existe, mas AnyDesk tem Flatpak oficial

### ✅ AUR packages OK
- `google-chrome`, `microsoft-edge-stable-bin`, `zoom`
- `visual-studio-code-bin`, `dbeaver-ce-bin`, `postman-bin`
- `realvnc-vnc-viewer` 8.3.0-1 (existe e atualizado)
- `winbox` 4.4-1 (corrigido: era `winbox3` no crystal)
- `ulauncher` 5.16.2-1
- `extension-manager` (existe no AUR)
- `keepassxc` (existe no AUR e oficial)
- `tilix` 1.9.6-10 — **NOTA: `tilix` está no AUR, NÃO no oficial**; script usa `pacman -S` na linha 65 → vai falhar; deve usar `yay -S`

### Itens pendentes de arquitetura
- [ ] Adicionar `set -Eeuo pipefail`
- [ ] Adicionar funções de log, contadores OK/SKIP/FAIL, resumo final
- [ ] Adicionar `--dry-run`, `--only`, `-y`, `--no-self-update`
- [ ] Separar pacotes oficiais (`pacman`) vs AUR (`yay`)
- [ ] Corrigir `tilix` → `yay -S tilix`
- [ ] Corrigir nomes de extensões GNOME (ver tabela acima)
- [ ] Remover `azuredatastudio-bin` (EOL)
- [ ] Remover duplicata `realvnc-vnc-viewer`
- [ ] Revisar `wine-mono`, `microsip`, `gtkglext`, `gtkd`
- [ ] Migrar Qt5 → Qt6 ou remover `qt5-remoteobjects`/`qt5-webengine`
- [ ] Idempotência (verificar antes de instalar)
- [ ] Logs em `~/.local/share/programs-arch-linux/logs/`
- [ ] Autorização gráfica (zenity) para sudo sem TTY

---

## `programs-crystal-linux.sh` (Crystal Linux — derivada do Arch)

Script mínimo, usa `ame` (helper do Crystal) em vez de `yay`. Requer edição manual de `/etc/pacman.conf` antes de rodar.

### ✅ Pacotes oficiais (verificar se existem no Arch base)
- `tilix` — **AUR only** (não oficial), script usa `pacman -S` → vai falhar
- `flameshot`, `gnome-tweaks`, `gnome-browser-connector`, `firefox` — ✅
- `inetutils` — ✅ (core)
- `openvpn`, `networkmanager-openvpn` — ✅
- `network-manager-applet` → verificar se é `nm-applet` ou `network-manager-applet`

### ❌ AUR packages via `ame` (verificados)
| Usado no script | Status AUR | Correção |
|-----------------|------------|----------|
| `google-chrome` | ✅ 156.0.8078.47-1 | OK |
| `microsoft-edge-stable-bin` | ✅ 155.0.4283.62-1 | OK |
| `zoom` | ✅ 7.2.1-1 | OK |
| `visual-studio-code-bin` | ✅ 1.142.0-1 | OK |
| `azuredatastudio-bin` | ⚠️ 1.52.0-3 **EOL** | Remover |
| `dbeaver-ce-bin` | ✅ 26.2.2-1 | OK |
| `postman-bin` | ✅ 12.32.4-1 | OK |
| `freedownloadmanager` | ✅ 6.35.1.7021-1 | OK |
| `realvnc-vnc-viewer` | ✅ 8.3.0-1 | OK (duplicado na linha 31) |
| `ferdium-bin` | ✅ 7.2.3-1 | OK |
| `winbox3` | ⚠️ 3.43-1 (Winbox 3.x c/ Wine) | Atual é `winbox` 4.4-1 |
| `inetutils` | ⚠️ **Duplicado** (já instalado via `pacman` linha 16) | Remover da linha 28 |
| `extension-manager` | ❌ **NÃO EXISTE** como `extension-manager` | `extension-manager-git` 0.6.5.r280... |
| `keepass` | ❌ **NÃO EXISTE** como `keepass` | Provável typo → `keepassxc` |
| `wine-mono` | ⚠️ Legado | Revisar |
| `microsip` | ✅ 3.22.18-1 (Wine wrapper) | Avaliar remoção |
| `gtkglext` | ✅ 1.2.0-20 (GTK2 legado) | Revisar |
| `anydesk-bin` | ✅ 8.1.0-1 | OK |

### Problemas críticos
- [ ] `tilix` instalado via `pacman -S` → **vai falhar** (está no AUR, não oficial)
- [ ] `keepass` → typo, deveria ser `keepassxc`
- [ ] `extension-manager` → não existe, usar `extension-manager-git`
- [ ] `winbox3` → versão antiga (3.x com Wine), atual é `winbox` 4.4-1
- [ ] `realvnc-vnc-viewer` duplicado (linhas 28 e 31)
- [ ] `azuredatastudio-bin` → EOL, remover
- [ ] `inetutils` duplicado (linha 16 via pacman, linha 28 via ame)
- [ ] `network-manager-applet` → verificar nome correto no Arch (`nm-applet`?)
- [ ] Script usa `ame` — confirmar se ainda é o helper padrão do Crystal Linux
- [ ] Sem `set -e`, sem tratamento de erro, sem resumo, sem idempotência
- [ ] Requer edição manual de `/etc/pacman.conf` (multilib) antes de rodar

---

## `install_omarchy.sh` (Arch/Omarchy)

## `instalar-fedora.sh` (Fedora) — ✅ **MIGRADO PARA ARQUITETURA DE REFERÊNCIA**

Script reescrito seguindo o padrão de `instalar-ubuntu-26-04.sh` / `instalar_zorin.sh`:
- [x] `set -uo pipefail`, `run_cmd`, `record`, contadores OK/SKIP/FAIL, resumo final.
- [x] Idempotente (verifica `rpm -q`, `flatpak info` antes de instalar).
- [x] Autorização gráfica persistente (`sudo-askpass` via zenity).
- [x] Logs/cache em `~/.local` (fora do repo).
- [x] Preferência: repos oficiais → repos terceiros → RPM direto → Flatpak.
- [x] Auto-atualização opcional via `REPO_RAW_URL`.
- [x] Flags: `--dry-run`, `-y/--yes`, `--no-upgrade`, `--no-self-update`, `--only <grupo>`, `--no-color`, `-v/--verbose`.
- [x] Grupos `--only`: `dnf|repos|rpm|flatpak|dev|cleanup`.
- [x] Dev tooling: opencode, nvm + Node LTS, .NET SDK (10.0, 8.0) com env em `~/.config/instalar-fedora/env.sh`.
- [x] `shellcheck` limpo (zero warnings).
- [x] `--dry-run` completa: OK:1 / SKIP:36 / FALHA:0.
- [x] Todos os 6 grupos `--only` funcionam independentemente.

### Correções de pacotes aplicadas
| Item | Antes | Depois | Status |
|------|-------|--------|--------|
| `remmina-plugins-vnc` | instalava plugin separado | **removido** (VNC/RDP/SSH built-in no `remmina`) | ✅ |
| `ulauncher` | não verificado | **adicionado** ao `DNF_PACKAGES` (existe no Fedora) | ✅ |
| `com.anydesk.Anydesk` | typo no case | **mantido** (ID correto no Flathub é `Anydesk` com 'd' minúsculo) | ✅ |
| `wmctrl`, `wine`, etc. | lista antiga | **removidos** (não estavam no script original) | ✅ |
| `inetutils` | não existe | **não adicionado** | ✅ |
| Zoiper | sem RPM | **mantido aviso** no final | ✅ |

### Itens pendentes (pós-migração)
- [ ] Testar em Fedora real (dnf, repos terceiros, Flatpak, dev tooling)
- [ ] Verificar URLs dos RPMs diretos (Chrome, Edge, VS Code, Zoom) em máquina-alvo
- [ ] Criar `docs/fedora.md` com guia detalhado
- [ ] Atualizar `README.md` com link para `docs/fedora.md`

---

## `sql-2008.sh` (compatibilidade SQL Server 2008)

Script solto, sem shebang, sem tratamento de erro e **perigoso**:
- [ ] Sem `#!/bin/bash` e sem `set -e`.
- [ ] `sed -i` em `/etc/ssl/openssl.cnf` sem backup e sem `sudo` explícito.
- [ ] Compila OpenSSL **1.1.1h** (2019, sem patches de segurança) e sobrescreve
      `/usr/bin/openssl` com symlink → pode quebrar o sistema.
- [ ] `sudo ln -s ... /usr/bin/openssl` falha se já existir (sem `-f`).
- [ ] `./config` com `sudo make install` fora do diretório (falta `cd`).
- [ ] Não instala deps antes do `./config` (make/gcc vêm depois).
- [ ] Recomendado: checar se o sistema atual aceita selevel=1 no
      `/etc/ssl/openssl.cnf` **sem** compilar OpenSSL, que quase sempre basta.

---

## `lvm-free-ubuntu-server.sh` (⚠️ destrutivo)

- [ ] Sem shebang e sem `set -e`.
- [ ] `pvresize /dev/sda3` e o LVM device estão **hard-coded** — pode destruir
      dados em outra máquina. Detectar os devices dinamicamente.
- [ ] `sudo su` no topo (interativo) quebra execução não interativa.
- [ ] Faltam confirmações e checagens (`vgs`, `lvs`, `df -h` antes/depois).
- [ ] Deveria exigir confirmação explícita e avisar sobre backup.

---

## `instalar_simplay.sh` (Wine)

Relativamente ok e **testável no Ubuntu**:
- [ ] Versão do zip hard-coded (1.3.6) — verificar se continua atual.
- [ ] `curl -L` sem `--fail`/`--retry`; sem validação do zip.
- [ ] `winetricks -q dotnet48 ...` pode baixar muito e falhar; sem checagem.
- [ ] `eval "$INSTALAR ..."` com string de comando — frágil.
- [ ] Sem shebang robusto/`set -e`; bom candidato a padronizar.

---

## Padrão a seguir

Ao revisar cada script, alinhar com o `instalar-ubuntu-26-04.sh`:

1. Ordem de preferência: **repos oficiais → repos de terceiros/PPA → `.deb`/RPM
   direto → Flatpak**.
2. `set -uo pipefail`, funções de log, contagem OK/SKIP/FAIL e resumo final.
3. Idempotência (pode rodar de novo sem quebrar).
4. Autorização gráfica quando não houver terminal.
5. Sem armazenar logs/cache dentro do repositório.
