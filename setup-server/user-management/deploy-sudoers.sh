#!/usr/bin/env bash
# deploy-sudoers.sh — Give a deploy user passwordless (NOPASSWD) sudo for the
# commands a deployment needs: docker, nginx, systemd units, certbot.
#
# It also hands the web root to that user directly (owner + setgid www-data),
# so day-to-day file work under /var/www needs no sudo at all — that is safer
# than a sudoers rule with a path wildcard, which `..` can escape.
#
# Safe to run non-interactively:
#   curl -fsSL <raw-url> | TARGET_USER=deploy bash
#
# Environment variables (all optional):
#   TARGET_USER   user to grant the rules to        (default: $SUDO_USER / $USER)
#   SERVICES      systemd units to allow            (default: "nginx docker")
#   WEB_ROOT      directory to hand to the user     (default: /var/www; empty = skip)
#   MODE          scoped | full                     (default: scoped)
#                 full = ALL=(ALL) NOPASSWD:ALL — unrestricted root, use only
#                 on a machine that is a deploy target and nothing else.
#
# ⚠️  Note on privilege: NOPASSWD docker is equivalent to passwordless root
#     (`docker run -v /:/host` mounts the whole filesystem). The same is true
#     of the docker group. This script makes that trade deliberately — it is
#     for a dedicated deploy account, not a shared login.

set -euo pipefail

TARGET_USER="${TARGET_USER:-${SUDO_USER:-$USER}}"
SERVICES="${SERVICES:-nginx docker}"
WEB_ROOT="${WEB_ROOT:-/var/www}"
MODE="${MODE:-scoped}"

SUDO=""
[ "$(id -u)" -eq 0 ] || SUDO="sudo"

# 1. Sanity checks
if ! id "$TARGET_USER" >/dev/null 2>&1; then
  echo "❌ User '$TARGET_USER' does not exist. Create it first (see create-user.sh)."
  exit 1
fi

# /etc/sudoers.d ignores any filename containing a dot or ending in ~,
# so squash everything that is not alphanumeric into a dash.
SUDOERS_FILE="/etc/sudoers.d/90-deploy-$(printf '%s' "$TARGET_USER" | tr -c 'A-Za-z0-9_-' '-')"

# 2. Resolve absolute paths — sudoers only matches fully qualified commands.
#    Fall back to the usual Ubuntu location when the tool is not installed yet;
#    a rule for a missing binary simply never matches.
bin_or() { command -v "$1" 2>/dev/null || printf '%s' "$2"; }
DOCKER="$(bin_or docker           /usr/bin/docker)"
COMPOSE="$(bin_or docker-compose  /usr/bin/docker-compose)"
SYSTEMCTL="$(bin_or systemctl     /usr/bin/systemctl)"
JOURNALCTL="$(bin_or journalctl   /usr/bin/journalctl)"
NGINX="$(bin_or nginx             /usr/sbin/nginx)"
CERTBOT="$(bin_or certbot         /usr/bin/certbot)"

# 3. Build the rule set in a temp file, validate, then install.
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

if [ "$MODE" = "full" ]; then
  cat > "$TMP" <<EOF
# Managed by deploy-sudoers.sh — MODE=full. Unrestricted passwordless root.
$TARGET_USER ALL=(ALL) NOPASSWD:ALL
EOF
else
  # One systemctl rule per unit per verb: an unrestricted `systemctl` would let
  # the user start a unit file they wrote themselves, which is plain root.
  svc_rules=""
  for unit in $SERVICES; do
    for verb in start stop restart reload reload-or-restart status enable disable is-active is-enabled; do
      svc_rules="$svc_rules    $SYSTEMCTL $verb $unit, \\
"
    done
  done
  svc_rules="$svc_rules    $SYSTEMCTL daemon-reload"

  {
    cat <<EOF
# Managed by deploy-sudoers.sh — do not edit by hand, re-run the script.
# Scoped passwordless sudo for deployment tasks only (MODE=scoped).

Cmnd_Alias DEPLOY_DOCKER = $DOCKER, $COMPOSE
Cmnd_Alias DEPLOY_SVC = \\
$svc_rules
Cmnd_Alias DEPLOY_WEB = $NGINX -t, $NGINX -s reload, $CERTBOT
Cmnd_Alias DEPLOY_LOG = $JOURNALCTL

$TARGET_USER ALL=(root) NOPASSWD: DEPLOY_DOCKER, DEPLOY_SVC, DEPLOY_WEB, DEPLOY_LOG
EOF
  } > "$TMP"
fi

# visudo -cf refuses a broken file *before* it can lock everyone out of sudo.
if ! $SUDO visudo -cf "$TMP"; then
  echo "❌ Generated sudoers file is invalid; nothing was installed."
  exit 1
fi

# install(1) sets owner/mode atomically — sudo requires 0440 root:root here.
$SUDO install -m 0440 -o root -g root "$TMP" "$SUDOERS_FILE"
echo "→ Installed $SUDOERS_FILE (MODE=$MODE)"

# 4. Group membership: docker without sudo, and www-data for the web root.
if getent group docker >/dev/null; then
  $SUDO usermod -aG docker "$TARGET_USER"
  echo "→ Added $TARGET_USER to group 'docker'"
fi

# 5. Hand the web root to the user instead of granting sudo chown/rm on it.
#    setgid (2775) makes every new file inherit www-data, so nginx can read
#    whatever the deploy user writes without another chmod pass.
if [ -n "$WEB_ROOT" ]; then
  if getent group www-data >/dev/null; then
    $SUDO usermod -aG www-data "$TARGET_USER"
    $SUDO mkdir -p "$WEB_ROOT"
    $SUDO chown -R "$TARGET_USER:www-data" "$WEB_ROOT"
    $SUDO find "$WEB_ROOT" -type d -exec chmod 2775 {} +
    $SUDO find "$WEB_ROOT" -type f -exec chmod 0664 {} +
    echo "→ $WEB_ROOT is now owned by $TARGET_USER:www-data (setgid, no sudo needed)"
  else
    echo "⚠️  Group 'www-data' not found (nginx not installed?); skipped $WEB_ROOT."
  fi
fi

# 6. Show what the user may now run. `sudo -n` never prompts, and `-l -U`
#    lists another user's rules; `|| true` because it exits non-zero when the
#    list is empty and `set -e` would abort on that.
echo
echo "Effective rules for $TARGET_USER:"
$SUDO sudo -n -l -U "$TARGET_USER" 2>/dev/null || true

echo "✅ Done. Log out and back in for the new group membership to apply."
