#!/usr/bin/env zsh
set -euo pipefail

# Configurable variables
TARGET_USER=${1:-${TARGET_USER:-xdaco}}
CONTAINER_USER=${CONTAINER_USER:-xdaco}
WORKSPACE_DIR=${WORKSPACE_DIR:-~/Downloads/mhs_workspace}
REPO_ROOT="${0:a:h:h}"
BREWFILE_PATH="${REPO_ROOT}/Brewfile"

echo "Running for Target User: $TARGET_USER"

echo ">>> macOS Stateless Workstation Bootstrap"

if [[ "$USER" != "$TARGET_USER" ]]; then
  echo "ERROR: Please log in as user '$TARGET_USER' before running."
  exit 1
fi

# ---- Sudo authentication (ask once and keep alive) ----
echo ">>> Requesting sudo access"
sudo -v

# Function to run sudo commands (reuses cached credentials)
sudo_cmd() {
  sudo "$@"
}

# Keep sudo alive for the duration of the script
while true; do
  sudo -n true >/dev/null 2>&1 || break
  sleep 60
done 2>/dev/null &
SUDO_KEEPALIVE_PID=$!

# Clean up background process on exit
trap 'kill $SUDO_KEEPALIVE_PID 2>/dev/null || true' EXIT

# ---- System updates and Xcode ----
sudo_cmd softwareupdate -i -a
xcode-select --install >/dev/null 2>&1 || true
until xcode-select -p >/dev/null 2>&1; do sleep 5; done

# ---- Homebrew Architecture Check & Installation ----
# Apple Silicon uses /opt/homebrew, Intel uses /usr/local
ARCH=$(uname -m)
if [[ "$ARCH" == "arm64" ]]; then
  BREW_PREFIX="/opt/homebrew"
else
  BREW_PREFIX="/usr/local"
fi

if ! command -v brew >/dev/null; then
  echo ">>> Installing Homebrew for $ARCH..."
  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Load brew environment based on detected architecture
eval "$($BREW_PREFIX/bin/brew shellenv)"
brew update

# ---- Homebrew Bundle (Resilient Installation) ----
if [ -f "$BREWFILE_PATH" ]; then
    echo ">>> Installing from $BREWFILE_PATH..."

    # Use environment variable to prevent lockfile creation
    export HOMEBREW_BUNDLE_NO_LOCK=1

    # Run the bundle. If it fails, just show a warning but don't exit.
    if ! brew bundle --file="$BREWFILE_PATH"; then
        echo ">>> Warning: Some bundle items failed to install, check logs above."
    fi
else
    # This ONLY triggers if the file itself is missing
    echo ">>> Error: Brewfile not found at $BREWFILE_PATH"
    exit 1
fi

# ---- SSH config ----
mkdir -p ~/.ssh
if ! grep -q "xdaco-ultimate-devcontainer" ~/.ssh/config 2>/dev/null; then
  cat <<EOF >> ~/.ssh/config
Host xdaco-ultimate-devcontainer
  HostName localhost
  Port 2222
  User ${CONTAINER_USER}
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
EOF
fi

# ---- Install Nerd Fonts (Agave + Meslo) ----
echo ">>> Installing Nerd Fonts (Agave + Meslo)..."
mkdir -p "$HOME/.local/share/fonts"
curl -fsSL https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/Agave.zip -o /tmp/Agave.zip
curl -fsSL https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/Meslo.zip -o /tmp/Meslo.zip
unzip -qo /tmp/Agave.zip -d "$HOME/.local/share/fonts"
unzip -qo /tmp/Meslo.zip -d "$HOME/.local/share/fonts"
fc-cache -fv
rm -f /tmp/Agave.zip /tmp/Meslo.zip
echo ">>> Nerd Fonts installed successfully."

# ---- Download and add xdaco aliases to .zshrc ----
echo ">>> Downloading xdaco aliases..."
if curl -fsSL https://raw.githubusercontent.com/xdaco/bash-resources/master/xdaco_aliases.sh -o "$HOME/xdaco_aliases.sh"; then
  chmod +x "$HOME/xdaco_aliases.sh"
  echo ">>> Downloaded xdaco_aliases.sh to home directory"
fi

echo ">>> Adding xdaco aliases to .zshrc..."
if [ -f "$HOME/.zshrc" ]; then
  if ! grep -q 'xdaco_aliases.sh' "$HOME/.zshrc" 2>/dev/null; then
    echo -e "\n# Load xdaco aliases\nif [ -f \"\$HOME/xdaco_aliases.sh\" ]; then\n  source \"\$HOME/xdaco_aliases.sh\"\nfi" >> "$HOME/.zshrc"
  fi
fi

echo ">>> macOS bootstrap complete. Reboot recommended."
