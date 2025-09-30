#!/usr/bin/env bash
# revert-zsh.sh — Safely revert zsh + Oh My Zsh install on Ubuntu

set -euo pipefail

# ------- configuration -------
TARGET_USER="${SUDO_USER:-$USER}"   # the real user who ran sudo, or current
BACKUP_SUFFIX="$(date +%Y%m%d-%H%M%S)"
# -----------------------------

require_root() {
  if [ "$EUID" -ne 0 ]; then
    echo "Please run with sudo/root: sudo bash $0"
    exit 1
  fi
}

user_shell() {
  getent passwd "$1" | cut -d: -f7
}

set_shell_to_bash_if_needed() {
  local u="$1"
  local current
  current="$(user_shell "$u" || true)"
  if [ -z "$current" ]; then
    echo "⚠️  User '$u' not found; skipping shell change."
    return
  fi
  if [ "$current" != "/bin/bash" ]; then
    if [ -x /bin/bash ]; then
      echo "→ Changing login shell for '$u' from '$current' to /bin/bash"
      chsh -s /bin/bash "$u"
    else
      echo "❌ /bin/bash not found. Aborting for safety."
      exit 1
    fi
  else
    echo "✓ '$u' already uses /bin/bash"
  fi
}

backup_and_remove_user_zsh_files() {
  local u="$1"
  local home_dir
  home_dir="$(eval echo "~$u")"

  if [ ! -d "$home_dir" ]; then
    echo "⚠️  Home directory for '$u' not found; skipping user file removal."
    return
  fi

  # Backup .zshrc if present
  if [ -f "$home_dir/.zshrc" ]; then
    echo "→ Backing up $home_dir/.zshrc to $home_dir/.zshrc.bak.$BACKUP_SUFFIX"
    cp -a "$home_dir/.zshrc" "$home_dir/.zshrc.bak.$BACKUP_SUFFIX"
  fi

  # Remove Oh My Zsh
  if [ -d "$home_dir/.oh-my-zsh" ]; then
    echo "→ Removing $home_dir/.oh-my-zsh"
    rm -rf "$home_dir/.oh-my-zsh"
  fi

  # Remove common zsh caches/dumps
  find "$home_dir" -maxdepth 1 -type f -name ".zcompdump*" -printf "→ Removing %p\n" -exec rm -f {} \; || true

  # Optionally remove .zshrc (comment the next block if you want to keep it)
  if [ -f "$home_dir/.zshrc" ]; then
    echo "→ Removing $home_dir/.zshrc (backup kept)"
    rm -f "$home_dir/.zshrc"
  fi

  # Fix ownership in case script runs as root
  chown -R "$u":"$u" "$home_dir" || true
}

remove_system_zsh_bits() {
  echo "→ Purging zsh package"
  apt-get update -y
  DEBIAN_FRONTEND=noninteractive apt-get purge -y zsh zsh-common || true
  apt-get autoremove -y
  apt-get autoclean -y

  # Remove any leftover system zsh config (safe to ignore if absent)
  for p in /etc/zsh /etc/zshrc /etc/zshenv /etc/zprofile /etc/zlogin /etc/zlogout; do
    if [ -e "$p" ]; then
      echo "→ Removing $p"
      rm -rf "$p"
    fi
  done
}

main() {
  require_root

  echo "=== Step 1: Ensure login shells are set to /bin/bash before removing zsh ==="
  set_shell_to_bash_if_needed "$TARGET_USER"

  # If root's shell is zsh, switch it too (prevents su/sudo breakage)
  ROOT_SHELL="$(user_shell root || echo /bin/bash)"
  if [[ "$ROOT_SHELL" != "/bin/bash" ]]; then
    echo "→ Changing login shell for 'root' from '$ROOT_SHELL' to /bin/bash"
    chsh -s /bin/bash root
  else
    echo "✓ root already uses /bin/bash"
  fi

  echo "=== Step 2: Remove user-level Oh My Zsh & config for $TARGET_USER ==="
  backup_and_remove_user_zsh_files "$TARGET_USER"

  # Optional: clean zsh for *other* human users too (uncomment if desired)
  # awk -F: '($3>=1000)&&($1!="nobody"){print $1}' /etc/passwd | while read u; do
  #   [ "$u" != "$TARGET_USER" ] && backup_and_remove_user_zsh_files "$u"
  #   set_shell_to_bash_if_needed "$u"
  # done

  echo "=== Step 3: Remove system zsh packages/config ==="
  remove_system_zsh_bits

  echo "=== Done ==="
  echo "✅ Reverted to bash. Open a NEW session to ensure /bin/bash is in effect."
  echo "ℹ️ Backups (if any) live at: ~/.zshrc.bak.$BACKUP_SUFFIX"
}

main "$@"
