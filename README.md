# 🧱 PART 1 — CONTAINER IMAGES

---

## 📦 `containers/xdaco-ultimate-base/Containerfile`

```Dockerfile
# -----------------------------------------------------------------------------
# xdaco-ultimate-base — Debian Trixie rootless base for stateless workstation
# -----------------------------------------------------------------------------
FROM docker.io/library/debian:trixie

ARG CONTAINER_USERNAME=xdaco

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV USER=${CONTAINER_USERNAME}
ENV HOME=/home/${CONTAINER_USERNAME}
ENV PATH="$HOME/.cargo/bin:$HOME/.npm-global/bin:$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin"

# -----------------------------------------------------------------------------
# System packages
# -----------------------------------------------------------------------------
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
    pkg-config libssl-dev cmake libgit2-dev \
    sudo curl wget gnupg2 lsb-release ca-certificates \
    zsh git tmux openssh-server rsync \
    build-essential gcc g++ make bash nano \
    python3 python3-venv python3-pip \
    nodejs npm php-cli php-mbstring unzip \
    bash-completion tree fzf fd-find bat jq \
    ripgrep ncdu htop btop p7zip-full zip skopeo \
    fdupes duf nmap cmus asciinema pass \
    stow neovim direnv age wego eza \
    zoxide git-delta rustc  cargo \
    fontconfig passwd  \
    ; \
    rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# UV (Python package manager)
# -----------------------------------------------------------------------------
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# -----------------------------------------------------------------------------
# diff-so-fancy
# -----------------------------------------------------------------------------
RUN curl -fsSL \
    https://github.com/so-fancy/diff-so-fancy/releases/download/v1.4.4/diff-so-fancy \
    -o /usr/local/bin/diff-so-fancy \
    && chmod +x /usr/local/bin/diff-so-fancy

# -----------------------------------------------------------------------------
# User + sudo
# -----------------------------------------------------------------------------
RUN set -eux; \
    /usr/sbin/useradd -m -s /usr/bin/zsh ${CONTAINER_USERNAME} && \
    echo "${CONTAINER_USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${CONTAINER_USERNAME} && \
    chmod 0440 /etc/sudoers.d/${CONTAINER_USERNAME}

# ----------------------------------------- ------------------------------------
# SSH daemon
# -----------------------------------------------------------------------------
RUN set -eux; \
    mkdir -p /var/run/sshd; \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config; \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config

EXPOSE 22

# -----------------------------------------------------------------------------
# Switch to user
# -----------------------------------------------------------------------------
USER ${USER}
WORKDIR ${HOME}

# -----------------------------------------------------------------------------
# Rust based tools (rootless)
# -----------------------------------------------------------------------------
RUN set -eux; \
    cargo install just || true; \
    cargo install onefetch || true; \
    cargo install atuin || true

# -----------------------------------------------------------------------------
# Oh My Zsh + Agnoster + Fonts + Starship
# -----------------------------------------------------------------------------
RUN set -eux; \
    \
    # Oh My Zsh (official unattended)
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended; \
    \
    # Agnoster theme
    git clone --depth=1 https://github.com/agnoster/agnoster-zsh-theme.git /tmp/agnoster; \
    cp /tmp/agnoster/agnoster.zsh-theme "$HOME/.oh-my-zsh/custom/themes/agnoster.zsh-theme"; \
    rm -rf /tmp/agnoster; \
    sed -i 's/^ZSH_THEME=.*/ZSH_THEME="agnoster"/' "$HOME/.zshrc"; \
    \
    # Powerline fonts
    git clone --depth=1 https://github.com/powerline/fonts.git /tmp/powerline-fonts; \
    /tmp/powerline-fonts/install.sh; \
    rm -rf /tmp/powerline-fonts; \
    \
    # Nerd Fonts (Agave + Meslo)
    mkdir -p "$HOME/.local/share/fonts"; \
    curl -fsSL https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/Agave.zip -o /tmp/Agave.zip; \
    curl -fsSL https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/Meslo.zip -o /tmp/Meslo.zip; \
    unzip -qo /tmp/Agave.zip -d "$HOME/.local/share/fonts"; \
    unzip -qo /tmp/Meslo.zip -d "$HOME/.local/share/fonts"; \
    fc-cache -fv; \
    rm -f /tmp/Agave.zip /tmp/Meslo.zip; \
    \
    # Starship (installed but not enabled)
    curl -fsSL https://starship.rs/install.sh | sh -s -- -y; \
    printf '\n# Starship (optional — disabled by default)\n# eval "$(starship init zsh)"\n' >> "$HOME/.zshrc"; \
    \
    # Download and load xdaco aliases
    curl -fsSL https://raw.githubusercontent.com/xdaco/bash-resources/master/xdaco_aliases.sh -o "$HOME/xdaco_aliases.sh"; \
    chmod +x "$HOME/xdaco_aliases.sh"; \
    printf '\n# Load xdaco aliases\nif [ -f "$HOME/xdaco_aliases.sh" ]; then\n  source "$HOME/xdaco_aliases.sh"\nfi\n' >> "$HOME/.zshrc"

# -----------------------------------------------------------------------------
# Entrypoint
# -----------------------------------------------------------------------------
WORKDIR ${HOME}
CMD ["/usr/sbin/sshd", "-D"]
```

---

## 📦 `containers/xdaco-ultimate-dev/Containerfile`

```Dockerfile
# -----------------------------------------------------------------------------
# Multi-stage builders
# -----------------------------------------------------------------------------
FROM docker.io/library/composer:2.6 AS composer-builder
FROM docker.io/chatwork/sops:3.11.0 AS sops-builder

# -----------------------------------------------------------------------------
# Main image
# -----------------------------------------------------------------------------
FROM localhost/xdaco-ultimate-base:latest

# Copy binaries from builders
COPY --from=composer-builder /usr/bin/composer /usr/local/bin/composer
COPY --from=sops-builder /usr/local/bin/sops  /usr/local/bin/sops

USER root
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
    postgresql-client sqlite3 \
    ; \
    rm -rf /var/lib/apt/lists/*

USER ${USER}
WORKDIR ${HOME}
```

---

## 📦 `containers/xdaco-ultimate-ai/Containerfile`

```Dockerfile
FROM localhost/xdaco-ultimate-base:latest

# AI tooling can be added here
USER ${USER}
# -----------------------------------------------------------------------------
# NPM rootless configuration
# -----------------------------------------------------------------------------
RUN mkdir -p "$HOME/.npm-global" && \
    npm config set prefix "$HOME/.npm-global" && \
    npm install -g @anthropic-ai/claude-code

# -----------------------------------------------------------------------------
# Python rootless installation with pipx
# -----------------------------------------------------------------------------
RUN python3 -m pip install --user --break-system-packages pipx
RUN python3 -m pipx ensurepath
RUN python3 -m pipx install mcp-memory-service

# -----------------------------------------------------------------------------
# Install Opencode (rootless)
# -----------------------------------------------------------------------------
RUN curl -fsSL https://opencode.ai/install | bash
ENV PATH="$HOME/.opencode/bin:$PATH"

USER ${USER}
WORKDIR ${HOME}
```

---

## 📦 `containers/xdaco-ultimate-db/Containerfile`

```Dockerfile
FROM localhost/xdaco-ultimate-ai:latest

USER ${USER}
RUN python3 -m pipx install mycli pgcli
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

## Default Build (uses username "xdaco")

```bash
podman build -t xdaco-ultimate-base containers/xdaco-ultimate-base
podman build -t xdaco-ultimate-dev containers/xdaco-ultimate-dev
podman build -t xdaco-ultimate-ai containers/xdaco-ultimate-ai
podman build -t xdaco-ultimate-db containers/xdaco-ultimate-db
podman pull docker.io/frooodle/s-pdf
podman tag docker.io/frooodle/s-pdf xdaco-ultimate-pdf
```

## Custom Username Build

To build with a custom container username, use the `CONTAINER_USERNAME` build argument:

```bash
CONTAINER_USER=myuser
podman build --build-arg CONTAINER_USERNAME=$CONTAINER_USER -t xdaco-ultimate-base containers/xdaco-ultimate-base
podman build --build-arg CONTAINER_USERNAME=$CONTAINER_USER -t xdaco-ultimate-dev containers/xdaco-ultimate-dev
podman build --build-arg CONTAINER_USERNAME=$CONTAINER_USER -t xdaco-ultimate-ai containers/xdaco-ultimate-ai
podman build --build-arg CONTAINER_USERNAME=$CONTAINER_USER -t xdaco-ultimate-db containers/xdaco-ultimate-db
```

**Note:** All child images must use the same `CONTAINER_USERNAME` as the base image they inherit from.

---

# 🚀 PART 3 — RUN COMMANDS

## Main Dev Container

**Default username (xdaco):**
```bash
podman run -d \
  --name xdaco-ultimate-devcontainer \
  --hostname xdaco-ultimate-devcontainer \
  -p 2222:22 \
  -v ~/Downloads/mhs_workspace:/home/xdaco/workspace:Z \
  xdaco-ultimate-dev
```

**Custom username:**
If you built with a custom `CONTAINER_USERNAME`, adjust the volume mount path accordingly:
```bash
CONTAINER_USER=myuser
podman run -d \
  --name xdaco-ultimate-devcontainer \
  --hostname xdaco-ultimate-devcontainer \
  -p 2222:22 \
  -v ~/Downloads/mhs_workspace:/home/$CONTAINER_USER/workspace:Z \
  xdaco-ultimate-dev
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
  -p 2222:22 \
  -v %h/Downloads/mhs_workspace:/home/xdaco/workspace:Z \
  xdaco-ultimate-dev

ExecStop=/usr/bin/podman stop xdaco-ultimate-devcontainer

[Install]
WantedBy=default.target
```

**Custom username:**
If you built with a custom `CONTAINER_USERNAME`, adjust the volume mount path:
```ini
[Unit]
Description=XDACO Ultimate Devcontainer
After=network-online.target

[Service]
Restart=always
ExecStart=/usr/bin/podman run --rm \
  --name xdaco-ultimate-devcontainer \
  --hostname xdaco-ultimate-devcontainer \
  -p 2222:22 \
  -v %h/Downloads/mhs_workspace:/home/myuser/workspace:Z \
  xdaco-ultimate-dev

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
syft xdaco-ultimate-dev -o spdx-json > sbom.json
cosign sign --key cosign.key xdaco-ultimate-dev
```

---

# 🧠 PART 7 — DIRENV PROJECT TEMPLATE

`.envrc`

```bash
use podman xdaco-ultimate-dev
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
# Build with default container username (xdaco)
podman build -t xdaco-ultimate-base containers/xdaco-ultimate-base
podman build -t xdaco-ultimate-dev containers/xdaco-ultimate-dev
podman build -t xdaco-ultimate-db containers/xdaco-ultimate-db
podman build -t xdaco-ultimate-ai containers/xdaco-ultimate-ai

podman rm -f xdaco-ultimate-devcontainer || true
podman run -d \
  --name xdaco-ultimate-devcontainer \
  --hostname xdaco-ultimate-devcontainer \
  -p 2222:22 \
  -v ~/Downloads/mhs_workspace:/home/xdaco/workspace:Z \
  xdaco-ultimate-dev
```

### Linux

Same build commands as macOS.

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
│   ├── xdaco-ultimate-dev
│   ├── xdaco-ultimate-ai
│   └── xdaco-ultimate-db
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
use podman xdaco-ultimate-dev
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
- tree, fd, bat, jq, ripgrep, eza, lsd
- diff-so-fancy, delta, rsync, ncdu, duf, fdupes
- p7zip, zip, glow, pass, stow, skopeo
- nmap, asciinema, wego
- htop, btop, cpufetch, neofetch, onefetch
- gcc, g++, make, python3, nodejs, npm, composer
- mycli, pgcli, postgrest
- opencode, claude-code
- podman, podman-compose
- age, sops, gnupg
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
