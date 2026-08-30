#!/usr/bin/env bash
#
# ubuntu-user-management.sh — REFERENCE CHEAT SHEET (not an installer).
#
# ⚠️  DO NOT PIPE THIS INTO bash. Every command below is commented out on
#     purpose: the file mixes account creation with irreversible deletion
#     (userdel -r, find / -exec rm -rf). Executing it top-to-bottom would
#     delete users and files. Copy the single line you need instead.
#
# Naming notes for anything you copy out:
#   * Do NOT use USER as a variable name — it is the login name set by the
#     shell, and overwriting it breaks later commands in the same session.
#   * Do NOT use GROUPS as a variable name — in bash it is a read-only special
#     array, so `GROUPS="sudo,docker"` FAILS and leaves the value empty.
#   Use TARGET_USER / EXTRA_GROUPS (as below) instead.

cat <<USAGE
This file is a reference cheat sheet and does not execute anything.
Open it and copy out the command you need:  less "$0"
USAGE
exit 0

# =============================================================================
# QUICK VARS
# =============================================================================
# TARGET_USER="pdeploy"                  # target username
# EXTRA_GROUPS="sudo,docker"             # comma-separated supplementary groups
# NEW_USER="deploy"                      # used by the rename section

# =============================================================================
# CREATE / SET UP A USER
# =============================================================================
# sudo adduser "$TARGET_USER"            # interactive: create user, home, password
# sudo useradd -m -s /bin/bash "$TARGET_USER" && sudo passwd "$TARGET_USER"  # non-interactive
# sudo usermod -aG "$EXTRA_GROUPS" "$TARGET_USER"   # add to admin/dev groups
#
# id "$TARGET_USER"                      # verify UID/GID and groups
# getent passwd "$TARGET_USER"           # verify the account exists
# groups "$TARGET_USER"                  # show group memberships
# getent group sudo                      # confirm who is in 'sudo'

# =============================================================================
# SHELL / DOTFILES (zsh example)
# =============================================================================
# Install zsh first — chsh fails if the shell is missing or not in /etc/shells.
# sudo chsh -s "$(command -v zsh)" "$TARGET_USER"   # needs the username argument;
#                                                   # without it you change YOUR shell
# sudo rsync -a /root/.oh-my-zsh/ "/home/$TARGET_USER/.oh-my-zsh/"
# sudo install -m 0644 -o "$TARGET_USER" -g "$TARGET_USER" /root/.zshrc "/home/$TARGET_USER/.zshrc"
# sudo chown -R "$TARGET_USER:$TARGET_USER" "/home/$TARGET_USER/.oh-my-zsh"

# =============================================================================
# SSH KEYS
# =============================================================================
# sudo -u "$TARGET_USER" mkdir -p "/home/$TARGET_USER/.ssh"
# sudo -u "$TARGET_USER" chmod 700 "/home/$TARGET_USER/.ssh"
# sudo -u "$TARGET_USER" touch "/home/$TARGET_USER/.ssh/authorized_keys"
# sudo -u "$TARGET_USER" chmod 600 "/home/$TARGET_USER/.ssh/authorized_keys"

# =============================================================================
# SUDO BEHAVIOUR
# =============================================================================
# sudo -i                                # root shell (no sudo needed inside it)
# sudo -v                                # cache sudo credentials now
# sudo -k                                # forget cached credentials immediately
#
# Passwordless sudo — validate the file BEFORE it takes effect, otherwise a
# syntax error can lock you out of sudo entirely:
# echo "$TARGET_USER ALL=(ALL) NOPASSWD:ALL" | sudo tee "/tmp/90-$TARGET_USER" >/dev/null
# sudo visudo -cf "/tmp/90-$TARGET_USER" \
#   && sudo install -m 0440 -o root -g root "/tmp/90-$TARGET_USER" "/etc/sudoers.d/90-$TARGET_USER-nopasswd"
#
# Extend the sudo grace period to 60 minutes for this user:
# echo "Defaults:$TARGET_USER timestamp_timeout=60" | sudo tee "/tmp/91-$TARGET_USER" >/dev/null
# sudo visudo -cf "/tmp/91-$TARGET_USER" \
#   && sudo install -m 0440 -o root -g root "/tmp/91-$TARGET_USER" "/etc/sudoers.d/91-$TARGET_USER-timeout"

# =============================================================================
# ACCOUNT MAINTENANCE
# =============================================================================
# sudo passwd "$TARGET_USER"             # set/change password
# sudo passwd -l "$TARGET_USER"          # lock (disable password auth)
# sudo passwd -u "$TARGET_USER"          # unlock
# sudo usermod -L "$TARGET_USER"         # lock (alternative)
# sudo usermod -U "$TARGET_USER"         # unlock (alternative)
# sudo chage -l "$TARGET_USER"           # show password aging info
# sudo chage -E 0 "$TARGET_USER"         # expire the account now (disable login)
# sudo chage -E -1 "$TARGET_USER"        # remove expiration

# Rename a user / move the home directory. The user must have NO running
# processes or usermod refuses ("user is currently used by process ...").
# sudo pkill -u "$TARGET_USER"
# sudo usermod -l "$NEW_USER" "$TARGET_USER"        # rename the login
# sudo groupmod -n "$NEW_USER" "$TARGET_USER"       # rename the primary group
# sudo usermod -m -d "/home/$NEW_USER" "$NEW_USER"  # move home and update the path

# =============================================================================
# LISTING / AUDIT
# =============================================================================
# cut -d: -f1 /etc/passwd                     # all usernames
# awk -F: '$3>=1000{print $1}' /etc/passwd    # likely human users (UID >= 1000)
# who                                         # currently logged in
# lastlog | grep -v "Never"                   # last login per account
#
# getent group                                       # all groups (preferred)
# getent group | awk -F: '{print $1}' | sort         # group names, sorted
# getent group | sort -t: -k3,3n                     # sorted by GID
# getent group | wc -l                               # count groups
# awk -F: '$3>=1000{print $1}' /etc/group            # likely human groups
# getent group | awk -F: '{printf "%-20s GID=%-6s Members=%s\n",$1,$3,$4}'

# =============================================================================
# GROUP MANAGEMENT
# =============================================================================
# sudo usermod -aG docker "$TARGET_USER"      # add to a group (-a is REQUIRED,
#                                             # without it you REPLACE all groups)
# sudo gpasswd -d "$TARGET_USER" docker       # remove from a group
# getent group docker                         # view members of a group

# =============================================================================
# ☠️  REMOVAL — DESTRUCTIVE AND IRREVERSIBLE
# =============================================================================
# Always set TARGET_USER to a real username first. The original version of this
# file ran these against the literal string "username".
#
# sudo pkill -u "$TARGET_USER"                # stop the user's processes
# sudo userdel -r "$TARGET_USER"              # delete user + home + mail spool
#
# Deep clean of files outside home. Review the list BEFORE deleting — a bad
# TARGET_USER (or an empty variable) here can wipe system files:
# sudo find / -xdev -user "$TARGET_USER" -print          # 1. inspect
# sudo find / -xdev -user "$TARGET_USER" -delete         # 2. then delete
#
# Alternative one-liner: sudo deluser --remove-all-files "$TARGET_USER"
#
# getent passwd "$TARGET_USER" || echo "User $TARGET_USER removed"   # verify

# =============================================================================
# RECOVERY / MISC
# =============================================================================
# sudo chsh -s /bin/bash root                 # reset root's shell if it was broken
# sudo chown -R "$TARGET_USER:$TARGET_USER" "/home/$TARGET_USER"   # fix home ownership
