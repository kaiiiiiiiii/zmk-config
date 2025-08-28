#!/bin/bash
# Debug script for Nix installation issues in GitHub Actions runner

set -euo pipefail

echo "=== Nix Installation Debug Information ==="
echo "Date: $(date)"
echo "User: $(whoami)"
echo "Home: $HOME"
echo "PATH: $PATH"

echo -e "\n=== Container Detection ==="
if grep -qE '(docker|kubepods|containerd)' /proc/1/cgroup 2>/dev/null; then
    echo "✓ Running in container (detected via cgroup)"
elif [ -f /.dockerenv ]; then
    echo "✓ Running in Docker container (detected via .dockerenv)"
elif [ -f /run/.containerenv ]; then
    echo "✓ Running in container (detected via .containerenv)"
else
    echo "❌ Not detected as container environment"
fi

echo -e "\n=== System Groups (checking for nixbld) ==="
if getent group nixbld >/dev/null 2>&1; then
    echo "✓ nixbld group exists"
    getent group nixbld
else
    echo "❌ nixbld group does not exist (this is expected for single-user install)"
fi

echo -e "\n=== Nix Installation Check ==="
if command -v nix >/dev/null 2>&1; then
    echo "✓ Nix is available: $(command -v nix)"
    echo "Nix version: $(nix --version 2>/dev/null || echo 'version check failed')"
else
    echo "❌ Nix not found in PATH"
fi

echo -e "\n=== Nix Profile Directories ==="
echo "Single-user Nix profile directory:"
if [ -d "$HOME/.nix-profile" ]; then
    echo "✓ $HOME/.nix-profile exists"
    ls -la "$HOME/.nix-profile/" || echo "Cannot list contents"
else
    echo "❌ $HOME/.nix-profile does not exist"
fi

echo -e "\nMulti-user Nix profile directory:"
if [ -d "/nix/var/nix/profiles/default" ]; then
    echo "✓ /nix/var/nix/profiles/default exists"
    ls -la "/nix/var/nix/profiles/default/" || echo "Cannot list contents"
else
    echo "❌ /nix/var/nix/profiles/default does not exist"
fi

echo -e "\n=== Nix Store ==="
if [ -d "/nix/store" ]; then
    echo "✓ /nix/store exists"
    echo "Store entries: $(ls /nix/store | wc -l) items"
else
    echo "❌ /nix/store does not exist"
fi

echo -e "\n=== Profile Scripts ==="
single_user_script="$HOME/.nix-profile/etc/profile.d/nix.sh"
multi_user_script="/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"

if [ -f "$single_user_script" ]; then
    echo "✓ Single-user profile script exists: $single_user_script"
else
    echo "❌ Single-user profile script missing: $single_user_script"
fi

if [ -f "$multi_user_script" ]; then
    echo "✓ Multi-user profile script exists: $multi_user_script"
else
    echo "❌ Multi-user profile script missing: $multi_user_script"
fi

echo -e "\n=== Environment Variables ==="
echo "NIX_STORE_DIR: ${NIX_STORE_DIR:-unset}"
echo "NIX_STATE_DIR: ${NIX_STATE_DIR:-unset}"
echo "NIX_PROFILES: ${NIX_PROFILES:-unset}"
echo "NIX_SSL_CERT_FILE: ${NIX_SSL_CERT_FILE:-unset}"

echo -e "\n=== Volume Mounts (Docker) ==="
if command -v mount >/dev/null 2>&1; then
    echo "Nix-related mounts:"
    mount | grep nix || echo "No nix-related mounts found"
else
    echo "mount command not available"
fi

echo -e "\n=== Recommendations ==="
if ! command -v nix >/dev/null 2>&1; then
    echo "❌ Nix installation needed"
    echo "   For container environment, use: curl -L https://nixos.org/nix/install | sh -s -- --no-daemon"
    echo "   Then source: source $HOME/.nix-profile/etc/profile.d/nix.sh"
else
    echo "✓ Nix appears to be properly installed"
fi

echo -e "\n=== Debug Complete ==="
