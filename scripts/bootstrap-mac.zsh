#!/usr/bin/env zsh
set -euo pipefail

# Configurable variables
TARGET_USER=${1:-${TARGET_USER:-mhs}}
CONTAINER_USER=${CONTAINER_USER:-xdaco}
WORKSPACE_DIR=${WORKSPACE_DIR:-~/Downloads/mhs_workspace}

echo ">>> macOS Stateless Workstation Bootstrap"

if [[ "$USER" != "$TARGET_USER" ]]; then
  echo "ERROR: Please log in as user '$TARGET_USER' before running."
  exit 1
fi

# ---- Sudo authentication (ask once) ----
echo ">>> Requesting sudo access"
sudo -v

# Keep sudo alive for the duration of the script
while true; do
  sudo -n true
  sleep 60
done 2>/dev/null &
SUDO_KEEPALIVE_PID=$!

trap 'kill $SUDO_KEEPALIVE_PID' EXIT

# ---- System updates and Xcode ----
sudo softwareupdate -i -a
xcode-select --install >/dev/null 2>&1 || true
until xcode-select -p >/dev/null 2>&1; do sleep 5; done

# ---- Homebrew ----
if ! command -v brew >/dev/null; then
  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

eval "$(/opt/homebrew/bin/brew shellenv)"
brew update

# ---- Core host tools ----
brew install podman podman-desktop tailscale gh git zsh mas

# ---- Unified GUI apps ----
brew install --cask \
  alacritty ghostty visual-studio-code sublime-text texmaker vlc brave-browser gimp \
  cursor balenaetcher bitwarden nomachine slack \
  inkscape obsidian \
  utm alfred whatsapp

# ---- Podman VM ----
podman machine init --now --cpus 6 --memory 8192 --disk-size 60 || true

# ---- Dotfiles ----
DOTFILES_DIR="$HOME/src/dotfiles"

mkdir -p ~/src

if [[ ! -d "$DOTFILES_DIR" ]]; then
  git clone git@github.com:xdaco/dotfiles.git "$DOTFILES_DIR"
else
  echo "Dotfiles repo already exists, skipping clone."
fi

pushd "$DOTFILES_DIR" >/dev/null
make
popd >/dev/null

# ---- SSH config ----
mkdir -p ~/.ssh
cat <<EOF >> ~/.ssh/config
Host xdaco-ultimate-devcontainer
  HostName localhost
  Port 2222
  User ${CONTAINER_USER}
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
EOF

chsh -s /bin/zsh

echo ">>> macOS bootstrap complete. Reboot recommended."
