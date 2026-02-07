#!/usr/bin/env zsh
set -euo pipefail

# Configurable variables
TARGET_USER=${1:-${TARGET_USER:-xdaco}}
CONTAINER_USER=${CONTAINER_USER:-xdaco}
WORKSPACE_DIR=${WORKSPACE_DIR:-~/Downloads/mhs_workspace}

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

# ---- Homebrew ----
if ! command -v brew >/dev/null; then
  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

eval "$(/opt/homebrew/bin/brew shellenv)"
brew update

# ---- Core host tools ----
echo ">>> Installing core host tools..."
brew install podman podman-desktop gh git zsh mas tree wget jq tldr thefuck python3 composer || true

# Install tailscale separately with error handling for linking issues
echo ">>> Installing tailscale..."
brew install tailscale || {
  echo ">>> Tailscale installation encountered issues, checking if linking is needed..."
  # Check if tailscale was installed but just not linked
  if brew list tailscale >/dev/null 2>&1; then
    echo ">>> Tailscale package is installed, attempting to fix linking..."
    brew link --overwrite tailscale 2>/dev/null || {
      echo ">>> Warning: Tailscale linking failed."
      echo ">>> You can try running 'brew link --overwrite tailscale' manually."
      echo ">>> Or use 'sudo brew link --overwrite tailscale' if permission issues persist."
    }
  else
    echo ">>> Warning: Tailscale installation failed completely."
    echo ">>> You may need to install it manually: brew install tailscale"
  fi
}

# ---- Unified GUI apps ----
# Function to check if an app is already installed
app_installed() {
  local app_name="$1"
  # Check if installed via Homebrew cask
  if brew list --cask "$app_name" >/dev/null 2>&1; then
    return 0
  fi
  # Check common app locations
  case "$app_name" in
    alacritty)
      [[ -d "/Applications/Alacritty.app" ]] && return 0
      ;;
    ghostty)
      [[ -d "/Applications/Ghostty.app" ]] && return 0
      ;;
    visual-studio-code)
      [[ -d "/Applications/Visual Studio Code.app" ]] && return 0
      ;;
    sublime-text)
      [[ -d "/Applications/Sublime Text.app" ]] && return 0
      ;;
    texmaker)
      [[ -d "/Applications/Texmaker.app" ]] && return 0
      ;;
    vlc)
      [[ -d "/Applications/VLC.app" ]] && return 0
      ;;
    brave-browser)
      [[ -d "/Applications/Brave Browser.app" ]] && return 0
      ;;
    gimp)
      [[ -d "/Applications/GIMP.app" ]] && return 0
      ;;
    cursor)
      [[ -d "/Applications/Cursor.app" ]] && return 0
      ;;
    balenaetcher)
      [[ -d "/Applications/balenaEtcher.app" ]] && return 0
      ;;
    bitwarden)
      [[ -d "/Applications/Bitwarden.app" ]] && return 0
      ;;
    nomachine)
      [[ -d "/Applications/NoMachine.app" ]] && return 0
      ;;
    slack)
      [[ -d "/Applications/Slack.app" ]] && return 0
      ;;
    inkscape)
      [[ -d "/Applications/Inkscape.app" ]] && return 0
      ;;
    obsidian)
      [[ -d "/Applications/Obsidian.app" ]] && return 0
      ;;
    utm)
      [[ -d "/Applications/UTM.app" ]] && return 0
      ;;
    alfred)
      [[ -d "/Applications/Alfred 5.app" ]] || [[ -d "/Applications/Alfred 4.app" ]] || [[ -d "/Applications/Alfred.app" ]] && return 0
      ;;
    whatsapp)
      [[ -d "/Applications/WhatsApp.app" ]] && return 0
      ;;
    go2shell)
      [[ -d "/Applications/Go2Shell.app" ]] && return 0
      ;;
    shuttle)
      [[ -d "/Applications/Shuttle.app" ]] && return 0
      ;;
    textmate)
      [[ -d "/Applications/TextMate.app" ]] && return 0
      ;;
    antigravity)
      [[ -d "/Applications/AntiGravity.app" ]] && return 0
      ;;
    notion)
      [[ -d "/Applications/Notion.app" ]] && return 0
      ;;
    calibre)
      [[ -d "/Applications/calibre.app" ]] && return 0
      ;;
    kindle)
      [[ -d "/Applications/Kindle.app" ]] && return 0
      ;;
    the-unarchiver)
      [[ -d "/Applications/The Unarchiver.app" ]] && return 0
      ;;
  esac
  return 1
}

# Function to install app if not already installed
install_app_if_needed() {
  local app_name="$1"
  if app_installed "$app_name"; then
    echo ">>> '$app_name' is already installed, skipping..."
    return 0
  else
    echo ">>> Installing '$app_name'..."
    brew install --cask "$app_name" || {
      echo ">>> Warning: Failed to install '$app_name', but continuing..."
      return 1
    }
  fi
}

echo ">>> Installing GUI applications..."
install_app_if_needed alacritty
install_app_if_needed ghostty
install_app_if_needed visual-studio-code
install_app_if_needed sublime-text
install_app_if_needed texmaker
install_app_if_needed vlc
install_app_if_needed brave-browser
install_app_if_needed gimp
install_app_if_needed cursor
install_app_if_needed balenaetcher
install_app_if_needed bitwarden
install_app_if_needed nomachine
install_app_if_needed slack
install_app_if_needed inkscape
install_app_if_needed obsidian
install_app_if_needed utm
install_app_if_needed alfred
install_app_if_needed whatsapp
install_app_if_needed go2shell
install_app_if_needed shuttle
install_app_if_needed textmate
install_app_if_needed antigravity
install_app_if_needed notion
install_app_if_needed calibre
install_app_if_needed kindle
install_app_if_needed the-unarchiver

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
else
  echo ">>> Warning: Failed to download xdaco aliases, but continuing..."
fi

echo ">>> Adding xdaco aliases to .zshrc..."
if [ -f "$HOME/.zshrc" ]; then
  if ! grep -q 'xdaco_aliases.sh' "$HOME/.zshrc" 2>/dev/null; then
    echo '' >> "$HOME/.zshrc"
    echo '# Load xdaco aliases' >> "$HOME/.zshrc"
    echo 'if [ -f "$HOME/xdaco_aliases.sh" ]; then' >> "$HOME/.zshrc"
    echo '  source "$HOME/xdaco_aliases.sh"' >> "$HOME/.zshrc"
    echo 'fi' >> "$HOME/.zshrc"
    echo ">>> Added xdaco aliases to .zshrc"
  else
    echo ">>> xdaco aliases already in .zshrc, skipping..."
  fi
else
  echo ">>> Creating .zshrc with xdaco aliases..."
  echo '# Load xdaco aliases' > "$HOME/.zshrc"
  echo 'if [ -f "$HOME/xdaco_aliases.sh" ]; then' >> "$HOME/.zshrc"
  echo '  source "$HOME/xdaco_aliases.sh"' >> "$HOME/.zshrc"
  echo 'fi' >> "$HOME/.zshrc"
fi

echo ">>> macOS bootstrap complete. Reboot recommended."
