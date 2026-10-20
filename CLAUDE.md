# Tool-Scripts — Project Documentation

## Overview

A collection of utility scripts to automate installation, configuration, and maintenance of development and personal environments across Linux distributions (Ubuntu, Zorin OS, Fedora, Arch, Crystal Linux) and macOS.

## Repository Structure

```
Tool-Scripts/
├── CLAUDE.md                    # This file
├── README.md                    # Project overview & script catalog
├── TODO.md                      # Known issues & improvement backlog
├── instalar-ubuntu-26-04.sh     # ✅ Reference implementation (Ubuntu 26.04)
├── instalar_zorin.sh            # ✅ Zorin OS 18.x (Ubuntu 24.04 base)
├── instalar-macos.sh            # ✅ macOS (Intel x86_64 via direct download + MacPorts)
├── instalar-fedora.sh           # ⚠️ Fedora (needs package name fixes)
├── programs.sh                  # ⚠️ Debian/Ubuntu legacy (many issues)
├── programs-arch-linux.sh       # ⚠️ Arch Linux (AUR package name issues)
├── programs-crystal-linux.sh    # ⚠️ Crystal Linux (Arch derivative)
├── install_omarchy.sh           # ⚠️ Omarchy/Arch (minimal)
├── instalar_simplay.sh          # ⚠️ SimPlay via Wine
├── sql-2008.sh                  # ⚠️ Legacy OpenSSL for SQL Server 2008
├── lvm-free-ubuntu-server.sh    # ⚠️ Destructive LVM resize
├── programs.sh                  # ⚠️ Generic Debian/Ubuntu
└── docs/
    ├── ubuntu.md                # Detailed Ubuntu guide
    └── macos.md                 # Detailed macOS guide
```

## Script Status Matrix

| Script | Status | Architecture | Notes |
|--------|--------|--------------|-------|
| `instalar-ubuntu-26-04.sh` | ✅ **Reference** | Ubuntu 26.04 LTS | Idempotent, error handling, progress UI, graphical sudo |
| `instalar_zorin.sh` | ✅ **Complete** | Zorin OS 18.x | Adds progress bar + ETA, live-log, verbose flags |
| `instalar-macos.sh` | ✅ **Complete** | macOS (Intel/ARM) | Direct download + MacPorts (no Homebrew for Intel) |
| `instalar-fedora.sh` | 🔧 **Needs fixes** | Fedora | Package name corrections needed |
| `programs.sh` | 🔧 **Legacy** | Debian/Ubuntu | Many outdated items, no error handling |
| `programs-arch-linux.sh` | 🔧 **Needs fixes** | Arch Linux | AUR package names, Qt5 removal issues |
| `programs-crystal-linux.sh` | 🔧 **Needs fixes** | Crystal Linux | AUR issues, `ame` helper verification |
| `install_omarchy.sh` | 🔧 **Minimal** | Omarchy/Arch | Basic script, needs hardening |
| `instalar_simplay.sh` | 🔧 **Needs polish** | Ubuntu + Wine | Hardcoded versions, no validation |
| `sql-2008.sh` | ⚠️ **Dangerous** | Linux | Compiles old OpenSSL, overwrites system binary |
| `lvm-free-ubuntu-server.sh` | ⚠️ **Destructive** | Ubuntu Server | Hardcoded devices, no safety checks |

## Core Architecture (Reference: `instalar-ubuntu-26-04.sh` / `instalar_zorin.sh`)

### Installation Preference Order
1. **Official repos** (apt/dnf/pacman) — update with system
2. **Third-party APT repos / PPAs** — also update via apt
3. **Direct `.deb`/`.rpm`/`.dmg`/`.pkg`** — stable URLs
4. **Flatpak/Flathub** — only when no reliable native package

### Required Patterns for All Scripts
- `set -uo pipefail` (not `set -e` — allows controlled error handling)
- Logging to `~/.local/share/<script>/logs/`
- Cache in `~/.cache/<script>/`
- OK/SKIP/FAIL counters with final summary
- Idempotent (re-runnable without breaking)
- Graphical sudo via `zenity`/`osascript` when no TTY
- `--dry-run`, `-y/--yes`, `--only <group>`, `--no-self-update` flags
- Optional self-update via `REPO_RAW_URL`

### Progress UI (Zorin script adds)
- Global stage header: `Etapa X/N [XX%]`
- Per-stage progress bar with item counts + ETA
- Spinner showing current action
- `--live-log`, `--no-color`, `-v/--verbose` flags

## Development Tools (installed via `dev` group)
- **opencode**: `~/.opencode/bin` via `https://opencode.ai/install`
- **nvm + Node LTS**: official nvm installer
- **.NET SDK**: `dotnet-install.sh` in `~/.dotnet` (channels 10.0, 8.0)
- Env persisted in `~/.config/<script>/env.sh`, loaded by shell RC files

## Agent Organization

### Primary Agent: `provisioning-architect`
Manages the overall provisioning strategy, coordinates sub-agents, makes architectural decisions about package sources, installation order, and cross-platform consistency.

### Sub-Agents (Specialized, Cost-Effective)
1. **`package-auditor`** — Validates package names against official repos (apt, dnf, pacman, MacPorts, brew), flags EOL/renamed/missing packages
2. **`script-hardener`** — Applies safety patterns: `set -uo pipefail`, error handling, idempotency, logging, dry-run support
3. **`progress-ui`** — Implements progress bars, spinners, ETA, live-log, verbose/quiet modes
4. **`docs-sync`** — Keeps README.md, TODO.md, docs/*.md in sync with script changes
5. **`ci-validator`** — Runs shellcheck, bats tests, dry-run validation in CI
6. **`legacy-migrator`** — Migrates legacy scripts (`programs.sh`, `programs-arch-linux.sh`, etc.) to reference architecture

## Workflows

### Adding/Updating a Script
1. `package-auditor` verifies all package names for target distro
2. `script-hardener` applies reference architecture patterns
3. `progress-ui` adds progress reporting
4. `docs-sync` updates documentation
5. `ci-validator` runs validation

### Fixing Legacy Scripts
1. `legacy-migrator` analyzes script against reference
2. `package-auditor` fixes package names
3. `script-hardener` applies patterns
4. `docs-sync` updates TODO.md (marks items done)

### Cross-Platform Consistency Check
1. `package-auditor` compares package lists across distros
2. `provisioning-architect` decides on canonical package set
3. `docs-sync` updates comparison tables

## Configuration Files

### `.claude/settings.json`
Project-specific permissions and hooks.

### `.claude/agents/*.md`
Agent definitions with specialized prompts.

## Key Conventions

### Naming
- Scripts: `instalar-<distro>-<version>.sh` or `instalar_<distro>.sh`
- Config arrays: `UPPER_SNAKE_CASE` (e.g., `APT_PACKAGES`, `THIRD_PARTY_REPOS`)
- Functions: `snake_case` (e.g., `apt_install`, `install_opencode`)

### Error Handling
```bash
run_cmd() {
    local label="$1" logfile="$2"; shift 2
    if [ "$DRY_RUN" -eq 1 ]; then record SKIP "$label (dry-run)"; return 0; fi
    spinner_start "$label"
    if "$@" >>"$logfile" 2>&1; then record OK "$label"; return 0; fi
    record FAIL "$label (veja $logfile)"; return 1
}
```

### Progress Bar (from Zorin script)
```bash
draw_bar() {
    [ -t 2 ] || return 0
    local label="$1" current="$2" total="$3"
    local pct=$(( current * 100 / total ))
    # ... renders [████░░░] 45% 9/20 ~30s
}
```

### Graphical Sudo
```bash
ensure_askpass() {
    # Creates /usr/local/bin/sudo-askpass using zenity/kdialog
    # Configures /etc/sudo.conf, /etc/sudoers.d/, /etc/profile.d/
}
```

## Testing Checklist

Before committing any script:
- [ ] `shellcheck script.sh` passes
- [ ] `./script.sh --dry-run` runs without errors
- [ ] `./script.sh --only apt` (or each group) works independently
- [ ] Idempotent: running twice produces only SKIP/OK
- [ ] Logs written to `~/.local/share/<script>/logs/`
- [ ] Summary shows OK/SKIP/FAIL counts
- [ ] Graphical sudo works without TTY (test with `pkexec`)

## References

- [Ubuntu 26.04 Packages](https://packages.ubuntu.com/noble/)
- [Zorin OS 18 (Ubuntu 24.04 base) Packages](https://packages.ubuntu.com/noble/)
- [Fedora Packages](https://packages.fedoraproject.org/)
- [Arch Linux Packages](https://archlinux.org/packages/)
- [AUR](https://aur.archlinux.org/)
- [MacPorts Ports](https://ports.macports.org/)
- [Homebrew Formulae](https://formulae.brew.sh/)
- [GNOME Extensions](https://extensions.gnome.org/)