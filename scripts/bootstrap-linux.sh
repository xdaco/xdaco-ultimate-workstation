#!/usr/bin/env sh
set -eu

# ============================
# Fedora Atomic Bootstrap Script
# Some packages may be failed to install on aarch64 architecture
# ============================

# Configurable variables
TARGET_USER=${1:-${TARGET_USER:-mhs}}

# Detect CPU architecture
ARCH=$(uname -m)
echo "=== Linux Bootstrap ==="
echo "Detected architecture: $ARCH"

# Ask for sudo password once
echo "Enter your sudo password for user '$TARGET_USER':"
# Use stty to hide password input (POSIX-compliant)
stty -echo
read SUDO_PASS
stty echo
echo ""

# Function to run sudo commands without asking again
sudo_cmd() {
    echo "$SUDO_PASS" | sudo -S "$@" 2>/dev/null
}

# Function to run commands as target user (for user-space installations)
run_as_user() {
    echo "$SUDO_PASS" | sudo -S -u "$TARGET_USER" sh -c "$1"
}

# ----------------------------
# 1️⃣ Create user if not exists
# ----------------------------
if ! id "$TARGET_USER" >/dev/null 2>&1; then
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
# Use space-separated string instead of array (POSIX-compliant)
PACKAGES="zsh git tailscale podman alacritty lsd tmux"
PACKAGES_TO_INSTALL=""

for pkg in $PACKAGES; do
    # Installed check
    if rpm -q --quiet "$pkg" >/dev/null 2>&1; then
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

# Install Sublime Text repo (x86_64 only)
if [ "$ARCH" = "x86_64" ]; then
    echo "Installing Sublime Text repository (x86_64)..."
    sudo_cmd rpm-ostree install \
        https://download.sublimetext.com/rpm/stable/x86_64/sublime-text.repo
else
    echo "Skipping Sublime Text repository (not available for $ARCH)."
fi

# ----------------------------
# 4️⃣ Add Flathub remote silently
# ----------------------------
if ! flatpak remotes --user 2>/dev/null | grep -q "^flathub$"; then
    echo "Adding Flathub remote..."
    flatpak remote-add --user --if-not-exists flathub \
        https://dl.flathub.org/repo/flathub.flatpakrepo
else
    echo "Flathub remote already exists."
fi

# ----------------------------
# 5️⃣ Install Flatpak apps (architecture-specific)
# ----------------------------
# Define flatpak apps for x86_64 (space-separated string, POSIX-compliant)
FLATPAK_APPS_X86_64="com.visualstudio.code com.sublimetext.three net.xm1math.Texmaker org.videolan.VLC com.brave.Browser org.gimp.GIMP com.bitwarden.desktop com.nomachine.nxplayer com.slack.Slack org.inkscape.Inkscape md.obsidian.Obsidian com.ktechpit.whatsie org.libreoffice.LibreOffice io.github.alainm23.planify com.rustdesk.RustDesk"

# Define flatpak apps for aarch64 (space-separated string, POSIX-compliant)
FLATPAK_APPS_AARCH64="com.visualstudio.code org.videolan.VLC com.brave.Browser com.quexten.Goldwarden org.gimp.GIMP com.ktechpit.whatsie org.inkscape.Inkscape md.obsidian.Obsidian org.libreoffice.LibreOffice io.github.alainm23.planify com.rustdesk.RustDesk"

# Select the appropriate app list based on architecture
case "$ARCH" in
    x86_64)
        FLATPAK_APPS="$FLATPAK_APPS_X86_64"
        echo "Using x86_64 flatpak app list."
        ;;
    aarch64)
        FLATPAK_APPS="$FLATPAK_APPS_AARCH64"
        echo "Using aarch64 flatpak app list."
        ;;
    *)
        echo "Warning: Unknown architecture '$ARCH'. Using x86_64 app list as fallback."
        FLATPAK_APPS="$FLATPAK_APPS_X86_64"
        ;;
esac

APPS_TO_INSTALL=""

for app in $FLATPAK_APPS; do
    if flatpak list --app --columns=application 2>/dev/null | grep -q "^${app}$"; then
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
# 6️⃣ Install Nerd Fonts (Agave + Meslo)
# ----------------------------
echo "Installing Nerd Fonts (Agave + Meslo)..."
run_as_user '
    mkdir -p "$HOME/.local/share/fonts" && \
    curl -fsSL https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/Agave.zip -o /tmp/Agave.zip && \
    curl -fsSL https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/Meslo.zip -o /tmp/Meslo.zip && \
    unzip -qo /tmp/Agave.zip -d "$HOME/.local/share/fonts" && \
    unzip -qo /tmp/Meslo.zip -d "$HOME/.local/share/fonts" && \
    fc-cache -fv && \
    rm -f /tmp/Agave.zip /tmp/Meslo.zip
' || {
    echo "Warning: Font installation failed, but continuing..."
}

# ----------------------------
# 7️⃣ Install chezmoi (dotfiles bootstrap)
# ----------------------------
if ! command -v chezmoi >/dev/null 2>&1; then
    echo "Installing chezmoi..."
    sudo_cmd sh -c "$(curl -fsSL https://chezmoi.io/get)" -- -b /usr/local/bin
else
    echo "chezmoi already installed."
fi

# ----------------------------
# 8️⃣ Apply dotfiles (optional)
# ----------------------------
# sudo_cmd -u $TARGET_USER chezmoi init --apply https://github.com/xdaco/xdaco-dotfiles.git

# ----------------------------
# 9️⃣ Install Starship prompt (optional)
# ----------------------------
if ! command -v starship >/dev/null 2>&1; then
    echo "Installing Starship prompt..."
    run_as_user "curl -fsSL https://starship.rs/install.sh | sh -s -- -y"
else
    echo "Starship already installed."
fi

# ----------------------------
# 🔟 Install oh-my-zsh (if zsh is available)
# ----------------------------
if command -v zsh >/dev/null 2>&1; then
    echo "Installing oh-my-zsh..."
    run_as_user "sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\" '' --unattended" || {
        echo "Warning: oh-my-zsh installation failed, but continuing..."
    }
else
    echo "We cannot install oh-my-zsh now. Please reboot and run this script again."
    echo "Or alternatively after reboot,  you can run:"
    echo '  curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh | sh'
fi

# ----------------------------
# 🔟 Download and add xdaco aliases to .zshrc
# ----------------------------
echo "Downloading xdaco aliases..."
run_as_user "
    curl -fsSL https://raw.githubusercontent.com/xdaco/bash-resources/master/xdaco_aliases.sh -o \"\$HOME/xdaco_aliases.sh\" && \
    chmod +x \"\$HOME/xdaco_aliases.sh\" && \
    echo 'Downloaded xdaco_aliases.sh to home directory'
" || {
    echo "Warning: Failed to download xdaco aliases, but continuing..."
}

echo "Adding xdaco aliases to .zshrc..."
run_as_user "
    if [ -f \"\$HOME/.zshrc\" ]; then
        if ! grep -q 'xdaco_aliases.sh' \"\$HOME/.zshrc\" 2>/dev/null; then
            echo '' >> \"\$HOME/.zshrc\"
            echo '# Load xdaco aliases' >> \"\$HOME/.zshrc\"
            echo 'if [ -f \"\$HOME/xdaco_aliases.sh\" ]; then' >> \"\$HOME/.zshrc\"
            echo '  source \"\$HOME/xdaco_aliases.sh\"' >> \"\$HOME/.zshrc\"
            echo 'fi' >> \"\$HOME/.zshrc\"
            echo 'Added xdaco aliases to .zshrc'
        else
            echo 'xdaco aliases already in .zshrc, skipping...'
        fi
    else
        echo 'Warning: .zshrc not found, creating it...'
        echo '# Load xdaco aliases' > \"\$HOME/.zshrc\"
        echo 'if [ -f \"\$HOME/xdaco_aliases.sh\" ]; then' >> \"\$HOME/.zshrc\"
        echo '  source \"\$HOME/xdaco_aliases.sh\"' >> \"\$HOME/.zshrc\"
        echo 'fi' >> \"\$HOME/.zshrc\"
    fi
"

echo "=== Linux Bootstrap Complete ==="
echo "Please reboot the system before use."