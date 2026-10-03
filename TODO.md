# TODO — pendências dos scripts

Itens obsoletos ou frágeis identificados nos scripts deste repositório.
O script `instalar-ubuntu-26-04.sh` já foi revisado; os demais ainda têm
pendências. Nada aqui foi corrigido ainda — é só um levantamento.

---

## Transversais (afetam vários scripts)

### Azure Data Studio — descontinuado
A Microsoft **aposentou o Azure Data Studio em 28/02/2026**. Os links de
download foram removidos e a instalação tende a falhar. O substituto é o
**VS Code** com as extensões de SQL/Azure (já instalado nos scripts).

Ainda referenciam o Azure Data Studio:
- `programs.sh`
- `programs-arch-linux.sh`
- `programs-crystal-linux.sh`
- `install_macos.sh`

> `instalar-fedora.sh` já foi ajustado (removeu o Azure DS e avisa o usuário).

### RealVNC Viewer — links diretos extintos
A RealVNC removeu os links diretos de download (hoje exige login no portal).
URLs fixas como `VNC-Viewer-7.15.1-Linux-x64.deb` retornam **404**.

Ainda referenciam o RealVNC:
- `programs.sh` (URL fixa morta)
- `programs-arch-linux.sh` (AUR `realvnc-vnc-viewer`, citado 2×)
- `programs-crystal-linux.sh` (`realvnc-vnc-viewer`, citado 2×)
- `install_macos.sh` (cask `vnc-viewer`)

> `instalar-ubuntu-26-04.sh` já resolveu com **Remmina** (VNC/RDP/SSH) via apt.

### MicroSIP — só existe para Windows
`microsip` não tem pacote Linux; requer Wine. Avaliar se vale manter no fluxo.
- `programs-arch-linux.sh`
- `programs-crystal-linux.sh`
- `install_omarchy.sh`

### Zoiper — download não automatizável
O site redireciona para a versão antiga (Zoiper 3) e bloqueia automação.
Abordagem recomendada: modal de navegador com detecção em `~/Downloads`
(implementado no `instalar-ubuntu-26-04.sh`).
- `programs.sh` (wget quebrado)
- `install_macos.sh` (só nota)
- `instalar-fedora.sh` (só aviso)

---

## `programs.sh` (Debian/Ubuntu)

Script antigo, sem tratamento de erro. Pendências específicas:

- [ ] `chrome-gnome-shell` está **renomeado** → usar `gnome-browser-connector`.
- [ ] `inetutils-*` como glob é frágil (depende do shell/expansão) → listar
      pacotes explícitos (`inetutils-telnet`, `inetutils-traceroute`).
- [ ] URL fixa do RealVNC retorna **404**.
- [ ] Link do Azure Data Studio é de versão antiga e está **EOL**.
- [ ] WiFiman na **versão 1.2.8**; a atual é **1.3.0**.
- [ ] `wget` do Zoiper baixa página HTML, não o `.deb`.
- [ ] `sudo rm -r programas` sem confirmação e com `sudo` desnecessário.
- [ ] Sem `set -euo pipefail`, sem resumo/contagem de falhas.
- [ ] Poderia seguir a mesma arquitetura do `instalar-ubuntu-26-04.sh`.

---

## `programs-arch-linux.sh` (Arch)

- [ ] `azuredatastudio-bin` — **EOL**.
- [ ] `realvnc-vnc-viewer` aparece **duplicado** (linhas 59 e 62).
- [ ] `wine-mono microsip gtkglext` — dependências legadas/opcionais; revisar.
- [ ] `source`/uso do yay sem `--needed` consistente; revisar idempotência.
- [ ] Sem tratamento de erro nem resumo final.

---

## `programs-crystal-linux.sh` (Crystal Linux)

- [ ] `azuredatastudio-bin` — **EOL**.
- [ ] `keepass` — provável **typo**; o pacote correto é `keepassxc`.
- [ ] `realvnc-vnc-viewer` aparece **duplicado** (linhas 28 e 31).
- [ ] `microsip`, `gtkglext`, `wine-mono` — revisar necessidade.
- [ ] `winbox3` vs `winbox` — alinhar com a versão atual.

---

## `install_macos.sh` (macOS)

- [ ] cask `azure-data-studio` — **EOL**.
- [ ] cask `vnc-viewer` — verificar se ainda existe no Homebrew (RealVNC mudou).
- [ ] Zoiper/WiFiman não têm fórmula oficial (já documentado no script).
- [ ] Considerar `remmina` como cliente VNC/RDP mantido.

---

## `install_omarchy.sh` (Arch/Omarchy)

- [ ] `microsip` — só Windows (requer Wine); avaliar remoção.
- [ ] Sem tratamento de erro nem resumo final.

---

## `instalar-fedora.sh` (Fedora)

Já está bem estruturado (`set -Eeuo pipefail`, validações, avisos). Sem
pendências críticas. Opcional:
- [ ] Avaliar substituir o Flatpak `org.freedownloadmanager.Manager` por um
      RPM oficial, se houver.

---

## Padrão a seguir

Ao revisar cada script, alinhar com o `instalar-ubuntu-26-04.sh`:

1. Ordem de preferência: **repos oficiais → repos de terceiros/PPA → `.deb`/RPM
   direto → Flatpak**.
2. `set -uo pipefail`, funções de log, contagem OK/SKIP/FAIL e resumo final.
3. Idempotência (pode rodar de novo sem quebrar).
4. Autorização gráfica quando não houver terminal.
5. Sem armazenar logs/cache dentro do repositório.
