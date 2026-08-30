# Node.js (nvm) + Claude Code playbook

Reference for installing nvm, Node.js and the Claude Code CLI on Ubuntu by
hand. Copy the block you need — this is documentation, not a script.

Everything here installs into `$HOME`. **Run it as the user who will use it,
never with `sudo`** — an nvm or Claude Code installed as root is invisible to
your normal account, and files it creates in `~` end up root-owned.

Only the "Prerequisites" section needs root, and on a stock Ubuntu it is
usually already satisfied.

> There is no installer script for this on purpose. Piping one into `bash`
> leaves sudo with no reliable way to prompt for a password, which is what
> produced `sudo: I'm sorry <user>. I'm afraid I can't do that` — sudo's
> "insult" for a failed authentication, printed without ever showing a prompt.
> Run these steps in an interactive shell, where sudo can ask properly.

## Prerequisites

Check first; install only what is missing.

```bash
command -v curl git
```

If either is absent, from an account with working sudo:

```bash
sudo apt-get update
sudo apt-get install -y curl git ca-certificates
```

If sudo rejects you, see [Appendix: when sudo refuses](#appendix-when-sudo-refuses).

## 1. Install nvm

Check the current release tag at <https://github.com/nvm-sh/nvm/releases> and
substitute it below.

```bash
NVM_VERSION="v0.40.3"
curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/$NVM_VERSION/install.sh" | bash
```

The installer clones into `~/.nvm` and appends its snippet to the shell profile
it detects — usually `~/.bashrc`. Re-running it updates an existing checkout
rather than failing, and it will not duplicate the snippet.

Load nvm into the shell you are sitting in, without logging out:

```bash
export NVM_DIR="$HOME/.nvm"
. "$NVM_DIR/nvm.sh"
nvm --version
```

If you use zsh, the installer may not have touched `~/.zshrc`. Check, and add
it if the grep comes back empty:

```bash
grep -n NVM_DIR ~/.zshrc
```

```bash
cat >> ~/.zshrc <<'EOF'

# nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
EOF
```

`\.` is deliberate — it is `.` (source) with alias expansion suppressed, and it
is what the nvm installer itself writes.

## 2. Install Node.js

```bash
nvm install --lts          # newest LTS
nvm install 22             # a major line
nvm install 22.11.0        # an exact version
```

Make one of them the default for every new shell, then confirm:

```bash
nvm alias default --lts
nvm use default
node --version
npm --version
which node                 # should be under ~/.nvm/versions/node/...
```

Useful afterwards:

```bash
nvm ls                     # installed versions + aliases
nvm ls-remote --lts        # what is available
nvm uninstall 20           # remove a version
```

### If `nvm: command not found`

nvm is a **shell function**, not a binary — `which nvm` finds nothing by
design. It only exists in a shell that has sourced `nvm.sh`. Either open a new
login shell, or source it again:

```bash
export NVM_DIR="$HOME/.nvm"; . "$NVM_DIR/nvm.sh"
```

It also cannot work inside a script run with `set -u`: `nvm.sh` reads unset
variables, so relax that around the source (`set +u` … `set -u`).

## 3. Install Claude Code

Two ways. The native installer needs no Node at all and updates itself, so
prefer it; use npm if you already manage tooling that way.

**Native (recommended):**

```bash
curl -fsSL https://claude.ai/install.sh | bash
```

**npm (needs Node 18+ from step 2):**

```bash
npm install -g @anthropic-ai/claude-code
```

Do **not** put `sudo` in front of the npm command. With nvm, the global prefix
is inside `~/.nvm` and is already yours; `sudo npm` would install against
root's PATH and create root-owned files in your home directory.

### Put it on your PATH

The native installer places the binary in `~/.local/bin`, which a fresh Ubuntu
account only adds to the PATH at login **if the directory already existed**.
Check:

```bash
command -v claude
```

Empty? Add it, then reload:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc   # and/or ~/.zshrc
export PATH="$HOME/.local/bin:$PATH"
```

### Verify and log in

```bash
claude --version
claude doctor              # installation health check
```

Then, from a project directory:

```bash
cd ~/your-project
claude
```

The first run prints a URL for a one-time browser login. On a headless server,
open that URL on your laptop and paste the resulting code back into the
terminal. Credentials are stored under `~/.claude/`, so this is per-user — a
second account on the same machine logs in separately.

### Updating and removing

```bash
claude update                              # native install
npm update -g @anthropic-ai/claude-code    # npm install

rm -rf ~/.local/bin/claude ~/.claude       # remove native install + config
npm uninstall -g @anthropic-ai/claude-code
```

## Appendix: when sudo refuses

`sudo: I'm sorry <user>. I'm afraid I can't do that` is one of sudo's insults
(enabled by `Defaults insults`). It means **authentication failed** — a wrong
password, or an account with no usable password at all. It does *not* mean the
command was forbidden; that reads
`<user> is not allowed to execute ... as root`.

Diagnose from an account whose sudo works:

```bash
sudo passwd -S someuser    # P = usable password, L = locked, NP = none set
sudo -l -U someuser        # what that user may actually run
```

Fixes, from a working sudo account or as root:

```bash
sudo passwd someuser                 # give the account a real password
sudo usermod -aG sudo someuser       # grant full sudo (log out and back in)
```

For a deploy account that should install packages without a password, see
`user-management/deploy-sudoers.sh`, or install the handful of prerequisites
once as root and let the user do everything else in `$HOME` — which is all this
playbook needs.

Also check whether you have a terminal at all. sudo cannot prompt when there is
no TTY, which is why `ssh host 'curl ... | bash'` and CI jobs fail here:

```bash
tty                        # "not a tty" means sudo has nowhere to ask
```
