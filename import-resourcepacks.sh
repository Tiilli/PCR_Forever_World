#!/usr/bin/env bash
# Import resource packs from the instance via Modrinth hash lookup, pinning the exact file.
set -uo pipefail
SRC="/home/tilli/.local/share/PrismLauncher/instances/PCR's Forever World/minecraft/resourcepacks"

for f in "$SRC"/*.zip; do
  base=$(basename "$f")
  case "$base" in *.duplicate*) continue ;; esac
  h=$(sha1sum "$f" | cut -d' ' -f1)
  resp=$(curl -sf "https://api.modrinth.com/v2/version_file/$h?algorithm=sha1") \
    || { echo "NOT FOUND: $base"; continue; }
  url=$(jq -r --arg h "$h" '.files[] | select(.hashes.sha1==$h) | .url' <<<"$resp")
  [ -z "$url" ] && { echo "NO MATCHING FILE: $base"; continue; }
  name=${base%.zip}
  packwiz -y url add --force --meta-folder resourcepacks "$name" "$url"
  sleep 0.25
done
