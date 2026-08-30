#!/usr/bin/env bash
# install-claude-code.sh — Install the Claude Code CLI on Ubuntu.
# Runs per-user (the CLI lives in $HOME), so do NOT run this with sudo.
# Safe to run non-interactively:  curl -fsSL <raw-url> | bash
#
#   INSTALL_METHOD=npm bash install-claude-code.sh
#
# INSTALL_METHOD:
#   auto    (default) native installer, falling back to npm if it fails
#   native  https://claude.ai/install.sh — self-updating, no Node needed
#   npm     npm install -g @anthropic-ai/claude-code (needs Node 18+)

set -euo pipefail

INSTALL_METHOD="${INSTALL_METHOD:-auto}"
CLAUDE_VERSION="${CLAUDE_VERSION:-latest}"   # "latest", "stable", or e.g. "1.0.60"
LOCAL_BIN="$HOME/.local/bin"

if [ "$(id -u)" -eq 0 ] && [ "$HOME" = "/root" ]; then
  echo "⚠️  Running as root — Claude Code will be installed for root only."
  echo "   Run it as your normal user instead, or via: sudo -u <user> -H bash …"
fi

# 1. Prerequisites
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y curl ca-certificates git ripgrep

# 2. Pick up an nvm-managed node, if there is one, so `npm` is visible even
#    though this non-login shell never sourced the user's rc files.
if [ -s "${NVM_DIR:-$HOME/.nvm}/nvm.sh" ]; then
  set +u
  # shellcheck disable=SC1091
  . "${NVM_DIR:-$HOME/.nvm}/nvm.sh"
  set -u
fi

install_native() {
  echo "→ Installing Claude Code via the native installer ($CLAUDE_VERSION)"
  curl -fsSL https://claude.ai/install.sh | bash -s "$CLAUDE_VERSION"
}

install_npm() {
  if ! command -v npm >/dev/null 2>&1; then
    echo "✗ npm not found. Install Node first (see install-nvm.sh) or use INSTALL_METHOD=native." >&2
    return 1
  fi
  echo "→ Installing Claude Code via npm"
  # A system-wide npm prefix (/usr/lib/node_modules) needs root; an nvm one does not.
  local prefix
  prefix="$(npm prefix -g)"
  if [ -w "$prefix" ]; then
    npm install -g @anthropic-ai/claude-code
  else
    sudo -E env "PATH=$PATH" npm install -g @anthropic-ai/claude-code
  fi
}

# 3. Install (idempotent: both paths overwrite/upgrade an existing install)
case "$INSTALL_METHOD" in
  native) install_native ;;
  npm)    install_npm ;;
  auto)
    if ! install_native; then
      echo "⚠️  Native installer failed — falling back to npm."
      install_npm
    fi
    ;;
  *)
    echo "✗ Unknown INSTALL_METHOD='$INSTALL_METHOD' (use auto, native or npm)." >&2
    exit 1
    ;;
esac

# 4. The native installer drops the binary in ~/.local/bin, which is not on the
#    PATH of a fresh Ubuntu account until that directory exists at login time.
if [ -d "$LOCAL_BIN" ]; then
  for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    [ -f "$rc" ] || continue
    if grep -q '\.local/bin' "$rc"; then
      echo "✓ $rc already puts ~/.local/bin on the PATH"
    else
      printf '\n# Claude Code\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$rc"
      echo "→ added ~/.local/bin to the PATH in $rc"
    fi
  done
  export PATH="$LOCAL_BIN:$PATH"
fi

# 5. Verify (`|| true`: a missing binary here is a PATH problem, not a reason
#    for `set -e` to swallow the message below)
command -v claude || true
claude --version || true

echo "✅ Claude Code installed. Open a new shell, then run 'claude' in a project"
echo "   directory and follow the one-time browser login."
