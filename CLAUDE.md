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

### Orchestration: the main session
There is no separate "primary agent" — the main session **is** the orchestrator. It delegates via the `Task` tool, reviews sub-agent output, applies fixes, and enforces the quality gates. `.claude/agents/provisioning-architect.md` holds the architectural decision framework the main session follows (it cannot spawn agents itself). **Sub-agents never spawn other sub-agents** — only the main session calls `Task`.

### Sub-Agents (Specialized)
They save **main-session context, not tokens**: each sub-agent runs with a fresh context, so its output doesn't pollute the conversation. Total token spend is usually the same or higher — the trade-off is focus and parallelism, not cost.

| Agent | Model | Does |
|-------|-------|------|
| `package-auditor` | `sonnet` | Validates package names against official repos (apt, dnf, pacman, MacPorts, brew); flags EOL/renamed/missing |
| `script-hardener` | `haiku` | Applies safety patterns: `set -uo pipefail`, error handling, idempotency, logging, dry-run |
| `docs-sync` | `haiku` | Keeps README.md, TODO.md, docs/*.md in sync with script changes |
| `ci-validator` | `haiku` | shellcheck, syntax, `--dry-run`, group isolation — reports pass/fail (never edits scripts) |
| `legacy-migrator` | `sonnet` | Analyzes legacy scripts and rewrites them to the reference architecture |

> Progress UI has no dedicated agent — the main session implements it (pattern in *Progress UI*).

### Shared State & Concurrency (anti-clobber rules)
Sub-agents **do not share context** — each `Task` starts fresh and cannot see another agent's output. The filesystem is the only shared state, and the **main session is the shared memory**: it holds every sub-agent's report and relays the relevant parts into the next agent's prompt. To keep two agents from rewriting the same work:

1. **One file, one agent at a time** — never spawn two agents with overlapping scopes in the same wave; batch only disjoint file sets.
2. **Serialize dependent steps** — e.g. `package-auditor` → `script-hardener` on the same script: wait for the result, then spawn the next.
3. **Scope every prompt** — each `Task` prompt names the exact files the agent may touch ("Edit only `instalar-fedora.sh`") and forbids the rest.
4. **Edit, don't rewrite** — on shared scripts agents use targeted `Edit` (exact-match), never full-file `Write`; if another agent changed the text, the edit fails loudly instead of clobbering. Full-file `Write` is for new files only.
5. **Checkpoint between waves** — after each agent: `git diff --stat`, and commit when the step passes its quality gates, so overlap shows up immediately and is revertible.
6. **Stop on conflict** — an agent whose `Edit` fails on expected text re-reads the file; if it changed unexpectedly, it stops and reports instead of forcing the write.

## Workflows

### Adding/Updating a Script
1. Main session: verify package names for target distro (delegate to `package-auditor` when the list is large)
2. `script-hardener` applies reference architecture patterns
3. Main session: add progress reporting (pattern in *Progress UI*)
4. `docs-sync` updates README.md, TODO.md, docs/*.md
5. `ci-validator` runs shellcheck + `--dry-run` + idempotency checks

### Fixing Legacy Scripts
1. Main session: analyze script against reference architecture
2. `package-auditor` fixes package names
3. `script-hardener` applies patterns
4. `docs-sync` updates TODO.md (marks items done)
5. `ci-validator` validates

### Migrating a Legacy Script (full pipeline, one file at a time)
1. `package-auditor`: audit all package names
2. `legacy-migrator`: rewrite to reference architecture (applying the auditor's fixes)
3. `ci-validator`: quality gates
4. `docs-sync`: TODO.md, README.md, docs/<distro>.md
5. Main session: `git diff --stat` → commit (one commit per migrated script)

### Cross-Platform Consistency Check
1. `package-auditor` compares package lists across distros
2. Main session: decide on canonical package set (framework: `provisioning-architect`)
3. `docs-sync` updates comparison tables

## Configuration Files

### `.claude/agents/*.md`
Agent definitions (name, tools, model, specialized prompts). Currently: `provisioning-architect`, `package-auditor`, `script-hardener`, `docs-sync`, `ci-validator`, `legacy-migrator`.

> No `.claude/settings.json` exists yet — add one when project permissions/hooks are needed.

## Key Conventions

### Naming
- Scripts: `instalar-<distro>-<version>.sh` or `instalar_<distro>.sh`
- Config arrays: `UPPER_SNAKE_CASE` (e.g., `APT_PACKAGES`, `THIRD_PARTY_REPOS`)
- Functions: `snake_case` (e.g., `apt_install`, `install_opencode`)

### Core Functions (single source of truth: `.claude/agents/script-hardener.md`)
| Function | Purpose |
|----------|---------|
| `run_cmd(label, logfile, cmd...)` | spinner + per-command logfile + OK/SKIP/FAIL record; SKIPs under `--dry-run` |
| `record(status, label)` | counters, colored output, `summary.log` |
| `draw_bar(label, current, total)` | `[████░░░] 45% 9/20 ~30s`, TTY-only |
| `confirm(question)` | respects `-y`; zenity/kdialog/osascript when no TTY |
| `ensure_askpass()` / `setup_sudo()` / `prime_sudo()` | graphical sudo (`zenity`/`kdialog`/`osascript`) without TTY |

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