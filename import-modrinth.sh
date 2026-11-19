#!/usr/bin/env bash
# Import jars from the Prism instance into the packwiz pack via Modrinth lookup.
# Usage: ./import-modrinth.sh [one-jar]
set -uo pipefail
MODS_DIR="/home/tilli/.local/share/PrismLauncher/instances/PCR's Forever World/minecraft/mods"

if [ $# -ge 1 ]; then
  jars=("$MODS_DIR/$1")
else
  jars=("$MODS_DIR"/*.jar)
fi

found=0; missing=0
for jar in "${jars[@]}"; do
  h=$(sha1sum "$jar" | cut -d' ' -f1)
  resp=$(curl -sf "https://api.modrinth.com/v2/version_file/$h?algorithm=sha1") \
    || { echo "NOT FOUND ON MODRINTH: $(basename "$jar")"; missing=$((missing+1)); continue; }

  pid=$(jq -r '.project_id // empty' <<<"$resp")
  vnum=$(jq -r '.version_number // empty' <<<"$resp")

  # Resolve the project slug from its ID (second API call)
  slug=$(curl -sf "https://api.modrinth.com/v2/project/$pid" | jq -r '.slug // empty')
  proj=${slug:-$pid}   # fall back to the project ID if no slug

  echo "== $(basename "$jar") -> $proj $vnum"
  packwiz -y modrinth add "https://modrinth.com/mod/$proj/version/$vnum" \
    || { echo "ADD FAILED: $(basename "$jar") -- API response:"; echo "$resp" | jq .; }
  found=$((found+1))
done
echo "Summary: $found imported, $missing not found"
