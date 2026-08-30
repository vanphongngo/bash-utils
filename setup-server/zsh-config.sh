#!/usr/bin/env bash
# zsh-config.sh — Install zsh + Oh My Zsh + autosuggestions/syntax-highlighting.
# Safe to run non-interactively:  curl -fsSL <raw-url> | bash

set -euo pipefail

# When piped from curl there is no TTY, so Oh My Zsh must not try to launch a
# shell or run chsh itself; we handle the shell change ourselves at the end.
export RUNZSH=no
export CHSH=no
export KEEP_ZSHRC=no

ZSH_DIR="${ZSH:-$HOME/.oh-my-zsh}"
ZSH_CUSTOM_DIR="${ZSH_CUSTOM:-$ZSH_DIR/custom}"

# 1. Install zsh and prerequisites
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y zsh git curl

# 2. Install Oh My Zsh (idempotent: skip if already present)
if [ -d "$ZSH_DIR" ]; then
  echo "✓ Oh My Zsh already installed at $ZSH_DIR"
else
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# 3./4. Install plugins (clone only when missing so re-runs don't fail)
install_plugin() {
  local name="$1" url="$2" dest="$ZSH_CUSTOM_DIR/plugins/$1"
  if [ -d "$dest" ]; then
    echo "✓ plugin $name already installed"
  else
    git clone --depth 1 "$url" "$dest"
  fi
}
install_plugin zsh-autosuggestions     https://github.com/zsh-users/zsh-autosuggestions.git
install_plugin zsh-syntax-highlighting https://github.com/zsh-users/zsh-syntax-highlighting.git

# 5. Enable the plugins in ~/.zshrc (only rewrite the default plugins=(git) line)
if [ -f "$HOME/.zshrc" ]; then
  if grep -q '^plugins=(git)$' "$HOME/.zshrc"; then
    sed -i 's/^plugins=(git)$/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' "$HOME/.zshrc"
  elif ! grep -q 'zsh-autosuggestions' "$HOME/.zshrc"; then
    echo "⚠️  Could not auto-edit plugins=(...) in ~/.zshrc — add these manually:"
    echo "    plugins=(git zsh-autosuggestions zsh-syntax-highlighting)"
  fi
else
  echo "⚠️  ~/.zshrc not found; skipping plugin activation."
fi

# 6. Make zsh the default login shell.
#    NOTE: chsh prompts for a password, which is impossible under `curl | bash`.
#    Use usermod via sudo instead, which does not prompt on the pipe.
ZSH_BIN="$(command -v zsh)"
grep -qx "$ZSH_BIN" /etc/shells || echo "$ZSH_BIN" | sudo tee -a /etc/shells >/dev/null
sudo chsh -s "$ZSH_BIN" "$USER"

# 7. Do NOT `source ~/.zshrc` here — this is a bash process and .zshrc is zsh
#    syntax, so sourcing it fails. Start a new shell instead:
echo "✅ Done. Log out and back in, or run: exec zsh"
