# 🧱 PART 1 — CONTAINER IMAGES

---

## 📦 `containers/xdaco-ultimate-base/Containerfile`

```Dockerfile
FROM debian@sha256:6b3f06a1c4c4c5f5b5d6d4c4c6c7e87b0a5d1e7c1f1b8f7e4c3d2b1a9e8f7

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN set -eux; \
  apt-get update; \
  apt-get install -y --no-install-recommends \
    ca-certificates curl wget gnupg2 lsb-release sudo \
    zsh git tmux openssh-server rsync \
    build-essential gcc g++ make \
    python3 python3-pip python3-venv \
    nodejs npm php-cli php-mbstring unzip \
    bash-completion \
    tree fzf fd-find bat jq ripgrep ncdu \
    htop btop bottom \
    p7zip-full zip \
    diff-so-fancy fdupes duf \
    nmap wego cmus asciinema \
    pass stow neovim \
    direnv \
    age sops \
  ; \
  rm -rf /var/lib/apt/lists/*

# ---- Rust toolchain ----
RUN set -eux; \
  curl https://sh.rustup.rs -sSf | sh -s -- -y; \
  source /root/.cargo/env; \
  cargo install eza onefetch cpufetch zoxide git-delta just atuin bat-extras

ENV PATH="/root/.cargo/bin:${PATH}"

# ---- Composer ----
RUN curl -fsSL https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# ---- Node dev ----
RUN npm install -g opencode @anthropic-ai/claude-code

# ---- User ----
RUN useradd -m -s /usr/bin/zsh xdaco && \
    echo "xdaco ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/xdaco && \
    chmod 0440 /etc/sudoers.d/xdaco

# ---- SSH ----
RUN mkdir -p /var/run/sshd && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config

EXPOSE 22

USER xdaco
WORKDIR /home/xdaco

CMD ["/usr/sbin/sshd", "-D"]
```

---

## 📦 `containers/xdaco-ultimate-dev/Containerfile`

```Dockerfile
FROM xdaco-ultimate-base

USER root
RUN set -eux; \
  apt-get update; \
  apt-get install -y --no-install-recommends \
    postgresql-client \
    sqlite3 \
  ; \
  rm -rf /var/lib/apt/lists/*

USER xdaco
```

---

## 📦 `containers/xdaco-ultimate-db/Containerfile`

```Dockerfile
FROM xdaco-ultimate-dev

USER root
RUN pip install --no-cache-dir mycli pgcli

USER xdaco
```

---

## 📦 `containers/xdaco-ultimate-ai/Containerfile`

```Dockerfile
FROM xdaco-ultimate-dev
USER xdaco
```

---

## 📦 `containers/xdaco-ultimate-pdf/Containerfile`

```Dockerfile
FROM docker.io/frooodle/s-pdf@sha256:REPLACE_WITH_DIGEST
```

_(Or pull directly, no build needed.)_

---

# 🏗 PART 2 — BUILD COMMANDS

```bash
podman build -t xdaco-ultimate-base containers/xdaco-ultimate-base
podman build -t xdaco-ultimate-dev containers/xdaco-ultimate-dev
podman build -t xdaco-ultimate-db containers/xdaco-ultimate-db
podman build -t xdaco-ultimate-ai containers/xdaco-ultimate-ai
podman pull docker.io/frooodle/s-pdf
podman tag docker.io/frooodle/s-pdf xdaco-ultimate-pdf
```

---

# 🚀 PART 3 — RUN COMMANDS

## Main Dev Container

```bash
podman run -d \
  --name xdaco-ultimate-devcontainer \
  --hostname xdaco-ultimate-devcontainer \
  -p 2222:22 \
  -v ~/Downloads/mhs_workspace:/home/xdaco/workspace:Z \
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

```ssh
Host ultimate-devcontainer
  HostName localhost
  Port 2222
  User xdaco
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

Only showing renamed lines (everything else unchanged):

### macOS

```bash
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

Same replacements.

---

# 📘 PART 9 — UPDATED GUIDE (AUTHORITATIVE)

## 🧠 XDACO Ultimate Stateless Workstation v3.1

> One identity. One container. Any machine. Ten minutes.

---

## 🏗 Architecture

```
Host OS (macOS / Fedora Atomic)
│  GUI apps only
│  Podman rootless
│
└── xdaco-ultimate-base (OCI)
    └── xdaco-ultimate-dev
        ├── xdaco-ultimate-db
        ├── xdaco-ultimate-ai
        └── xdaco-ultimate-pdf
```

---

## 👤 Identity

| Component | User                              |
| --------- | --------------------------------- |
| Host OS   | mhs                               |
| Container | xdaco                             |
| SSH       | ssh ultimate-devcontainer -p 2222 |

---

## 📂 Workspace Mount

```
Host:      ~/Downloads/mhs_workspace
Container: /home/xdaco/workspace
```

---

## 🔐 Dotfiles

Managed via **chezmoi + stow**

```bash
chezmoi init --apply https://github.com/YOURORG/dotfiles.git
stow zsh tmux nvim git
```

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

- zsh, oh-my-zsh, gitstatus, tmux, neovim
- direnv, zoxide, atuin, starship (installed, not default)
- tree, fd, bat, batgrep, batdiff, batwatch, jq, ripgrep
- diff-so-fancy, delta, rsync, ncdu, duf, fdupes
- p7zip, zip, glow, pass, stow
- nmap, asciinema, wego
- htop, btop, bottom, cpufetch, neofetch, onefetch
- gcc, g++, make, python3, nodejs, npm, composer
- mycli, pgcli, postgrest
- opencode, claude-code
- podman, podman-compose
- age, sops, gnupg

---

### GUI Apps (macOS + Fedora)

- alacritty
- ghostty
- vscode
- sublime-text
- texmaker
- vlc
- brave
- gimp
- balenaEtcher
- bitwarden
- nomachine
- slack
- tailscale
- inkscape
- obsidian
- whatsapp
- libreoffice
- stirling-pdf (container)

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
