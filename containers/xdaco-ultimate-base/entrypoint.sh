#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Rootless sshd entrypoint — runs entirely as the (non-root) container user.
#   - Generates a per-container host key on first start (never baked into image)
#   - Loads the login key from a pubkey mounted at /run/host-pubkey (optional)
#   - Listens on the unprivileged port 2222 so no root/capabilities are needed
# Provide your key at run time, e.g.:
#   -v ~/.ssh/id_ed25519.pub:/run/host-pubkey:ro
# -----------------------------------------------------------------------------
set -e

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

# Per-container host key (generated once, on first run)
if [ ! -f "$HOME/.ssh/ssh_host_ed25519_key" ]; then
    ssh-keygen -t ed25519 -f "$HOME/.ssh/ssh_host_ed25519_key" -N "" -q
fi

# Authorized key supplied at runtime
if [ -f /run/host-pubkey ]; then
    cat /run/host-pubkey > "$HOME/.ssh/authorized_keys"
    chmod 600 "$HOME/.ssh/authorized_keys"
fi

cat > "$HOME/.ssh/sshd_config" <<EOF
Port 2222
HostKey $HOME/.ssh/ssh_host_ed25519_key
PidFile $HOME/.ssh/sshd.pid
AuthorizedKeysFile $HOME/.ssh/authorized_keys
PasswordAuthentication no
SetEnv LANG=C.UTF-8
EOF

exec /usr/sbin/sshd -D -e -f "$HOME/.ssh/sshd_config"
