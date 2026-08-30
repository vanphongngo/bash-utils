#!/usr/bin/env bash
# file-managment.sh — Reference snippets for file permissions and disk usage.
# This is a CHEAT SHEET, not a runnable installer: read it and copy the line
# you need. Running it top-to-bottom only touches ./data in the current dir.

set -euo pipefail

TARGET="${1:-./data}"

# Sticky + read/write for every uid on a directory tree. Used to make a
# bind-mounted volume writable by whatever uid runs inside the container.
# Fine for dev/test; in production grant the specific uid instead — it is safer:
#   sudo chown -R 1000:1000 "$TARGET"
sudo chmod -R 1777 "$TARGET"

# Disk usage of everything in the current directory, largest last
du -sh -- * | sort -h

# Other handy checks (uncomment as needed):
# df -h                     # free space per filesystem
# du -xh --max-depth=1 / | sort -h   # biggest top-level dirs, one filesystem
