#!/usr/bin/env bash
set -euo pipefail

# ============================
# Fedora Atomic Bootstrap Script
# Some packages may be failed to install on aarch64 architecture
# ============================

# Configurable variables
TARGET_USER=${1:-${TARGET_USER:-mhs}}

echo "=== Linux Bootstrap ==="

# Ask for sudo password once
echo "Enter your sudo password for user '$TARGET_USER':"
read -s SUDO_PASS

# Function to run sudo commands without asking again
sudo_cmd() {
    echo "$SUDO_PASS" | sudo -S "$@"
}

# ----------------------------
# 1️⃣ Create user if not exists
# ----------------------------
if ! id "$TARGET_USER" &>/dev/null; then
    sudo_cmd useradd -m -s /usr/bin/zsh "$TARGET_USER"
    echo "$TARGET_USER:$SUDO_PASS" | sudo_cmd chpasswd
    sudo_cmd usermod -aG wheel "$TARGET_USER"
    echo "User '$TARGET_USER' created."
else
    echo "User '$TARGET_USER' already exists."
fi

# ----------------------------
# 2️⃣ Fix MTU
# ----------------------------
sudo_cmd ip link set dev enp0s1 mtu 1400
echo "MTU for enp0s1 set to 1400."

# ----------------------------
# 3️⃣ Install rpm-ostree packages
# ----------------------------
PACKAGES=("zsh" "git" "tailscale" "podman" "alacritty" "lsd"  "tmux" )
PACKAGES_TO_INSTALL=""

for pkg in "${PACKAGES[@]}"; do
    # Installed check
    if rpm -q --quiet "$pkg"; then
        echo "Package '$pkg' is already installed, skipping..."
        continue
    fi

    # Staged / provided check (robust)
    if (rpm-ostree install --dry-run "$pkg" 2>&1 || true) | grep -q -E "already requested|already provided"; then
        echo "Package '$pkg' is already staged/requested or provided by base, skipping..."
        continue
    fi

    # Otherwise, add to install list
    PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL $pkg"
done

if [ -n "$PACKAGES_TO_INSTALL" ]; then
    echo "Installing packages:$PACKAGES_TO_INSTALL"
    sudo_cmd rpm-ostree install $PACKAGES_TO_INSTALL
else
    echo "All required packages are already installed, staged, or provided."
fi

sudo_cmd rpm-ostree install \
  https://download.sublimetext.com/rpm/stable/x86_64/sublime-text.repo

# ----------------------------
# 4️⃣ Add Flathub remote silently
# ----------------------------
if ! flatpak remotes --user | grep -q "^flathub$"; then
    echo "Adding Flathub remote..."
    flatpak remote-add --user --if-not-exists flathub \
        https://dl.flathub.org/repo/flathub.flatpakrepo
else
    echo "Flathub remote already exists."
fi

# ----------------------------
# 5️⃣ Install Flatpak apps
# ----------------------------
FLATPAK_APPS=(
    com.visualstudio.code
    com.sublimetext.three
    net.xm1math.Texmaker
    org.videolan.VLC
    com.brave.Browser
    org.gimp.GIMP
    com.bitwarden.desktop
    com.nomachine.nxplayer
    com.slack.Slack
    org.inkscape.Inkscape
    md.obsidian.Obsidian
    com.ktechpit.whatsie
    org.libreoffice.LibreOffice
    io.github.alainm23.planify
)

APPS_TO_INSTALL=""

for app in "${FLATPAK_APPS[@]}"; do
    if flatpak list --app --columns=application | grep -q "^${app}$" 2>/dev/null; then
        echo "Flatpak app '$app' already installed, skipping..."
    else
        APPS_TO_INSTALL="$APPS_TO_INSTALL $app"
    fi
done

if [ -n "$APPS_TO_INSTALL" ]; then
    echo "Installing flatpak apps:$APPS_TO_INSTALL"
    flatpak install -y --user flathub $APPS_TO_INSTALL
else
    echo "All required flatpak apps are already installed."
fi

# ----------------------------
# 6️⃣ Install chezmoi (dotfiles bootstrap)
# ----------------------------
if ! command -v chezmoi &>/dev/null; then
    echo "Installing chezmoi..."
    sudo_cmd sh -c "$(curl -fsSL https://chezmoi.io/get)" -- -b /usr/local/bin
else
    echo "chezmoi already installed."
fi

# ----------------------------
# 7️⃣ Apply dotfiles (optional)
# ----------------------------
# sudo_cmd -u $TARGET_USER chezmoi init --apply https://github.com/xdaco/xdaco-dotfiles.git

# ----------------------------
# 8️⃣ Install Starship prompt (optional)
# ----------------------------
if ! command -v starship &>/dev/null; then
    echo "Installing Starship prompt..."
    sudo_cmd -u $TARGET_USER sh -c "$(curl -fsSL https://starship.rs/install.sh)" -- -y
else
    echo "Starship already installed."
fi

echo "=== Linux Bootstrap Complete ==="
echo "Please reboot the system before use."

## After root we can install oh-my-zsh

#sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
