sudo adduser pdeploy
sudo usermod -aG sudo pdeploy
sudo cp -r /root/.oh-my-zsh /home/pdeploy/
sudo cp /root/.zshrc /home/pdeploy/
sudo chown -R pdeploy:pdeploy /home/pdeploy/.oh-my-zsh
sudo chown pdeploy:pdeploy /home/pdeploy/.zshrc
chsh -s "$(which zsh)"
sudo -i ## => no need sudo keyword for following commands
sudo -v ## => input password at the first time access to the session, then no need to input password again

sudo pkill -u username   # Kill all processes of the user
sudo userdel -r username # Delete the user and remove their home directory
sudo find / -user username -exec rm -rf {} \; 2>/dev/null # Delete any files owned by the user outside home
sudo deluser username 2>/dev/null # Extra cleanup: remove from groups if still present
getent passwd | grep username # Verify if user still exists (should return nothing)



# ====== QUICK VARS ======
USER="pdeploy"                         # target username
GROUPS="sudo,docker"                   # comma-separated supplementary groups

# ====== CREATE / SETUP USER ======
sudo adduser "$USER"                   # interactive: create user, home, set password
# or (non-interactive example): sudo useradd -m -s /bin/bash "$USER" && sudo passwd "$USER"

sudo usermod -aG "$GROUPS" "$USER"     # add the user to common admin/dev groups

id "$USER"                             # verify UID/GID and groups
getent passwd "$USER"                  # verify account exists
groups "$USER"                         # show user’s group memberships
getent group sudo                      # confirm who’s in 'sudo'

# ====== SHELL / DOTFILES (zsh example) ======
chsh -s "$(command -v zsh)" "$USER"    # set default login shell to zsh for this user
# Copy zsh config from root with perms preserved (safer than cp -r)
sudo rsync -a /root/.oh-my-zsh/ "/home/$USER/.oh-my-zsh/"
sudo install -m 0644 /root/.zshrc "/home/$USER/.zshrc"
sudo chown -R "$USER:$USER" "/home/$USER/.oh-my-zsh" "/home/$USER/.zshrc"

# ====== SSH KEYS QUICK SETUP (optional) ======
sudo -u "$USER" mkdir -p "/home/$USER/.ssh"          # create .ssh as the user
sudo chmod 700 "/home/$USER/.ssh"                    # secure directory
sudo -u "$USER" touch "/home/$USER/.ssh/authorized_keys"
sudo chmod 600 "/home/$USER/.ssh/authorized_keys"    # secure file

# ====== SUDO BEHAVIOR ======
sudo -i                                # start a root shell (no sudo needed inside this session)
sudo -v                                # cache sudo credentials now (enter password once)
sudo -k                                # forget cached sudo credentials immediately (force re-prompt)
# Allow passwordless sudo for this user (safe via sudoers.d + validation)
echo "$USER ALL=(ALL) NOPASSWD:ALL" | sudo tee "/etc/sudoers.d/90-$USER-nopasswd" >/dev/null
sudo visudo -cf "/etc/sudoers.d/90-$USER-nopasswd"   # validate sudoers syntax

# (Optional) extend sudo grace period to 60 minutes just for this user
echo "Defaults:$USER timestamp_timeout=60" | sudo tee "/etc/sudoers.d/91-$USER-timeout" >/dev/null
sudo visudo -cf "/etc/sudoers.d/91-$USER-timeout"

# ====== ACCOUNT MAINTENANCE ======
sudo passwd "$USER"                    # set/change password
sudo passwd -l "$USER"                 # lock the account (disable password auth)
sudo passwd -u "$USER"                 # unlock the account
sudo usermod -L "$USER"                # lock (alternative to passwd -l)
sudo usermod -U "$USER"                # unlock (alternative to passwd -u)
sudo chage -l "$USER"                  # show password aging info
sudo chage -E 0 "$USER"                # expire the account immediately (disable login)
sudo chage -E -1 "$USER"               # remove expiration (never expires)

# Rename user / move home (careful on active sessions)
NEWUSER="deploy"
sudo usermod -l "$NEWUSER" "$USER"     # rename login from $USER to $NEWUSER
sudo groupmod -n "$NEWUSER" "$USER"    # rename primary group to match
sudo usermod -m -d "/home/$NEWUSER" "$NEWUSER"  # move home and update path

# ====== LISTING / AUDIT ======
cut -d: -f1 /etc/passwd                # list all usernames
awk -F: '$3>=1000{print $1}' /etc/passwd  # list (likely) human users (UID >= 1000)
who                                    # who’s currently logged in
lastlog | grep -v "Never"              # last login per account (non-empty)

# ====== GROUP MANAGEMENT ======
sudo usermod -aG docker "$NEWUSER"     # add to a group
sudo gpasswd -d "$NEWUSER" docker      # remove from a group
getent group docker                    # view members of a group

# ====== SAFE REMOVAL (KILL, DELETE, CLEAN) ======
TARGET="username"                      # user to remove
sudo pkill -u "$TARGET"                # stop all processes owned by the user
sudo userdel -r "$TARGET"              # delete user + home + mail spool
# (deep clean files outside home; use with care on multi-tenant systems)
sudo find / -xdev -user "$TARGET" -exec rm -rf {} + 2>/dev/null
# Alternative one-liner cleanup:
# sudo deluser --remove-all-files "$TARGET"

getent passwd | grep "$TARGET" || echo "User $TARGET removed"  # verify removal

# ====== RECOVERY / MISC ======
sudo chsh -s /bin/bash root            # if you accidentally set root’s shell wrong, reset to bash
sudo chown -R "$NEWUSER:$NEWUSER" "/home/$NEWUSER"  # fix ownership of home if needed

getent group                                  # List all existing groups (portable, preferred)
cut -d: -f1 /etc/group                        # Show only group names from /etc/group
compgen -g                                    # Bash builtin: list group names (interactive shells)
getent group | awk -F: '{print $1}' | sort    # All groups, sorted by name
getent group | sort -t: -k3,3n                # All groups sorted by GID (field 3)
getent group | wc -l                          # Count how many groups exist
awk -F: '$3>=1000{print $1}' /etc/group       # Likely human-created groups (GID ≥ 1000)
getent group | awk -F: '{printf "%-20s GID=%-6s Members=%s\n",$1,$3,$4}'  # Pretty list with GID & members
