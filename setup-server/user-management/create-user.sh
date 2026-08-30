#!/usr/bin/env bash
# create-user.sh — INTERACTIVE user provisioning for Ubuntu.
#
# Asks for a username, a password, a privilege level, then creates the account
# and generates an SSH key pair for it.
#
# Unlike the other installers here this one is interactive on purpose, so it
# reads every prompt from /dev/tty rather than stdin — that keeps it working
# when the script itself arrives on stdin:
#
#   sudo bash create-user.sh
#   curl -fsSL <raw-url> | sudo bash
#
# The account gets one key pair, and the script prints both halves with the
# direction spelled out: the PUBLIC half is what you paste into GitHub (or
# another server's authorized_keys), the PRIVATE half is what your laptop needs
# in order to log in here.
#
# Every answer can also be pre-set, which skips the matching prompt and makes
# the script usable from CI:
#   TARGET_USER=deploy USER_PASSWORD='s3cret' PRIVILEGE=deploy SSH_MODE=generate \
#     sudo -E bash create-user.sh
#
# ALLOW_WEAK_PASSWORD=1 bypasses PAM's password-quality check (see step 7).
# REPO_RAW_URL overrides where the sibling scripts (deploy-sudoers.sh,
# zsh-config.sh) are fetched from when they are not sitting next to this one
# (i.e. when this ran from a pipe).

set -euo pipefail

# ---- must be root -----------------------------------------------------------
if [ "$(id -u)" -ne 0 ]; then
  echo "❌ Run as root: sudo bash $0"
  exit 1
fi

# ---- prompt helpers ---------------------------------------------------------
# Reading from /dev/tty (not stdin) is what makes `curl … | sudo bash` work.
TTY_OK=0
[ -r /dev/tty ] && TTY_OK=1

need_tty() {
  if [ "$TTY_OK" -ne 1 ]; then
    echo "❌ No terminal available and \$$1 is not set — cannot ask for '$1'."
    exit 1
  fi
}

# ---- sibling scripts --------------------------------------------------------
# The deploy and zsh options reuse the other scripts in this directory rather
# than duplicating them. Under `curl | bash` this script has no path at all —
# BASH_SOURCE is unset, which `set -u` turns into "unbound variable" — so fall
# back to fetching them over the network.
# Paths below are relative to setup-server/, so this file can sit in
# setup-server/user-management/ and still reach ../zsh-config.sh.
REPO_RAW_URL="${REPO_RAW_URL:-https://raw.githubusercontent.com/vanphongngo/bash-utils/main/setup-server}"
BASE_DIR=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  BASE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fi

FETCHED=()
trap 'rm -f "${FETCHED[@]:-}"' EXIT

fetch_sibling() {  # print a runnable path for a script in this repo, or fail
  local name="$1" tmp
  if [ -n "$BASE_DIR" ] && [ -f "$BASE_DIR/$name" ]; then
    printf '%s' "$BASE_DIR/$name"
    return 0
  fi
  tmp="$(mktemp)"
  # Progress goes to stderr — stdout is the return value of this function.
  echo "→ Fetching $name from $REPO_RAW_URL" >&2
  if curl -fsSL "$REPO_RAW_URL/$name" -o "$tmp" && [ -s "$tmp" ]; then
    FETCHED+=("$tmp")
    printf '%s' "$tmp"
    return 0
  fi
  rm -f "$tmp"
  return 1
}

ask() {            # ask VAR_NAME "prompt" ["default"]
  local var="$1" prompt="$2" default="${3:-}" current answer
  current="${!var:-}"
  if [ -n "$current" ]; then return 0; fi
  need_tty "$var"
  if [ -n "$default" ]; then
    read -r -p "$prompt [$default]: " answer < /dev/tty || true
    answer="${answer:-$default}"
  else
    read -r -p "$prompt: " answer < /dev/tty || true
  fi
  printf -v "$var" '%s' "$answer"
}

ask_secret() {     # ask_secret VAR_NAME "prompt" — silent, asked twice
  local var="$1" prompt="$2" first second
  if [ -n "${!var:-}" ]; then return 0; fi
  need_tty "$var"
  while :; do
    read -r -s -p "$prompt: " first < /dev/tty; echo
    read -r -s -p "Confirm $prompt: " second < /dev/tty; echo
    if [ "$first" != "$second" ]; then
      echo "  ✗ Passwords do not match, try again."
    elif [ "${#first}" -lt 8 ]; then
      echo "  ✗ Too short — use at least 8 characters."
    else
      printf -v "$var" '%s' "$first"
      return 0
    fi
  done
}

confirm() {        # confirm "question" — default no
  local answer
  [ "$TTY_OK" -eq 1 ] || return 1
  read -r -p "$1 [y/N]: " answer < /dev/tty || true
  [[ "$answer" =~ ^[Yy]$ ]]
}

# ---- 1. Username ------------------------------------------------------------
TARGET_USER="${TARGET_USER:-}"
ask TARGET_USER "Username to create"

# Same rule adduser enforces: start with a letter or underscore, then lower
# case letters, digits, underscore or dash. Anything else breaks tooling later.
if ! [[ "$TARGET_USER" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
  echo "❌ Invalid username '$TARGET_USER' (expected: ^[a-z_][a-z0-9_-]*$)"
  exit 1
fi

USER_EXISTS=0
if id "$TARGET_USER" >/dev/null 2>&1; then
  USER_EXISTS=1
  echo "ℹ️  User '$TARGET_USER' already exists — it will be reconfigured, not recreated."
fi

# ---- 2. Password ------------------------------------------------------------
USER_PASSWORD="${USER_PASSWORD:-}"
if [ -n "$USER_PASSWORD" ]; then
  :                                   # supplied via the environment
elif [ "$USER_EXISTS" -eq 1 ]; then
  # Re-running against an existing account must not force a password change,
  # and must not stall waiting for one when there is no terminal.
  if [ "$TTY_OK" -eq 1 ] && confirm "Set a new password for existing user '$TARGET_USER'?"; then
    ask_secret USER_PASSWORD "Password for $TARGET_USER"
  else
    echo "→ Keeping the current password."
  fi
else
  echo "(the system password policy usually wants 12+ chars, mixed case and"
  echo " digits, and rejects dictionary words — see ALLOW_WEAK_PASSWORD)"
  ask_secret USER_PASSWORD "Password for $TARGET_USER"
fi

# ---- 3. Privilege level -----------------------------------------------------
PRIVILEGE="${PRIVILEGE:-}"
if [ -z "$PRIVILEGE" ]; then
  need_tty PRIVILEGE
  cat <<'MENU'

Privilege level:
  1) basic       — plain user, no sudo
  2) deploy      — docker + www-data groups, passwordless sudo scoped to
                   docker / nginx / systemctl / certbot  (recommended for CI)
  3) sudo        — full sudo, password required each time (recommended for humans)
  4) sudo-nopass — full sudo, never asks for a password (root-equivalent)
MENU
  read -r -p "Choose 1-4 [3]: " choice < /dev/tty || true
  case "${choice:-3}" in
    1) PRIVILEGE=basic ;;
    2) PRIVILEGE=deploy ;;
    3) PRIVILEGE=sudo ;;
    4) PRIVILEGE=sudo-nopass ;;
    *) echo "❌ Invalid choice '$choice'"; exit 1 ;;
  esac
fi

case "$PRIVILEGE" in
  basic|deploy|sudo|sudo-nopass) ;;
  *) echo "❌ PRIVILEGE must be one of: basic deploy sudo sudo-nopass"; exit 1 ;;
esac

# Extra supplementary groups, comma separated. NOT named GROUPS: that is a
# read-only special array in bash and assigning to it fails outright.
EXTRA_GROUPS="${EXTRA_GROUPS:-}"
if [ -z "$EXTRA_GROUPS" ] && [ "$TTY_OK" -eq 1 ]; then
  read -r -p "Extra groups, comma separated (blank for none): " EXTRA_GROUPS < /dev/tty || true
fi

# ---- 4. Login shell ---------------------------------------------------------
SHELL_SETUP="${SHELL_SETUP:-}"          # bash | zsh
if [ -z "$SHELL_SETUP" ]; then
  if [ "$TTY_OK" -eq 1 ]; then
    cat <<'MENU'

Login shell:
  1) bash — leave the default shell alone
  2) zsh  — install zsh + Oh My Zsh + autosuggestions/syntax-highlighting
            for this user (runs zsh-config.sh; needs network + apt)
MENU
    read -r -p "Choose 1-2 [1]: " choice < /dev/tty || true
    case "${choice:-1}" in
      1) SHELL_SETUP=bash ;;
      2) SHELL_SETUP=zsh ;;
      *) echo "❌ Invalid choice '$choice'"; exit 1 ;;
    esac
  else
    SHELL_SETUP=bash
  fi
fi
case "$SHELL_SETUP" in
  bash|zsh) ;;
  *) echo "❌ SHELL_SETUP must be 'bash' or 'zsh'"; exit 1 ;;
esac

# ---- 5. SSH key — how YOU log in to this server ------------------------------
# The public key of the machine you connect FROM goes in authorized_keys here.
# Its private half never leaves your laptop; that is the whole point of a key
# pair, and it is why 'paste' is the default rather than 'generate'.
SSH_MODE="${SSH_MODE:-}"          # paste | generate | none
SSH_PUBKEY="${SSH_PUBKEY:-}"      # one key, or several separated by newlines
if [ -z "$SSH_MODE" ]; then
  if [ "$TTY_OK" -eq 1 ]; then
    cat <<'MENU'

SSH login access — the key you will connect to this server WITH:
  1) paste    — paste the public key(s) from your local machine (recommended)
  2) generate — create a new key pair here; you then copy the PRIVATE half
                to your laptop and delete it from the server
  3) none     — no key login (password only)
MENU
    read -r -p "Choose 1-3 [1]: " choice < /dev/tty || true
    case "${choice:-1}" in
      1) SSH_MODE=paste ;;
      2) SSH_MODE=generate ;;
      3) SSH_MODE=none ;;
      *) echo "❌ Invalid choice '$choice'"; exit 1 ;;
    esac
  else
    SSH_MODE=none
  fi
fi

if [ "$SSH_MODE" = "paste" ] && [ -z "$SSH_PUBKEY" ]; then
  need_tty SSH_PUBKEY
  echo
  echo "On your local machine run:  cat ~/.ssh/id_ed25519.pub"
  echo "Paste one key per line; press Enter on an empty line when done."
  while :; do
    read -r -p "  public key: " line < /dev/tty || true
    [ -n "$line" ] || break
    # Reject anything that is not a key before it reaches authorized_keys: a
    # malformed line there is silently ignored by sshd, which looks like a
    # server problem rather than a typo.
    if ! printf '%s' "$line" | grep -Eq '^(ssh-(rsa|ed25519|dss)|ecdsa-sha2-\S+|sk-ssh-\S+|sk-ecdsa-\S+) [A-Za-z0-9+/=]+'; then
      echo "  ✗ that does not look like a public key (expected 'ssh-ed25519 AAAA…')"
      continue
    fi
    SSH_PUBKEY="${SSH_PUBKEY:+$SSH_PUBKEY$'\n'}$line"
  done
  [ -n "$SSH_PUBKEY" ] || { echo "❌ No public key given."; exit 1; }
fi

# =============================================================================
# Apply
# =============================================================================
echo
echo "→ user=$TARGET_USER privilege=$PRIVILEGE shell=$SHELL_SETUP"
echo "  ssh=$SSH_MODE groups=${EXTRA_GROUPS:-<none>}"

# 6. Create the account. useradd -m (not adduser) because adduser is
#    interactive and would stall behind its own prompts.
if [ "$USER_EXISTS" -eq 0 ]; then
  useradd -m -s /bin/bash "$TARGET_USER"
  echo "→ Created $TARGET_USER"
fi
HOME_DIR="$(getent passwd "$TARGET_USER" | cut -d: -f6)"

# 7. Set the password.
#
#    chpasswd reads user:password on stdin, so nothing sensitive lands in the
#    process list or the shell history — but it goes through PAM, and Ubuntu's
#    pam_pwquality rejects weak passwords *even when root sets them*
#    ("BAD PASSWORD: … fails the dictionary check"). That is a non-zero exit,
#    which under `set -e` used to abort the script with the account already
#    created and nothing else configured. Handle it instead of dying on it.
PASSWORD_SET=0

hash_password() {   # print a SHA-512 crypt hash of stdin
  if command -v openssl >/dev/null 2>&1; then
    openssl passwd -6 -stdin
  elif command -v mkpasswd >/dev/null 2>&1; then
    mkpasswd -m sha-512 -s
  elif command -v python3 >/dev/null 2>&1; then
    # crypt was removed in Python 3.13; harmless if this branch is unreachable.
    python3 -c 'import crypt,sys; print(crypt.crypt(sys.stdin.readline().rstrip("\n"), crypt.mksalt(crypt.METHOD_SHA512)))'
  else
    return 1
  fi
}

try_chpasswd() {    # returns non-zero and prints PAM's reason on rejection
  local out
  if out="$(printf '%s:%s' "$TARGET_USER" "$1" | chpasswd 2>&1)"; then
    return 0
  fi
  printf '%s\n' "$out" | sed 's/^/  /'
  return 1
}

apply_password() {
  while :; do
    if try_chpasswd "$USER_PASSWORD"; then
      echo "→ Password set"
      PASSWORD_SET=1
      return 0
    fi

    if [ "${ALLOW_WEAK_PASSWORD:-0}" = "1" ]; then
      # chpasswd -e takes an already-hashed password, which skips PAM entirely.
      local hash
      if hash="$(printf '%s\n' "$USER_PASSWORD" | hash_password)" \
         && printf '%s:%s' "$TARGET_USER" "$hash" | chpasswd -e; then
        echo "→ Password set (ALLOW_WEAK_PASSWORD=1 — quality check bypassed)"
        PASSWORD_SET=1
        return 0
      fi
      echo "⚠️  Could not hash the password (no openssl/mkpasswd/python3)."
      return 1
    fi

    if [ "$TTY_OK" -eq 1 ]; then
      echo "  ↑ rejected by the system password policy. Pick a stronger one,"
      echo "    or re-run with ALLOW_WEAK_PASSWORD=1 to bypass the check."
      USER_PASSWORD=""
      ask_secret USER_PASSWORD "Password for $TARGET_USER"
      continue
    fi

    echo "⚠️  Password rejected by the policy and no terminal to retry on."
    echo "    Re-run with a stronger USER_PASSWORD, or ALLOW_WEAK_PASSWORD=1."
    return 1
  done
}

if [ -n "$USER_PASSWORD" ]; then
  # `|| true`: a password that cannot be set is worth a warning, not an abort —
  # the rest of the setup (groups, sudoers, SSH key) still needs to happen, and
  # key-based login works fine against an account with no usable password.
  apply_password || true
fi

# 8. Groups. usermod -aG appends; without -a it would REPLACE every
#    supplementary group the user already has.
if [ -n "$EXTRA_GROUPS" ]; then
  for grp in ${EXTRA_GROUPS//,/ }; do
    if getent group "$grp" >/dev/null; then
      usermod -aG "$grp" "$TARGET_USER"
      echo "→ Added to group '$grp'"
    else
      echo "⚠️  Group '$grp' does not exist; skipped."
    fi
  done
fi

# 9. Privileges.
USER_SLUG="$(printf '%s' "$TARGET_USER" | tr -c 'A-Za-z0-9_-' '-')"
SUDOERS_FILE="/etc/sudoers.d/90-$USER_SLUG"
DEPLOY_SUDOERS_FILE="/etc/sudoers.d/90-deploy-$USER_SLUG"   # written by deploy-sudoers.sh
install_sudoers() {   # install_sudoers "rule line"
  local tmp; tmp="$(mktemp)"
  printf '# Managed by create-user.sh — do not edit by hand.\n%s\n' "$1" > "$tmp"
  # Validate before installing: a syntax error in sudoers.d locks out sudo.
  if ! visudo -cf "$tmp"; then
    rm -f "$tmp"; echo "❌ Invalid sudoers rule; nothing installed."; exit 1
  fi
  install -m 0440 -o root -g root "$tmp" "$SUDOERS_FILE"
  rm -f "$tmp"
  echo "→ Installed $SUDOERS_FILE"
}

case "$PRIVILEGE" in
  basic)
    rm -f "$SUDOERS_FILE" "$DEPLOY_SUDOERS_FILE"
    # Reconfiguring an existing account down to 'basic' has to actually revoke
    # sudo, otherwise group membership silently keeps granting it.
    if id -nG "$TARGET_USER" | tr ' ' '\n' | grep -qx sudo; then
      gpasswd -d "$TARGET_USER" sudo >/dev/null
      echo "→ Removed from group 'sudo'"
    fi
    ;;
  sudo)
    usermod -aG sudo "$TARGET_USER"
    rm -f "$SUDOERS_FILE" "$DEPLOY_SUDOERS_FILE"   # the 'sudo' group grants it, with a password
    echo "→ Added to group 'sudo' (password required)"
    ;;
  sudo-nopass)
    usermod -aG sudo "$TARGET_USER"
    rm -f "$DEPLOY_SUDOERS_FILE"
    install_sudoers "$TARGET_USER ALL=(ALL) NOPASSWD:ALL"
    ;;
  deploy)
    rm -f "$SUDOERS_FILE"
    # Delegate to the sibling script so the deploy rule set lives in one place.
    if DS="$(fetch_sibling user-management/deploy-sudoers.sh)"; then
      TARGET_USER="$TARGET_USER" bash "$DS"
    else
      echo "⚠️  Could not find or fetch deploy-sudoers.sh — no deploy rules"
      echo "    installed. Run it separately once the machine has network:"
      echo "    curl -fsSL $REPO_RAW_URL/user-management/deploy-sudoers.sh | TARGET_USER=$TARGET_USER sudo -E bash"
    fi
    ;;
esac

# 10. Login shell.
if [ "$SHELL_SETUP" = "zsh" ]; then
  if ZS="$(fetch_sibling zsh-config.sh)"; then
    # zsh-config.sh installs into $HOME and runs chsh for $USER. Run it as root
    # with both pointed at the new account: the apt install and chsh need root,
    # and a fresh user may have neither sudo rights nor a password to escalate
    # with. Overriding USER for a child process is fine — what breaks things is
    # assigning to USER inside a script and then using it as your own variable.
    HOME="$HOME_DIR" USER="$TARGET_USER" bash "$ZS"
    # It ran as root, so everything it wrote under the home is root-owned.
    chown -R "$TARGET_USER:$TARGET_USER" "$HOME_DIR"
    echo "→ zsh + Oh My Zsh installed for $TARGET_USER"
  else
    echo "⚠️  Could not find or fetch zsh-config.sh — shell left as bash."
    echo "    Run it separately:  sudo -u $TARGET_USER -H bash zsh-config.sh"
  fi
fi

# 11. SSH key — public keys go into authorized_keys.
if [ "$SSH_MODE" != "none" ]; then
  SSH_DIR="$HOME_DIR/.ssh"
  AUTH_KEYS="$SSH_DIR/authorized_keys"
  # sshd ignores these files unless the permissions are exactly this tight.
  install -d -m 0700 -o "$TARGET_USER" -g "$TARGET_USER" "$SSH_DIR"
  touch "$AUTH_KEYS"
  chown "$TARGET_USER:$TARGET_USER" "$AUTH_KEYS"
  chmod 0600 "$AUTH_KEYS"

  if [ "$SSH_MODE" = "generate" ]; then
    KEY_PATH="$SSH_DIR/id_ed25519"
    if [ -f "$KEY_PATH" ]; then
      echo "✓ Login key already exists at $KEY_PATH — reusing it."
    else
      # -N '' = no passphrase, so the key works unattended in a deploy pipeline.
      sudo -u "$TARGET_USER" ssh-keygen -t ed25519 -N '' \
        -C "$TARGET_USER@$(hostname)" -f "$KEY_PATH" >/dev/null
      echo "→ Generated $KEY_PATH"
    fi
    SSH_PUBKEY="$(cat "$KEY_PATH.pub")"
  fi

  # SSH_PUBKEY may hold several keys, one per line — authorise each exactly
  # once so a re-run does not pile up duplicates.
  while IFS= read -r key; do
    [ -n "$key" ] || continue
    if grep -qxF "$key" "$AUTH_KEYS"; then
      echo "✓ Already authorised: ${key:0:24}…"
    else
      printf '%s\n' "$key" >> "$AUTH_KEYS"
      echo "→ Authorised ${key:0:24}… in $AUTH_KEYS"
    fi
  done <<< "$SSH_PUBKEY"
fi

# ---- Summary ----------------------------------------------------------------
echo
echo "==============================================================="
id "$TARGET_USER"
echo "home:  $HOME_DIR"
echo "shell: $(getent passwd "$TARGET_USER" | cut -d: -f7)"
if [ "$PASSWORD_SET" -eq 1 ]; then
  echo "pass:  set"
elif [ -n "$USER_PASSWORD" ]; then
  echo "pass:  NOT SET — policy rejected it; SSH key login still works,"
  echo "       but 'sudo' with a password and console login will not."
else
  echo "pass:  unchanged"
fi
for f in "$SUDOERS_FILE" "$DEPLOY_SUDOERS_FILE"; do
  [ -f "$f" ] && echo "sudo:  $f"
done || true
echo "==============================================================="

# A key pair has two halves and they travel in opposite directions, so print
# both with the direction spelled out — copying the wrong one is the usual way
# this goes wrong.
if [ "${SSH_MODE:-none}" != "none" ] && [ -n "${SSH_PUBKEY:-}" ]; then
  echo
  echo "PUBLIC key — not secret, safe to paste anywhere:"
  echo "---------------------------------------------------------------"
  printf '%s\n' "$SSH_PUBKEY"
  echo "---------------------------------------------------------------"
  echo "Already installed in $HOME_DIR/.ssh/authorized_keys on THIS server."
  if [ "$SSH_MODE" = "generate" ]; then
    echo "This is the key pair belonging to $TARGET_USER, so paste the line"
    echo "above wherever this account needs to reach:"
    echo "  GitHub, all repos:  https://github.com/settings/keys"
    echo "  GitHub, one repo:   repo → Settings → Deploy keys (tick 'Allow write')"
    echo "  Another server:     append it to ~/.ssh/authorized_keys there"
    echo "Then test the git access as the user:"
    echo "  sudo -u $TARGET_USER -H ssh -T git@github.com"
  fi
  echo "Read it again later with:"
  echo "  sudo cat $HOME_DIR/.ssh/id_ed25519.pub"
fi

if [ "${SSH_MODE:-none}" = "generate" ]; then
  echo
  echo "PRIVATE key: $HOME_DIR/.ssh/id_ed25519 — secret."
  echo "To log IN to this server as $TARGET_USER, the machine you connect FROM"
  echo "needs this half (the public one above is not enough)."
  if confirm "Print the private key now?"; then
    echo "---------------------------------------------------------------"
    cat "$HOME_DIR/.ssh/id_ed25519"
    echo "---------------------------------------------------------------"
    echo "Save it on your laptop as ~/.ssh/${TARGET_USER}_ed25519, then:"
    echo "  chmod 600 ~/.ssh/${TARGET_USER}_ed25519"
  fi
  echo
  echo "Connect with:  ssh -i ~/.ssh/${TARGET_USER}_ed25519 $TARGET_USER@<server-ip>"
  echo "Once it works, delete the private key here:"
  echo "  sudo rm $HOME_DIR/.ssh/id_ed25519"
fi

echo "✅ Done. Log out and back in for new group membership to take effect."
