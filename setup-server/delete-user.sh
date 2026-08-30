#!/usr/bin/env bash
# delete-user.sh — Remove a user account, safely and reversibly-ish.
#
# ☠️  DESTRUCTIVE. It deletes an account, its home directory and (optionally)
#     every file it owns elsewhere on the filesystem. Nothing is removed until
#     you have seen a summary and re-typed the username.
#
#   sudo bash delete-user.sh mdeploy
#   sudo bash delete-user.sh                       # asks for the username
#   curl -fsSL <raw-url> | sudo bash -s -- mdeploy
#
# Environment variables (all optional):
#   TARGET_USER    account to delete (same as the positional argument)
#   CONFIRM        set to the username to skip the typed confirmation (CI)
#   REMOVE_HOME    yes | no   delete the home directory   (default: yes)
#   BACKUP_DIR     tar the home into this directory first (default: none)
#   PURGE_FILES    yes | no   delete files the user owns outside its home
#                             (default: no — they are only listed)
#   FORCE          1          allow deleting a UID < 1000 system account
#
# What it will not do: delete root, delete the account you are sudo'ing from,
# or delete a system account unless FORCE=1.

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "❌ Run as root: sudo bash $0 [username]"
  exit 1
fi

TARGET_USER="${1:-${TARGET_USER:-}}"
REMOVE_HOME="${REMOVE_HOME:-yes}"
BACKUP_DIR="${BACKUP_DIR:-}"
PURGE_FILES="${PURGE_FILES:-no}"

TTY_OK=0
[ -r /dev/tty ] && TTY_OK=1

if [ -z "$TARGET_USER" ]; then
  [ "$TTY_OK" -eq 1 ] || { echo "❌ No username given and no terminal to ask on."; exit 1; }
  read -r -p "Username to DELETE: " TARGET_USER < /dev/tty || true
fi
[ -n "$TARGET_USER" ] || { echo "❌ No username given."; exit 1; }

# ---- 1. Refuse the obviously wrong targets ----------------------------------
if ! id "$TARGET_USER" >/dev/null 2>&1; then
  echo "❌ User '$TARGET_USER' does not exist — nothing to do."
  exit 1
fi

TARGET_UID="$(id -u "$TARGET_USER")"

if [ "$TARGET_UID" -eq 0 ]; then
  echo "❌ Refusing to delete a UID 0 account ('$TARGET_USER')."
  exit 1
fi

# ${SUDO_USER:-} is who invoked sudo. Deleting them mid-session leaves the
# machine with no way back in if they were the only admin.
if [ -n "${SUDO_USER:-}" ] && [ "$TARGET_USER" = "$SUDO_USER" ]; then
  echo "❌ Refusing to delete '$TARGET_USER' — that is the account running this sudo."
  exit 1
fi

# UID < 1000 is a service/system account (www-data, systemd-*, …); removing one
# breaks whatever daemon owns it.
if [ "$TARGET_UID" -lt 1000 ] && [ "${FORCE:-0}" != "1" ]; then
  echo "❌ '$TARGET_USER' is a system account (UID $TARGET_UID). Re-run with FORCE=1 if you mean it."
  exit 1
fi

# Losing the last sudo-capable human is the other way to lock yourself out.
if id -nG "$TARGET_USER" | tr ' ' '\n' | grep -qx sudo; then
  remaining="$(getent group sudo | cut -d: -f4 | tr ',' '\n' | grep -vx "$TARGET_USER" | grep -c . || true)"
  if [ "$remaining" -eq 0 ] && [ "${FORCE:-0}" != "1" ]; then
    echo "❌ '$TARGET_USER' is the only member of group 'sudo'. Deleting it could"
    echo "   lock you out of this machine. Add another admin first, or FORCE=1."
    exit 1
  fi
fi

HOME_DIR="$(getent passwd "$TARGET_USER" | cut -d: -f6)"

# ---- 2. Show exactly what is about to be destroyed --------------------------
echo
echo "==============================================================="
echo "About to DELETE user: $TARGET_USER (UID $TARGET_UID)"
id "$TARGET_USER"
echo "home:        $HOME_DIR  (remove: $REMOVE_HOME)"
echo "backup:      ${BACKUP_DIR:-<none>}"
echo "purge files: $PURGE_FILES"
echo "---------------------------------------------------------------"

echo "Running processes:"
pgrep -u "$TARGET_USER" -a || echo "  (none)"

# -xdev keeps find on the root filesystem, so it never walks into a mounted
# NFS share or an external disk. Cap the listing: a long tail is not readable.
echo "Files owned outside \$HOME (first 20, root filesystem only):"
find / -xdev -user "$TARGET_USER" -not -path "$HOME_DIR/*" -print 2>/dev/null | head -20 || true

echo "sudoers entries mentioning the user:"
grep -rls "\b$TARGET_USER\b" /etc/sudoers /etc/sudoers.d 2>/dev/null || echo "  (none)"
echo "==============================================================="

# ---- 3. Confirm -------------------------------------------------------------
# A typed username, not a y/N: this is the last stop before an irreversible
# delete, and y/N is far too easy to answer on autopilot.
if [ "${CONFIRM:-}" != "$TARGET_USER" ]; then
  [ "$TTY_OK" -eq 1 ] || { echo "❌ Not confirmed. Set CONFIRM=$TARGET_USER to run non-interactively."; exit 1; }
  read -r -p "Type the username to confirm deletion: " typed < /dev/tty || true
  if [ "$typed" != "$TARGET_USER" ]; then
    echo "→ Aborted, nothing was changed."
    exit 1
  fi
fi

# ---- 4. Back up the home directory ------------------------------------------
if [ -n "$BACKUP_DIR" ] && [ -d "$HOME_DIR" ]; then
  mkdir -p "$BACKUP_DIR"
  ARCHIVE="$BACKUP_DIR/$TARGET_USER-home-$(date +%Y%m%d-%H%M%S).tar.gz"
  # -C <parent> <basename> keeps the archive relative, so it cannot restore
  # over an absolute path by accident.
  tar -czf "$ARCHIVE" -C "$(dirname "$HOME_DIR")" "$(basename "$HOME_DIR")"
  echo "→ Backed up $HOME_DIR to $ARCHIVE"
fi

# ---- 5. Lock the account and stop its processes -----------------------------
# Lock first: userdel refuses while the user is logged in, and locking stops
# them logging back in during the seconds this takes.
usermod -L "$TARGET_USER" 2>/dev/null || true
usermod -s /usr/sbin/nologin "$TARGET_USER" 2>/dev/null || true

# pkill exits 1 when it matched nothing, which `set -e` would treat as fatal.
if pgrep -u "$TARGET_USER" >/dev/null 2>&1; then
  echo "→ Terminating processes owned by $TARGET_USER"
  pkill -TERM -u "$TARGET_USER" || true
  for _ in 1 2 3 4 5; do
    pgrep -u "$TARGET_USER" >/dev/null 2>&1 || break
    sleep 1
  done
  pkill -KILL -u "$TARGET_USER" || true
fi

# ---- 6. Scheduled jobs ------------------------------------------------------
# userdel does not touch these, and a leftover crontab keeps firing under a
# recycled UID.
crontab -r -u "$TARGET_USER" 2>/dev/null && echo "→ Removed crontab" || true
rm -f "/var/spool/cron/atjobs/"*".$TARGET_USER" 2>/dev/null || true

# ---- 7. sudoers rules written by this repo's scripts ------------------------
USER_SLUG="$(printf '%s' "$TARGET_USER" | tr -c 'A-Za-z0-9_-' '-')"
for f in "/etc/sudoers.d/90-$USER_SLUG" "/etc/sudoers.d/90-deploy-$USER_SLUG"; do
  if [ -f "$f" ]; then
    rm -f "$f"
    echo "→ Removed $f"
  fi
done
# Anything else is hand-written and may cover other users too — report, don't
# guess. A stale rule for a deleted name is inert until the name is reused.
LEFTOVER="$(grep -rls "\b$TARGET_USER\b" /etc/sudoers /etc/sudoers.d 2>/dev/null || true)"
if [ -n "$LEFTOVER" ]; then
  echo "⚠️  These sudoers files still mention '$TARGET_USER' — review by hand:"
  printf '%s\n' "$LEFTOVER" | sed 's/^/     /'
fi

# ---- 8. Delete the account --------------------------------------------------
if [ "$REMOVE_HOME" = "yes" ]; then
  userdel -r "$TARGET_USER" 2>/dev/null || userdel "$TARGET_USER"
  echo "→ Deleted $TARGET_USER and its home/mail spool"
else
  userdel "$TARGET_USER"
  echo "→ Deleted $TARGET_USER (home directory left at $HOME_DIR)"
fi

# userdel leaves the primary group behind when it still has other members.
if getent group "$TARGET_USER" >/dev/null; then
  if [ -z "$(getent group "$TARGET_USER" | cut -d: -f4)" ]; then
    groupdel "$TARGET_USER" && echo "→ Removed empty group '$TARGET_USER'"
  else
    echo "⚠️  Group '$TARGET_USER' still has members; left in place."
  fi
fi

# ---- 9. Files elsewhere on the filesystem -----------------------------------
# The UID is now unallocated, so these show as owned by a bare number and will
# silently belong to whoever gets that UID next.
ORPHANS="$(find / -xdev -uid "$TARGET_UID" -print 2>/dev/null || true)"
if [ -n "$ORPHANS" ]; then
  COUNT="$(printf '%s\n' "$ORPHANS" | grep -c . || true)"
  if [ "$PURGE_FILES" = "yes" ]; then
    printf '%s\n' "$ORPHANS" | sed 's/^/     /' | head -50
    find / -xdev -uid "$TARGET_UID" -delete 2>/dev/null || true
    echo "→ Deleted $COUNT orphaned file(s) owned by UID $TARGET_UID"
  else
    echo "⚠️  $COUNT file(s) on the root filesystem still owned by UID $TARGET_UID."
    echo "    Inspect:  sudo find / -xdev -uid $TARGET_UID -print"
    echo "    Delete:   re-run with PURGE_FILES=yes, or chown them to a live user."
  fi
fi

# ---- 10. Verify -------------------------------------------------------------
if getent passwd "$TARGET_USER" >/dev/null; then
  echo "❌ '$TARGET_USER' still exists — check the errors above."
  exit 1
fi
echo "✅ User '$TARGET_USER' removed."
