# bash-utils

Utility shell scripts. Currently: a suite for provisioning Ubuntu servers.

```
setup-server/                  # machine provisioning
└── user-management/           # everything about user accounts
```

## setup-server

| Script | Purpose | Run via pipe? |
| --- | --- | --- |
| `zsh-config.sh` | zsh + Oh My Zsh + autosuggestions/syntax-highlighting | yes |
| `zsh-config-revert.sh` | Undo the above, restore `/bin/bash` | yes (`sudo`) |
| `docker-config.sh` | Docker Engine, CLI, containerd, compose plugin | yes |
| `install-nginx.sh` | Nginx, default vhost, optional certbot TLS | yes |
| `install-nvm.sh` | nvm + a Node.js release (per-user, no sudo) | yes |
| `install-claude-code.sh` | Claude Code CLI, native installer or npm | yes |
| `file-managment.sh` | Permission / disk-usage reference snippets | no |

```bash
curl -fsSL https://raw.githubusercontent.com/vanphongngo/bash-utils/main/setup-server/zsh-config.sh | bash
curl -fsSL https://raw.githubusercontent.com/vanphongngo/bash-utils/main/setup-server/docker-config.sh | bash
curl -fsSL https://raw.githubusercontent.com/vanphongngo/bash-utils/main/setup-server/install-nginx.sh | bash
```

Node via nvm, then Claude Code (both install into `$HOME` — run them as the
user who will use them, **without** `sudo`):

```bash
curl -fsSL https://raw.githubusercontent.com/vanphongngo/bash-utils/main/setup-server/install-nvm.sh | bash
curl -fsSL https://raw.githubusercontent.com/vanphongngo/bash-utils/main/setup-server/install-claude-code.sh | bash
```

Pin the nvm release or the Node version, or force an install method:

```bash
curl -fsSL https://raw.githubusercontent.com/vanphongngo/bash-utils/main/setup-server/install-nvm.sh \
  | NVM_VERSION=v0.40.3 NODE_VERSION=22 bash
curl -fsSL https://raw.githubusercontent.com/vanphongngo/bash-utils/main/setup-server/install-claude-code.sh \
  | INSTALL_METHOD=npm bash
```

Nginx with TLS (certbot runs only when `DOMAIN` is set):

```bash
curl -fsSL https://raw.githubusercontent.com/vanphongngo/bash-utils/main/setup-server/install-nginx.sh \
  | DOMAIN=example.duckdns.org CERTBOT_EMAIL=you@example.com bash
```

Revert zsh:

```bash
curl -fsSL https://raw.githubusercontent.com/vanphongngo/bash-utils/main/setup-server/zsh-config-revert.sh | sudo bash
```

## setup-server/user-management

| Script | Purpose | Run via pipe? |
| --- | --- | --- |
| `create-user.sh` | **Interactive**: create a user — password, privileges, shell, SSH keys | yes (`sudo`) |
| `deploy-sudoers.sh` | Passwordless sudo for deploy tasks (docker/nginx/systemctl) + web root ownership | yes |
| `delete-user.sh` | Remove a user + home, crontab, sudoers rules, orphaned files | yes (`sudo`) |
| `playbook.md` | User & group reference — **documentation, not a script** | n/a |

Create a user interactively. It asks for the username, password, privilege
level, login shell and SSH key, reading the answers from the terminal even
when the script itself came down the pipe:

```bash
curl -fsSL https://raw.githubusercontent.com/vanphongngo/bash-utils/main/setup-server/user-management/create-user.sh | sudo bash
```

Same thing without prompts (for CI):

```bash
curl -fsSL https://raw.githubusercontent.com/vanphongngo/bash-utils/main/setup-server/user-management/create-user.sh \
  | TARGET_USER=deploy USER_PASSWORD='s3cret-pass' PRIVILEGE=deploy SHELL_SETUP=zsh \
    SSH_MODE=paste SSH_PUBKEY="$(cat ~/.ssh/id_ed25519.pub)" sudo -E bash
```

Grant an existing user passwordless sudo for deployments only:

```bash
curl -fsSL https://raw.githubusercontent.com/vanphongngo/bash-utils/main/setup-server/user-management/deploy-sudoers.sh \
  | TARGET_USER=deploy SERVICES="nginx docker" sudo -E bash
```

Delete a user (asks you to re-type the name before anything is removed):

```bash
curl -fsSL https://raw.githubusercontent.com/vanphongngo/bash-utils/main/setup-server/user-management/delete-user.sh | sudo bash -s -- mdeploy
```

`bash -s --` is what passes the username through the pipe; without it the
argument would be read as a filename for bash itself. Back the home directory
up first, or leave it in place:

```bash
curl -fsSL https://raw.githubusercontent.com/vanphongngo/bash-utils/main/setup-server/user-management/delete-user.sh \
  | BACKUP_DIR=/root/backups sudo -E bash -s -- mdeploy
curl -fsSL https://raw.githubusercontent.com/vanphongngo/bash-utils/main/setup-server/user-management/delete-user.sh \
  | REMOVE_HOME=no sudo -E bash -s -- mdeploy
```

### Notes

- Targets Ubuntu (apt, systemd). The installers are idempotent — re-running
  them is safe.
- `zsh-config.sh` and `docker-config.sh` change your login shell / groups; log
  out and back in for those to take effect.
- `install-nvm.sh` and `install-claude-code.sh` install into `$HOME`, so run
  them as the target user, not under `sudo` (they still call `sudo apt-get` for
  the few system packages they need). Both append to `~/.bashrc` and `~/.zshrc`
  only when the line is not already there, so a new shell is needed afterwards.
  `NODE_VERSION` accepts `--lts` (default), a major (`22`) or an exact version;
  set it to an empty string to install nvm alone.
- Neither of them calls `sudo` unless a prerequisite is genuinely missing, and
  they probe with `sudo -n true` first — an account that cannot sudo without a
  password gets a clear message naming the packages to install as root, instead
  of a sudo failure from inside the pipe (`curl | bash` gives sudo no reliable
  way to prompt).
- `install-claude-code.sh` defaults to the native installer
  (`https://claude.ai/install.sh`, no Node required) and falls back to
  `npm install -g @anthropic-ai/claude-code`. It sources an nvm install if one
  exists, so running it after `install-nvm.sh` in the same session finds `npm`.
  Authentication is a one-time browser login on first `claude` run — nothing is
  configured by the script.
- `create-user.sh` is the one script that asks questions; it prompts on
  `/dev/tty`, so piping it into `sudo bash` still works. Set `TARGET_USER`,
  `USER_PASSWORD`, `PRIVILEGE` (`basic` / `deploy` / `sudo` / `sudo-nopass`),
  `EXTRA_GROUPS`, `SHELL_SETUP` (`bash` / `zsh`) and `SSH_MODE`
  (`paste` / `generate` / `none`) to skip prompts.
- The two halves of a key pair travel in opposite directions, so the script
  prints both and labels them. With `SSH_MODE=paste` you supply the *public*
  key of the machine you connect from (`SSH_PUBKEY`, one per line — several are
  fine) and it is authorised for login. With `SSH_MODE=generate` the pair is
  created here: the *public* half is printed for you to paste into GitHub
  (account keys or a repo deploy key) or into another server's
  `authorized_keys`, and the *private* half is the one your laptop needs to log
  in — copy it off, then delete it from the server.
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
