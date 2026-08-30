# bash-utils

Utility shell scripts. Currently: a suite for provisioning Ubuntu servers.

## setup-server

| Script | Purpose | Run via pipe? |
| --- | --- | --- |
| `zsh-config.sh` | zsh + Oh My Zsh + autosuggestions/syntax-highlighting | yes |
| `zsh-config-revert.sh` | Undo the above, restore `/bin/bash` | no (needs `sudo bash`) |
| `docker-config.sh` | Docker Engine, CLI, containerd, compose plugin | yes |
| `install-nginx.sh` | Nginx, default vhost, optional certbot TLS | yes |
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

Revert zsh:

```bash
sudo bash setup-server/zsh-config-revert.sh
```

### Notes

- Targets Ubuntu (apt, systemd). The installers are idempotent — re-running them is safe.
- `zsh-config.sh` and `docker-config.sh` change your login shell / groups; log out and back in for those to take effect.
# bash-utils
