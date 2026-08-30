# bash-utils

Utility shell scripts. Currently: a suite for provisioning Ubuntu servers.

## setup-server

| Script | Purpose | Run via pipe? |
| --- | --- | --- |
| `zsh-config.sh` | zsh + Oh My Zsh + autosuggestions/syntax-highlighting | yes |
| `zsh-config-revert.sh` | Undo the above, restore `/bin/bash` | no (needs `sudo bash`) |
| `docker-config.sh` | Docker Engine, CLI, containerd, compose plugin | yes |
| `install-nginx.sh` | Nginx, default vhost, optional certbot TLS | yes |
| `create-user.sh` | **Interactive**: create a user (username, password, privileges) + SSH key | yes (`sudo`) |
| `deploy-sudoers.sh` | Passwordless sudo for deploy tasks (docker/nginx/systemctl) + web root ownership | yes |
| `file-managment.sh` | Permission / disk-usage reference snippets | no |
| `ubuntu-user-management.sh` | User & group cheat sheet — **reference only, does not execute** | no |

### Quick start

```bash
curl -fsSL https://raw.githubusercontent.com/vanphongngo/bash-utils/main/setup-server/zsh-config.sh | bash
curl -fsSL https://raw.githubusercontent.com/vanphongngo/bash-utils/main/setup-server/docker-config.sh | bash
curl -fsSL https://raw.githubusercontent.com/vanphongngo/bash-utils/main/setup-server/install-nginx.sh | bash
```

Nginx with TLS (certbot runs only when `DOMAIN` is set):

```bash
curl -fsSL https://raw.githubusercontent.com/vanphongngo/bash-utils/main/setup-server/install-nginx.sh \
  | DOMAIN=example.duckdns.org CERTBOT_EMAIL=you@example.com bash
```

Create a user interactively — it asks for the username, password, privilege
level and SSH key, and reads those answers from the terminal even when the
script itself came down the pipe:

```bash
sudo bash setup-server/create-user.sh
curl -fsSL https://raw.githubusercontent.com/vanphongngo/bash-utils/main/setup-server/create-user.sh | sudo bash
```

Same thing without prompts (for CI):

```bash
TARGET_USER=deploy USER_PASSWORD='s3cret-pass' PRIVILEGE=deploy SSH_MODE=generate \
  sudo -E bash setup-server/create-user.sh
```

Grant an existing user passwordless sudo for deployments only:

```bash
curl -fsSL https://raw.githubusercontent.com/vanphongngo/bash-utils/main/setup-server/deploy-sudoers.sh \
  | TARGET_USER=deploy SERVICES="nginx docker" sudo -E bash
```

Revert zsh:

```bash
sudo bash setup-server/zsh-config-revert.sh
```

### Notes

- Targets Ubuntu (apt, systemd). The installers are idempotent — re-running them is safe.
- `zsh-config.sh` and `docker-config.sh` change your login shell / groups; log out and back in for those to take effect.
- `create-user.sh` is the one script that asks questions; it prompts on
  `/dev/tty`, so piping it into `sudo bash` still works. Set `TARGET_USER`,
  `USER_PASSWORD`, `PRIVILEGE` (`basic` / `deploy` / `sudo` / `sudo-nopass`),
  `EXTRA_GROUPS` and `SSH_MODE` (`generate` / `paste` / `none`) to skip prompts.
- `deploy-sudoers.sh` writes a validated file under `/etc/sudoers.d` (checked
  with `visudo -cf` before install) and hands `/var/www` to the user rather
  than granting `sudo chown`/`rm` on it. Passwordless `docker` is
  root-equivalent — use it on a dedicated deploy account, not a shared login.
# bash-utils
