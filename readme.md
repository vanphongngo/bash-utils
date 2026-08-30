# bash-utils

Utility shell scripts. Currently: a suite for provisioning Ubuntu servers.

```
setup-server/                  # machine provisioning
└── user-management/           # everything about user accounts
```

`RAW` below is
`https://raw.githubusercontent.com/vanphongngo/bash-utils/main/setup-server`.

## setup-server

| Script | Purpose | Run via pipe? |
| --- | --- | --- |
| `zsh-config.sh` | zsh + Oh My Zsh + autosuggestions/syntax-highlighting | yes |
| `zsh-config-revert.sh` | Undo the above, restore `/bin/bash` | no (needs `sudo bash`) |
| `docker-config.sh` | Docker Engine, CLI, containerd, compose plugin | yes |
| `install-nginx.sh` | Nginx, default vhost, optional certbot TLS | yes |
| `file-managment.sh` | Permission / disk-usage reference snippets | no |

```bash
curl -fsSL $RAW/zsh-config.sh | bash
curl -fsSL $RAW/docker-config.sh | bash
curl -fsSL $RAW/install-nginx.sh | bash
```

Nginx with TLS (certbot runs only when `DOMAIN` is set):

```bash
curl -fsSL $RAW/install-nginx.sh \
  | DOMAIN=example.duckdns.org CERTBOT_EMAIL=you@example.com bash
```

Revert zsh:

```bash
sudo bash setup-server/zsh-config-revert.sh
```

## setup-server/user-management

| Script | Purpose | Run via pipe? |
| --- | --- | --- |
| `create-user.sh` | **Interactive**: create a user — password, privileges, shell, SSH login key, git key | yes (`sudo`) |
| `deploy-sudoers.sh` | Passwordless sudo for deploy tasks (docker/nginx/systemctl) + web root ownership | yes |
| `delete-user.sh` | Remove a user + home, crontab, sudoers rules, orphaned files | yes (`sudo`) |
| `playbook.md` | User & group reference — **documentation, not a script** | n/a |

Create a user interactively. It asks for the username, password, privilege
level, login shell and SSH keys, reading the answers from the terminal even
when the script itself came down the pipe:

```bash
sudo bash setup-server/user-management/create-user.sh
curl -fsSL $RAW/user-management/create-user.sh | sudo bash
```

Same thing without prompts (for CI):

```bash
TARGET_USER=deploy USER_PASSWORD='s3cret-pass' PRIVILEGE=deploy SHELL_SETUP=zsh \
  SSH_MODE=paste SSH_PUBKEY="$(cat ~/.ssh/id_ed25519.pub)" GITHUB_KEY_MODE=generate \
  sudo -E bash setup-server/user-management/create-user.sh
```

Grant an existing user passwordless sudo for deployments only:

```bash
curl -fsSL $RAW/user-management/deploy-sudoers.sh \
  | TARGET_USER=deploy SERVICES="nginx docker" sudo -E bash
```

Delete a user (asks you to re-type the name before anything is removed):

```bash
sudo bash setup-server/user-management/delete-user.sh mdeploy
BACKUP_DIR=/root/backups sudo -E bash setup-server/user-management/delete-user.sh mdeploy
```

### Notes

- Targets Ubuntu (apt, systemd). The installers are idempotent — re-running
  them is safe.
- `zsh-config.sh` and `docker-config.sh` change your login shell / groups; log
  out and back in for those to take effect.
- `create-user.sh` is the one script that asks questions; it prompts on
  `/dev/tty`, so piping it into `sudo bash` still works. Set `TARGET_USER`,
  `USER_PASSWORD`, `PRIVILEGE` (`basic` / `deploy` / `sudo` / `sudo-nopass`),
  `EXTRA_GROUPS`, `SHELL_SETUP` (`bash` / `zsh`), `SSH_MODE`
  (`paste` / `generate` / `none`) and `GITHUB_KEY_MODE`
  (`generate` / `paste` / `none`) to skip prompts.
- It sets up **two keys pointing in opposite directions**: the *public* key you
  paste (`SSH_PUBKEY`, one per line — several are fine) is authorised so you
  can log in from your laptop, and a *private* key is installed for the account
  so it can clone/push, with its public half printed for you to add at
  `https://github.com/settings/keys` or as a repo deploy key. The git key gets
  a pinned `~/.ssh/config` block and a pre-seeded `known_hosts` entry, so the
  first clone does not stop on a fingerprint prompt. `GITHUB_HOST` switches
  hosts (GHE, GitLab).
- If PAM's quality check rejects the password (`BAD PASSWORD: … fails the
  dictionary check`), the script re-prompts instead of aborting; set
  `ALLOW_WEAK_PASSWORD=1` to bypass it via a pre-hashed `chpasswd -e`.
  Re-running against a half-configured account finishes the job.
- `create-user.sh` reuses the other scripts rather than duplicating them:
  `PRIVILEGE=deploy` runs `deploy-sudoers.sh`, `SHELL_SETUP=zsh` runs
  `../zsh-config.sh` against the new account. Both are read from the checkout,
  or downloaded (override the base with `REPO_RAW_URL`) when it was piped in.
- `delete-user.sh` refuses to delete root, the account you are sudo'ing from,
  a system account (UID < 1000, unless `FORCE=1`) or the last member of the
  `sudo` group. It prints processes, owned files and sudoers references first,
  then requires the username typed back (or `CONFIRM=<user>` in CI). Files
  outside the home directory are only listed unless `PURGE_FILES=yes`.
- `deploy-sudoers.sh` writes a validated file under `/etc/sudoers.d` (checked
  with `visudo -cf` before install) and hands `/var/www` to the user rather
  than granting `sudo chown`/`rm` on it. Passwordless `docker` is
  root-equivalent — use it on a dedicated deploy account, not a shared login.
