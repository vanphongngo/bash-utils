# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this repo is

A collection of standalone utility shell scripts. There is no build system, no
package manager, no test suite, and no application code — each script is an
independent artifact that is read, copied, or piped into `bash` on a target
machine.

```
readme.md              # index of every script + copy-paste run commands
setup-server/          # Ubuntu server provisioning suite
```

## Two kinds of file — know which one you are editing

This distinction drives almost every decision here.

**1. Installers** — meant to be executed, usually via `curl … | bash`:
`zsh-config.sh`, `docker-config.sh`, `install-nginx.sh`, `zsh-config-revert.sh`.

**2. Cheat sheets** — reference collections of commands that are *not* meant to
run top-to-bottom: `ubuntu-user-management.sh`, `file-managment.sh`.
`ubuntu-user-management.sh` mixes account creation with `userdel -r` and
`find / -exec rm`, so it `exit 0`s immediately and keeps every command
commented out. **Never "fix" it by uncommenting the commands to make it
runnable** — that would make piping it into bash destroy a machine.

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

## Verifying changes

There is no test suite and the scripts target Ubuntu, so they cannot be
executed on a macOS dev machine. Before finishing:

```bash
bash -n setup-server/*.sh        # syntax check — always run this
shellcheck setup-server/*.sh     # if available (not installed by default)
```

Beyond that, review by reading: trace the script as if stdin were closed and
the machine were freshly provisioned, then re-trace it as a second run to
confirm idempotency.

## When adding a script

Put it in a topic directory (`setup-server/`, or a new one), follow the
installer conventions above, and add a row to the table in `readme.md` plus a
`curl` example if it is pipe-safe. Mark it clearly in both the header comment
and the readme if it is a cheat sheet rather than an installer.
