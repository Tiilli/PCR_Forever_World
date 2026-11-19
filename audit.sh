#!/usr/bin/env bash
# List pinned files that do not exist (under that exact name) in the instance mods folder.
set -uo pipefail
MODS_DIR="/home/tilli/.local/share/PrismLauncher/instances/PCR's Forever World/minecraft/mods"
bad=0
for f in mods/*.pw.toml; do
  pinned=$(sed -n 's/^filename = "\(.*\)"$/\1/p' "$f")
  if [ ! -e "$MODS_DIR/$pinned" ]; then
    echo "MISMATCH: $(basename "$f") pins '$pinned'"
    bad=$((bad+1))
  fi
done
echo "---"; echo "$bad mismatched pinned file(s)"
