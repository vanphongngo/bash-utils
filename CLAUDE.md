# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this repo is

A collection of standalone utility shell scripts. There is no build system, no
package manager, no test suite, and no application code — each script is an
independent artifact that is read, copied, or piped into `bash` on a target
machine.

```
readme.md                        # index of every script + copy-paste run commands
setup-server/                    # Ubuntu server provisioning suite
setup-server/user-management/    # user accounts: create, delete, sudoers, playbook
```

## Two kinds of file — know which one you are editing

This distinction drives almost every decision here.

**1. Installers** — meant to be executed, usually via `curl … | bash`:
`zsh-config.sh`, `docker-config.sh`, `install-nginx.sh`, `zsh-config-revert.sh`,
and everything in `user-management/`.

**2. Cheat sheets** — reference collections of commands that are *not* meant to
run top-to-bottom: `file-managment.sh`.

A reference collection of commands is a **document**, not a script. There used
to be an `ubuntu-user-management.sh` whose every line had to stay commented out
(it mixed account creation with `userdel -r` and `find / -exec rm`) so that
piping it into bash would not destroy a machine. It is now
`user-management/playbook.md`. Write new references as Markdown; do not
resurrect the commented-out-shell-script pattern.

## Conventions for installers

- Start with `#!/usr/bin/env bash` and `set -euo pipefail`.
- **Assume no TTY and no interaction.** These run through `curl | bash`, so
  stdin is the script itself. That rules out `vim`/`$EDITOR`, bare `chsh`
  (it prompts for a password — use `sudo chsh -s <shell> "$USER"`), and any
  installer that drops into a shell (`RUNZSH=no CHSH=no` for Oh My Zsh).
- Use `DEBIAN_FRONTEND=noninteractive` with `apt-get` (not `apt`, which warns
  about its unstable CLI in scripts) and always pass `-y`.
- **Be idempotent.** Re-running must not fail: guard `git clone` and file
  creation with existence checks, use `ln -sfn` rather than `ln -s`, and
  `gpg --dearmor --yes`.
- `set -e` turns informational commands into aborts. `systemctl status` exits
  non-zero for a stopped unit, so append `|| true` where the exit code is not
  a real failure.
- Create a config file *before* symlinking or reloading a service that reads it.
- Parameterise anything site-specific (domains, usernames, paths) as
  `"${VAR:-default}"` environment variables rather than hardcoding. An empty
  value should skip the optional step, not run it with a blank argument.
- Keep the numbered step comments (`# 1. …`, `# 2. …`) — they are the
  documentation for these files.
- End with a `✅`-prefixed line stating any manual follow-up (re-login for a
  group or shell change to apply).

## Shell variable names to avoid

Never use `USER` or `GROUPS` as your own variables:

- `USER` is the login name from the environment; overwriting it breaks later
  commands in the same script.
- `GROUPS` is a **read-only special array in bash** — `GROUPS="sudo,docker"`
  fails outright and leaves the value unusable.

Use `TARGET_USER` / `EXTRA_GROUPS` instead. This was a real bug in this repo.
Setting them in the *environment of a child process*
(`HOME=… USER=… bash zsh-config.sh`) is fine and is how `create-user.sh` runs
the other scripts against a different account — the rule is about assigning to
them and then using them as your own variables.

## Verifying changes

There is no test suite and the scripts target Ubuntu, so they cannot be
executed on a macOS dev machine. Before finishing:

```bash
bash -n setup-server/*.sh setup-server/user-management/*.sh   # always run this
shellcheck setup-server/*.sh setup-server/user-management/*.sh  # if available
```

Beyond that, review by reading: trace the script as if stdin were closed and
the machine were freshly provisioned, then re-trace it as a second run to
confirm idempotency.

## When adding a script

Put it in a topic directory (`setup-server/`, `setup-server/user-management/`,
or a new one), follow the installer conventions above, and add a row to the
matching table in `readme.md` plus a `curl` example if it is pipe-safe. A new
reference collection goes in as Markdown, not as a shell script.

Scripts that call each other (`create-user.sh` → `deploy-sudoers.sh`,
`zsh-config.sh`) must keep working when the caller arrived through a pipe: with
no file on disk, `BASH_SOURCE` is unset — which `set -u` makes fatal — so guard
it with `${BASH_SOURCE[0]:-}` and fall back to fetching the callee from
`REPO_RAW_URL`.
