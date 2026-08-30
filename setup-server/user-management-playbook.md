# Ubuntu user management playbook

Reference for managing user accounts on Ubuntu by hand. Copy the line you
need — this is documentation, not a script.

For the common paths there are scripts in this directory that already do the
right thing, with validation and idempotency:

| Task | Script |
| --- | --- |
| Create a user (password, privileges, SSH key) | `create-user.sh` |
| Grant passwordless sudo for deployments | `deploy-sudoers.sh` |
| Delete a user and clean up after it | `delete-user.sh` |

> This file replaces `ubuntu-user-management.sh`. That was a shell script whose
> every line had to stay commented out so that piping it into `bash` would not
> delete users and files — a document pretending to be a script. It is a
> document now.

## Naming rules for anything you copy out

- Never use `USER` as your own variable. It holds the login name from the
  environment; overwriting it breaks later commands in the same shell.
- Never use `GROUPS` as your own variable. In bash it is a **read-only special
  array**, so `GROUPS="sudo,docker"` fails outright and leaves it unusable.

Use `TARGET_USER` and `EXTRA_GROUPS` instead, as below.

```bash
TARGET_USER="pdeploy"          # the account being worked on
EXTRA_GROUPS="sudo,docker"     # comma-separated supplementary groups
NEW_USER="deploy"              # used by the rename section
```

## Create and set up a user

```bash
sudo adduser "$TARGET_USER"                  # interactive: user, home, password
sudo useradd -m -s /bin/bash "$TARGET_USER"  # non-interactive; -m creates the home
sudo passwd "$TARGET_USER"
sudo usermod -aG "$EXTRA_GROUPS" "$TARGET_USER"
```

`adduser` prompts, so it stalls under `curl | bash`; `useradd` is the one to
script with. `usermod -aG` **appends** — without `-a` it replaces every
supplementary group the user has.

Verify:

```bash
id "$TARGET_USER"              # UID, GID, all groups
getent passwd "$TARGET_USER"   # the account exists
groups "$TARGET_USER"          # group memberships
getent group sudo              # who is in 'sudo'
```

## Shell and dotfiles (zsh example)

Install zsh first — `chsh` fails if the shell is missing from `/etc/shells`.

```bash
sudo chsh -s "$(command -v zsh)" "$TARGET_USER"
sudo rsync -a /root/.oh-my-zsh/ "/home/$TARGET_USER/.oh-my-zsh/"
sudo install -m 0644 -o "$TARGET_USER" -g "$TARGET_USER" /root/.zshrc "/home/$TARGET_USER/.zshrc"
sudo chown -R "$TARGET_USER:$TARGET_USER" "/home/$TARGET_USER/.oh-my-zsh"
```

Pass the username to `chsh`. Without it you change **your own** shell, not
theirs. Bare `chsh` also prompts for a password, which cannot work in a pipe —
`sudo chsh -s <shell> <user>` does not prompt.

## SSH keys

`sshd` ignores `authorized_keys` unless the permissions are exactly this tight:

```bash
sudo install -d -m 0700 -o "$TARGET_USER" -g "$TARGET_USER" "/home/$TARGET_USER/.ssh"
sudo -u "$TARGET_USER" touch "/home/$TARGET_USER/.ssh/authorized_keys"
sudo chmod 600 "/home/$TARGET_USER/.ssh/authorized_keys"

# Generate a key pair for the user (no passphrase, for unattended deploys)
sudo -u "$TARGET_USER" ssh-keygen -t ed25519 -N '' \
  -f "/home/$TARGET_USER/.ssh/id_ed25519"
```

## Sudo behaviour

```bash
sudo -i     # root shell
sudo -v     # cache credentials now
sudo -k     # forget cached credentials immediately
sudo -l -U "$TARGET_USER"   # list another user's rules
```

Passwordless sudo — **validate the file before it takes effect**, because a
syntax error anywhere in `/etc/sudoers.d` locks you out of `sudo` entirely:

```bash
echo "$TARGET_USER ALL=(ALL) NOPASSWD:ALL" | sudo tee "/tmp/90-$TARGET_USER" >/dev/null
sudo visudo -cf "/tmp/90-$TARGET_USER" \
  && sudo install -m 0440 -o root -g root "/tmp/90-$TARGET_USER" "/etc/sudoers.d/90-$TARGET_USER-nopasswd"
```

Files in `/etc/sudoers.d` must be mode `0440` root:root, and the filename must
contain **no dot** and not end in `~` — sudo silently ignores the rest.

Extend the sudo grace period to 60 minutes for one user:

```bash
echo "Defaults:$TARGET_USER timestamp_timeout=60" | sudo tee "/tmp/91-$TARGET_USER" >/dev/null
sudo visudo -cf "/tmp/91-$TARGET_USER" \
  && sudo install -m 0440 -o root -g root "/tmp/91-$TARGET_USER" "/etc/sudoers.d/91-$TARGET_USER-timeout"
```

Prefer scoped rules over `NOPASSWD:ALL`. Note that passwordless `docker` is
root-equivalent either way — `docker run -v /:/host` mounts the whole disk —
so the docker group and a docker sudo rule are the same grant. `deploy-sudoers.sh`
makes that trade deliberately, for a dedicated deploy account.

## Account maintenance

```bash
sudo passwd "$TARGET_USER"        # set/change password
sudo passwd -l "$TARGET_USER"     # lock (disable password auth)
sudo passwd -u "$TARGET_USER"     # unlock
sudo usermod -L "$TARGET_USER"    # lock (alternative)
sudo usermod -U "$TARGET_USER"    # unlock
sudo chage -l "$TARGET_USER"      # password aging info
sudo chage -E 0 "$TARGET_USER"    # expire the account now (disable login)
sudo chage -E -1 "$TARGET_USER"   # remove the expiry
```

Locking the password does **not** block SSH key login. To cut off access
entirely, expire the account (`chage -E 0`) or empty `authorized_keys`.

`chpasswd` runs through PAM, so `pam_pwquality` rejects weak passwords even
when root sets them:

```bash
printf '%s:%s' "$TARGET_USER" 'the-password' | sudo chpasswd

# Bypass the quality check by supplying an already-hashed password:
printf '%s:%s' "$TARGET_USER" "$(openssl passwd -6)" | sudo chpasswd -e
```

## Rename a user / move the home directory

The user must have **no running processes** or `usermod` refuses with
"user is currently used by process …".

```bash
sudo pkill -u "$TARGET_USER"
sudo usermod -l "$NEW_USER" "$TARGET_USER"         # rename the login
sudo groupmod -n "$NEW_USER" "$TARGET_USER"        # rename the primary group
sudo usermod -m -d "/home/$NEW_USER" "$NEW_USER"   # move home, update the path
```

## Listing and audit

```bash
cut -d: -f1 /etc/passwd                    # all usernames
awk -F: '$3>=1000{print $1}' /etc/passwd   # likely human users (UID >= 1000)
who                                        # currently logged in
lastlog | grep -v "Never"                  # last login per account
```

Groups — prefer `getent`, which also sees LDAP/SSSD sources that
`/etc/group` does not contain:

```bash
getent group                                 # all groups
getent group | awk -F: '{print $1}' | sort   # names, sorted
getent group | sort -t: -k3,3n               # sorted by GID
getent group | wc -l                         # count
getent group | awk -F: '{printf "%-20s GID=%-6s Members=%s\n",$1,$3,$4}'
```

## Group management

```bash
sudo usermod -aG docker "$TARGET_USER"   # add (-a is REQUIRED — see above)
sudo gpasswd -d "$TARGET_USER" docker    # remove from a group
getent group docker                      # members of a group
sudo groupadd deployers
sudo groupdel deployers                  # only when it has no members left
```

## ☠️ Removal — destructive and irreversible

Use `delete-user.sh`: it refuses root, refuses the account you are sudo'ing
from, refuses the last member of `sudo`, shows what will be destroyed, and
makes you re-type the username. By hand:

```bash
sudo pkill -u "$TARGET_USER"       # stop the user's processes first
sudo userdel -r "$TARGET_USER"     # delete user + home + mail spool
```

`userdel` does not remove crontabs or sudoers rules — a leftover crontab keeps
firing under whoever inherits the UID:

```bash
sudo crontab -r -u "$TARGET_USER"
sudo rm -f "/etc/sudoers.d/90-$TARGET_USER"
```

Files outside the home directory. **Inspect before deleting** — an empty or
wrong `TARGET_USER` here wipes system files:

```bash
sudo find / -xdev -user "$TARGET_USER" -print     # 1. look
sudo find / -xdev -user "$TARGET_USER" -delete    # 2. only then delete
```

`-xdev` keeps `find` on the root filesystem so it never walks into a mounted
share or an external disk. After `userdel` the name is gone, so search by the
numeric UID instead: `sudo find / -xdev -uid 1001 -print`.

One-shot alternative: `sudo deluser --remove-all-files "$TARGET_USER"`.

Verify:

```bash
getent passwd "$TARGET_USER" || echo "User $TARGET_USER removed"
```

## Recovery

```bash
sudo chsh -s /bin/bash root                                    # root's shell was broken
sudo chown -R "$TARGET_USER:$TARGET_USER" "/home/$TARGET_USER" # fix home ownership
pkexec visudo                                                  # sudo itself is broken
```

If a bad `/etc/sudoers.d` file has locked out `sudo` and `pkexec` is
unavailable, reboot into recovery mode and use the root shell to delete it.
