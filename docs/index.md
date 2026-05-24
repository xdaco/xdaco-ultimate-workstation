# 🧱 PART 1 — CONTAINER IMAGES

---

## 📦 `containers/xdaco-ultimate-base/Containerfile`

The shared base every developer uses. Built `FROM debian:trixie` and includes:

- **Shell/UX:** zsh + Oh My Zsh (agnoster), tmux, Nerd Fonts, starship, modern CLI tools (ripgrep, fzf, bat, eza, zoxide, fd, jq, git-delta, …)
- **Runtimes & build basics:** Python 3 (+uv, +pipx), Node.js 24 (+corepack/pnpm/yarn), Rust (cargo + atuin/just/onefetch), and `build-essential`/`cmake`/`ninja`/`pkg-config` for native modules
- **Data/secrets:** PostgreSQL + SQLite clients, `mycli`/`pgcli`/`litecli`, `sops`, `age`
- **AI (everyone):** Claude Code, OpenCode, headless Chrome/Chromium, and the Torch-CPU MCP stack (mcp-memory-service, sentence-transformers, onnxruntime, mcp-proxy)
- **Remote:** OpenSSH server (the default `CMD`)

Source of truth: [`containers/xdaco-ultimate-base/Containerfile`](containers/xdaco-ultimate-base/Containerfile). Build arg `CONTAINER_USERNAME` (default `xdaco`) sets the user; child images inherit `USER`/`HOME`.

---

## 📦 `containers/xdaco-ultimate-cpp/Containerfile`

C/C++ toolchain on top of the base — `clang`/`clangd`/`lld`/`lldb`/`llvm`, `gdb`, `valgrind`, `cppcheck`, `clang-format`/`clang-tidy`, `meson`, `ccache`, `bear`, autotools. (Basic `gcc`/`g++`/`make`/`cmake`/`ninja` are already in the base.)

```Dockerfile
FROM docker.io/1xdaco/xdaco-ultimate-base:latest

USER root
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
    clang clangd lld lldb llvm clang-format clang-tidy cppcheck \
    gdb valgrind ccache bear meson \
    autoconf automake libtool \
    ; \
    rm -rf /var/lib/apt/lists/*

USER ${USER}
WORKDIR ${HOME}
```

---

## 📦 `containers/xdaco-ultimate-php/Containerfile`

PHP toolchain on top of the base — `php-cli` + common extensions (mbstring, xml, curl, zip, intl, bcmath, gd, mysql, pgsql, sqlite3) and Composer.

```Dockerfile
FROM docker.io/library/composer:2.9 AS composer-builder

FROM docker.io/1xdaco/xdaco-ultimate-base:latest

COPY --from=composer-builder /usr/bin/composer /usr/local/bin/composer

USER root
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
    php-cli php-mbstring php-xml php-curl php-zip php-intl php-bcmath php-gd \
    php-mysql php-pgsql php-sqlite3 \
    ; \
    rm -rf /var/lib/apt/lists/*

USER ${USER}
WORKDIR ${HOME}
```

---

## 📦 `containers/xdaco-ultimate-pdf/Containerfile`

```Dockerfile
# Web-based PDF server (Stirling PDF)
FROM docker.io/frooodle/s-pdf@latest

# Expose default web port
EXPOSE 8080
```

_(Or pull directly, no build needed.)_

---

# 🏗 PART 2 — BUILD COMMANDS

`cpp` and `php` are `FROM docker.io/1xdaco/xdaco-ultimate-base:latest`. Build **base first**, then the stack image(s) you need, tagged as `docker.io/1xdaco/...` so the `FROM` reference resolves.

## Pre-built (Docker Hub)

```bash
podman pull docker.io/1xdaco/xdaco-ultimate-base:latest
podman pull docker.io/1xdaco/xdaco-ultimate-cpp:latest    # C/C++ devs
podman pull docker.io/1xdaco/xdaco-ultimate-php:latest    # PHP devs
podman pull docker.io/frooodle/s-pdf
podman tag docker.io/frooodle/s-pdf xdaco-ultimate-pdf
```

## Local Build (uses username "xdaco")

```bash
podman build -t docker.io/1xdaco/xdaco-ultimate-base:latest containers/xdaco-ultimate-base
podman build -t docker.io/1xdaco/xdaco-ultimate-cpp:latest containers/xdaco-ultimate-cpp
podman build -t docker.io/1xdaco/xdaco-ultimate-php:latest containers/xdaco-ultimate-php
podman pull docker.io/frooodle/s-pdf
podman tag docker.io/frooodle/s-pdf xdaco-ultimate-pdf
```

## Custom Username Build

Use the `CONTAINER_USERNAME` build argument (base only; it propagates via `USER`/`HOME`):

```bash
CONTAINER_USER=myuser
podman build --build-arg CONTAINER_USERNAME=$CONTAINER_USER -t docker.io/1xdaco/xdaco-ultimate-base:latest containers/xdaco-ultimate-base
podman build -t docker.io/1xdaco/xdaco-ultimate-cpp:latest containers/xdaco-ultimate-cpp
podman build -t docker.io/1xdaco/xdaco-ultimate-php:latest containers/xdaco-ultimate-php
```

**Note:** All child images inherit `USER`/`HOME` from base; use the same `CONTAINER_USERNAME` when building the base.

---

# 🚀 PART 3 — RUN COMMANDS

## Main Dev Container

> Runs **rootless** as the container user (`xdaco`); sshd listens on **2222** inside the container. Authorize your login by mounting your public key at `/run/host-pubkey` (shown below). A per-container host key is generated on first start.

**Default username (xdaco):**
```bash
podman run -d \
  --name xdaco-ultimate-devcontainer \
  --hostname xdaco-ultimate-devcontainer \
  -p 2222:2222 \
  -v ~/.ssh/id_ed25519.pub:/run/host-pubkey:ro \
  -v ~/Downloads/mhs_workspace:/home/xdaco/workspace:Z \
  docker.io/1xdaco/xdaco-ultimate-base:latest
```

**Custom username:**  
If you built base with a custom `CONTAINER_USERNAME`, adjust the volume mount path:
```bash
CONTAINER_USER=myuser
podman run -d \
  --name xdaco-ultimate-devcontainer \
  --hostname xdaco-ultimate-devcontainer \
  -p 2222:2222 \
  -v ~/.ssh/id_ed25519.pub:/run/host-pubkey:ro \
  -v ~/Downloads/mhs_workspace:/home/$CONTAINER_USER/workspace:Z \
  docker.io/1xdaco/xdaco-ultimate-base:latest
```

## PDF Server

```bash
podman run -d \
  --name xdaco-ultimate-pdf \
  -p 8080:8080 \
  -v stirling-pdf-data:/usr/share/stirling-pdf \
  xdaco-ultimate-pdf
```

---

# 🔑 PART 4 — SSH CONFIG

`~/.ssh/config`

**Default username (xdaco):**
```ssh
Host ultimate-devcontainer
  HostName localhost
  Port 2222
  User xdaco
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
```

**Custom username:**
If you built with a custom `CONTAINER_USERNAME`, use that username:
```ssh
Host ultimate-devcontainer
  HostName localhost
  Port 2222
  User myuser
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
```

Login:

```bash
ssh ultimate-devcontainer -p 2222
```

---

# 🔄 PART 5 — SYSTEMD USER SERVICE

`~/.config/systemd/user/xdaco-ultimate-devcontainer.service`

**Default username (xdaco):**
```ini
[Unit]
Description=XDACO Ultimate Devcontainer
After=network-online.target

[Service]
Restart=always
ExecStart=/usr/bin/podman run --rm \
  --name xdaco-ultimate-devcontainer \
  --hostname xdaco-ultimate-devcontainer \
  -p 2222:2222 \
  -v %h/.ssh/id_ed25519.pub:/run/host-pubkey:ro \
  -v %h/Downloads/mhs_workspace:/home/xdaco/workspace:Z \
  docker.io/1xdaco/xdaco-ultimate-base:latest

ExecStop=/usr/bin/podman stop xdaco-ultimate-devcontainer

[Install]
WantedBy=default.target
```

**Custom username:**  
If you built base with a custom `CONTAINER_USERNAME`, adjust the volume mount path:
```ini
[Unit]
Description=XDACO Ultimate Devcontainer
After=network-online.target

[Service]
Restart=always
ExecStart=/usr/bin/podman run --rm \
  --name xdaco-ultimate-devcontainer \
  --hostname xdaco-ultimate-devcontainer \
  -p 2222:2222 \
  -v %h/.ssh/id_ed25519.pub:/run/host-pubkey:ro \
  -v %h/Downloads/mhs_workspace:/home/myuser/workspace:Z \
  docker.io/1xdaco/xdaco-ultimate-base:latest

ExecStop=/usr/bin/podman stop xdaco-ultimate-devcontainer

[Install]
WantedBy=default.target
```

Enable:

```bash
systemctl --user enable --now xdaco-ultimate-devcontainer
```

---

# 🔐 PART 6 — SBOM + COSIGN

```bash
syft podman:docker.io/1xdaco/xdaco-ultimate-base:latest -o spdx-json > sbom.json
cosign sign --key cosign.key docker.io/1xdaco/xdaco-ultimate-base:latest
```

---

# 🧠 PART 7 — DIRENV PROJECT TEMPLATE

`.envrc`

```bash
use podman docker.io/1xdaco/xdaco-ultimate-base:latest
layout python
```

---

# 🧰 PART 8 — UPDATED BOOTSTRAP SCRIPT DELTAS

## Bootstrap Scripts

The bootstrap scripts (`scripts/bootstrap-mac.zsh` and `scripts/bootstrap-linux.sh`) configure the **host OS** user via the `TARGET_USER` parameter or environment variable (defaults to `mhs` on both platforms).

The **container** username is configured separately via the `CONTAINER_USERNAME` build argument when building images (defaults to `xdaco`).

### Features

- **Smart package checking**: Skips already-installed packages/apps
- **Sudo password caching**: Asks for password once and reuses it
- **Robust rpm-ostree handling**: Checks if packages are installed, staged, or provided by base
- **Architecture-aware**: Different flatpak app lists for x86_64 and aarch64
- **Flatpak app guards**: Only installs missing applications
- **Font installation**: Installs Nerd Fonts (Agave + Meslo) for better terminal experience
- **Alias management**: Downloads and sources xdaco aliases for git shortcuts
- **Idempotent operations**: Safe to run multiple times

### Linux Bootstrap (`scripts/bootstrap-linux.sh`)

**Compatibility:** Written in POSIX-compliant shell (`sh`) to work on fresh installs where bash or zsh may not be available.

**What it does:**
1. Creates user if it doesn't exist (default: `mhs`)
2. Sets MTU for network interface (`enp0s1`)
3. Installs rpm-ostree packages: `zsh`, `git`, `tailscale`, `podman`, `alacritty`, `lsd`, `tmux`
4. Adds Sublime Text repository (x86_64 only)
5. Adds Flathub remote for flatpak apps
6. Installs flatpak GUI applications (architecture-specific lists)
7. Installs Nerd Fonts (Agave + Meslo) for better terminal experience
8. Installs `chezmoi` for dotfiles management
9. Installs `starship` prompt (optional)
10. Installs `oh-my-zsh` if zsh is available
11. Downloads and configures xdaco aliases for git shortcuts

**Usage:**
```bash
# Use default username "mhs"
./scripts/bootstrap-linux.sh

# Use custom username
./scripts/bootstrap-linux.sh myusername

# Or via environment variable
TARGET_USER=myusername ./scripts/bootstrap-linux.sh
```

**Note:** 
- Some packages may fail to install on aarch64 architecture
- Flatpak apps are architecture-aware: x86_64 gets full list including Sublime Text, Texmaker, NoMachine, and Whatsie; aarch64 gets a reduced list without these apps
- Sublime Text repository is only added on x86_64 systems

### macOS Bootstrap (`scripts/bootstrap-mac.zsh`)

**What it does:**
1. Verifies you're logged in as the target user
2. Requests sudo access (keeps it alive during script execution)
3. Updates system and installs Xcode Command Line Tools
4. Installs Homebrew if needed
5. Installs host tools: `podman`, `podman-desktop`, `tailscale`, `gh`, `git`, `zsh`, `mas`
   - Handles tailscale linking issues automatically
6. Installs GUI applications via Homebrew Cask (with existence checks to avoid conflicts)
7. Configures SSH access to container
8. Installs Nerd Fonts (Agave + Meslo) for better terminal experience
9. Downloads and configures xdaco aliases for git shortcuts

**Note:** The script checks if applications already exist before installing to prevent "App already exists" errors.

**Usage:**
```bash
# Use default username "mhs"
./scripts/bootstrap-mac.zsh

# Use custom username
./scripts/bootstrap-mac.zsh myusername

# Or via environment variable
TARGET_USER=myusername CONTAINER_USER=mycontaineruser ./scripts/bootstrap-mac.zsh
```

### macOS

```bash
# Build (tag as docker.io/1xdaco/... so cpp/php FROMs resolve)
podman build -t docker.io/1xdaco/xdaco-ultimate-base:latest containers/xdaco-ultimate-base
podman build -t docker.io/1xdaco/xdaco-ultimate-cpp:latest containers/xdaco-ultimate-cpp
podman build -t docker.io/1xdaco/xdaco-ultimate-php:latest containers/xdaco-ultimate-php

podman rm -f xdaco-ultimate-devcontainer || true
podman run -d \
  --name xdaco-ultimate-devcontainer \
  --hostname xdaco-ultimate-devcontainer \
  -p 2222:2222 \
  -v ~/.ssh/id_ed25519.pub:/run/host-pubkey:ro \
  -v ~/Downloads/mhs_workspace:/home/xdaco/workspace:Z \
  docker.io/1xdaco/xdaco-ultimate-base:latest
```

### Linux

Same build and run commands as macOS.

---

# 📘 PART 9 — UPDATED GUIDE (AUTHORITATIVE)

## 🧠 XDACO Ultimate Stateless Workstation v1.0.0

> One identity. One container. Any machine. Ten minutes.

---

## 🏗 Architecture

```
Host OS (macOS / Fedora Atomic)
│  GUI apps only
│  Podman rootless
│
├── xdaco-ultimate-base (OCI)
│   ├── xdaco-ultimate-cpp
│   └── xdaco-ultimate-php
│
└── xdaco-ultimate-pdf (external)
```

---

## 👤 Identity

| Component | User                              | Configurable Via               |
| --------- | --------------------------------- | ------------------------------ |
| Host OS   | mhs (default on both platforms)   | `TARGET_USER` parameter/env var in bootstrap scripts |
| Container | xdaco (default)                   | `CONTAINER_USERNAME` build arg |
| SSH       | ssh ultimate-devcontainer -p 2222 | Matches container username     |

**Note:** The container username defaults to `xdaco` but can be customized via the `CONTAINER_USERNAME` build argument when building images. All volume mounts and SSH configs must match the configured container username.

---

## 📂 Workspace Mount

**Default username (xdaco):**
```
Host:      ~/Downloads/mhs_workspace
Container: /home/xdaco/workspace
```

**Custom username:**
```
Host:      ~/Downloads/mhs_workspace
Container: /home/myuser/workspace
```

**Note:** Adjust the container path based on your `CONTAINER_USERNAME` build argument.

---

## 🔐 Dotfiles

Installation instructions:

```bash
# Clone the dotfiles repository
git clone https://github.com/xdaco/dotfiles.git ~/.dotfiles

# Checkout the workstation branch
cd ~/.dotfiles
git checkout xdaco/worksation

# Install on macOS
make
```

**Note:** The Linux part is outdated and not tested. Only macOS installation is currently supported.

## 🎨 Aliases & Fonts

### xdaco Aliases

Git aliases and helper functions are automatically installed:
- Downloaded to `~/xdaco_aliases.sh` during bootstrap/container build
- Sourced from `.zshrc` on shell startup
- Provides shortcuts like `g`, `gs`, `gd`, `gl`, `gp` for git operations
- Includes cross-platform permission helpers (`lsh`, `lsp`)
- Works offline after initial download

### Nerd Fonts

Nerd Fonts (Agave + Meslo) are installed for better terminal experience:
- Installed to `~/.local/share/fonts/`
- Automatically configured in containers
- Installed by bootstrap scripts on host systems

---

## 🔑 Secrets

| Tool | Purpose            |
| ---- | ------------------ |
| age  | Encryption         |
| sops | Structured secrets |
| pass | Password manager   |

---

## 🔄 Container Auto-Update

```bash
systemctl --user enable --now xdaco-ultimate-devcontainer
podman auto-update
```

---

## 🔁 Per-Project Devcontainers

`.envrc`

```bash
use podman docker.io/1xdaco/xdaco-ultimate-base:latest
```

```bash
direnv allow
```

---

## 🧰 SSH Access

```bash
ssh ultimate-devcontainer -p 2222
```

---

## 📦 TOOLING MATRIX

### Container CLI

- zsh, oh-my-zsh (Agnoster theme), gitstatus, tmux, neovim
- direnv, zoxide, atuin, starship (installed, not default)
- tree, fd, bat, jq, ripgrep, eza, lsd, less, glow
- diff-so-fancy, delta, rsync, ncdu, duf, fdupes
- p7zip, zip, pass, stow, skopeo
- nmap, asciinema, wego
- htop, btop, cpufetch, neofetch, onefetch
- gcc, g++, make, python3, nodejs, npm, composer
- mycli, pgcli, postgrest (ai/db images)
- opencode, claude-code (ai image)
- mcp-memory-service via pipx, CPU-only Torch (ai image)
- podman, podman-compose
- age, sops, gnupg
- syft (SBOM), cosign (signing)
- xdaco aliases (git shortcuts and helpers)
- Nerd Fonts (Agave + Meslo) for terminal

---

### GUI Apps (macOS + Fedora)

**macOS (via Homebrew Cask):**
- alacritty, ghostty
- visual-studio-code, sublime-text, texmaker
- vlc, brave-browser, gimp
- cursor, balenaetcher, bitwarden, nomachine, slack
- inkscape, obsidian
- utm, alfred, whatsapp

**Linux (via Flatpak, architecture-specific):**

**x86_64:**
- com.visualstudio.code, com.sublimetext.three, net.xm1math.Texmaker
- org.videolan.VLC, com.brave.Browser, org.gimp.GIMP
- com.bitwarden.desktop, com.nomachine.nxplayer, com.slack.Slack
- org.inkscape.Inkscape, md.obsidian.Obsidian, com.ktechpit.whatsie
- org.libreoffice.LibreOffice, io.github.alainm23.planify, com.rustdesk.RustDesk

**aarch64:**
- com.visualstudio.code, org.videolan.VLC, com.brave.Browser
- com.quexten.Goldwarden, org.gimp.GIMP, com.ktechpit.whatsie
- org.inkscape.Inkscape, md.obsidian.Obsidian
- org.libreoffice.LibreOffice, io.github.alainm23.planify, com.rustdesk.RustDesk

**Note:** Some apps (Sublime Text, Texmaker, NoMachine, Bitwarden) are not available on aarch64.

---

### macOS Only

- utm
- alfred
- goodnotes
- sideloadly

---

### Linux Only

- planify

---

# 🏆🏆🏆🏆
