#!/usr/bin/env bash
# install-nvm.sh — Install nvm (Node Version Manager) + a Node.js release.
# Runs per-user: nvm lives in $HOME, so do NOT run this with sudo.
# Safe to run non-interactively:  curl -fsSL <raw-url> | bash
#
#   NVM_VERSION=v0.40.3 NODE_VERSION=22 bash install-nvm.sh

set -euo pipefail

NVM_VERSION="${NVM_VERSION:-v0.40.3}"     # nvm release tag to install
NODE_VERSION="${NODE_VERSION:---lts}"     # "--lts", "22", "20.11.1", … ("" = skip Node)
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

if [ "$(id -u)" -eq 0 ] && [ "$HOME" = "/root" ]; then
  echo "⚠️  Running as root — nvm will be installed into /root/.nvm, not your login user."
fi

# 1. Prerequisites (the nvm installer needs curl/git; node builds nothing here).
#    Only reach for sudo when something is actually missing — under `curl | bash`
#    an account with no usable password cannot answer a sudo prompt, and these
#    packages are present on a stock Ubuntu anyway.
ensure_packages() {
  local missing=()
  for cmd in "$@"; do
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
  done
  [ ${#missing[@]} -eq 0 ] && { echo "✓ prerequisites already installed: $*"; return 0; }

  local SUDO=""
  if [ "$(id -u)" -ne 0 ]; then
    # -n: fail immediately rather than hanging on (or bombing out at) a prompt.
    if sudo -n true 2>/dev/null; then
      SUDO="sudo"
    else
      echo "❌ Missing: ${missing[*]} — and this account cannot use sudo without a password."
      echo "   Install them once as root, then re-run this script:"
      echo "     sudo apt-get update && sudo apt-get install -y ${missing[*]}"
      exit 1
    fi
  fi
  $SUDO apt-get update
  $SUDO DEBIAN_FRONTEND=noninteractive apt-get install -y "${missing[@]}"
}
ensure_packages curl git

# 2. Install nvm (idempotent: the installer updates an existing checkout, and
#    it appends its snippet to the login profile only when it is not there yet)
if [ -s "$NVM_DIR/nvm.sh" ]; then
  echo "✓ nvm already installed at $NVM_DIR"
else
  curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/$NVM_VERSION/install.sh" | bash
fi

# 3. Make sure zsh picks it up too — the installer only edits the profile it
#    detects, which under `curl | bash` is usually ~/.bashrc alone.
NVM_SNIPPET='export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"'
for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
  [ -f "$rc" ] || continue
  if grep -q 'NVM_DIR' "$rc"; then
    echo "✓ $rc already loads nvm"
  else
    printf '\n# nvm\n%s\n' "$NVM_SNIPPET" >> "$rc"
    echo "→ added the nvm snippet to $rc"
  fi
done

# 4. Load nvm into *this* shell. nvm.sh references unset variables, so `set -u`
#    would abort here; relax it just for the source and the nvm calls.
set +u
# shellcheck disable=SC1091
. "$NVM_DIR/nvm.sh"

# 5. Install Node and make it the default for new shells
if [ -n "$NODE_VERSION" ]; then
  nvm install "$NODE_VERSION"
  nvm alias default "$NODE_VERSION"
  nvm use default
fi
set -u

# 6. Verify
command -v node >/dev/null && node --version
command -v npm  >/dev/null && npm --version

echo "✅ nvm $NVM_VERSION installed in $NVM_DIR. Open a new shell (or run:"
echo "   export NVM_DIR=\"$NVM_DIR\"; . \"\$NVM_DIR/nvm.sh\") to use node/npm."
