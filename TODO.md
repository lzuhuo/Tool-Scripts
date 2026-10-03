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

## `install_omarchy.sh` (Arch/Omarchy)

- [ ] `microsip` — wrapper Wine (só Windows); avaliar remoção.
- [ ] `gtkglext` — conferir se ainda existe no AUR (no Arch não é oficial).
- [ ] Sem tratamento de erro nem resumo final.

---

## `instalar-fedora.sh` (Fedora)

Já está bem estruturado (`set -Eeuo pipefail`, validações, avisos).
Nomes verificados no `packages.fedoraproject.org`:
- `remmina`, `ulauncher`, `wmctrl`, `wine`, `winetricks`, `zenity`,
  `NetworkManager-openvpn`, `network-manager-applet` → existem.
- Pacotes usados pelo script que **não** existem com esse nome:
  - [ ] `inetutils` → **404**; usar `telnet` e `traceroute` (ambos existem).
  (Obs.: o script atual não usa `inetutils`, só registrar a referência.)
- [ ] `remmina-plugins-vnc` / `remmina-plugins-rdp` — existem por busca, mas a
      página direta dá 404; confirmar no `dnf search remmina`.
- [ ] Avaliar trocar o Flatpak `org.freedownloadmanager.Manager` por RPM, se
      houver.

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
