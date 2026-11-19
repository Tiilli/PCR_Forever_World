#!/usr/bin/env bash
# Re-pin mods whose .pw.toml references the wrong Modrinth file (wrong loader/MC variant)
# by pointing them at the exact CDN file matching the jar in the Prism instance.
set -uo pipefail
MODS_DIR="/home/tilli/.local/share/PrismLauncher/instances/PCR's Forever World/minecraft/mods"

echo "== Building project-id -> exact file map (hash lookup on all instance jars)"
declare -A PID_URL PID_VID
for jar in "$MODS_DIR"/*.jar; do
  h=$(sha1sum "$jar" | cut -d' ' -f1)
  resp=$(curl -sf "https://api.modrinth.com/v2/version_file/$h?algorithm=sha1") \
    || { echo "  (not on Modrinth: $(basename "$jar"))"; continue; }
  pid=$(jq -r '.project_id' <<<"$resp")
  PID_VID[$pid]=$(jq -r '.id' <<<"$resp")
  # Select the file matching OUR hash, never the "primary" file of the version
  PID_URL[$pid]=$(jq -r --arg h "$h" '.files[] | select(.hashes.sha1==$h) | .url' <<<"$resp")
  sleep 0.25
done

echo "== Repairing mismatched entries"
repaired=0; failed=0
for f in mods/*.pw.toml; do
  pinned=$(sed -n 's/^filename = "\(.*\)"$/\1/p' "$f")
  [ -e "$MODS_DIR/$pinned" ] && continue        # entry is already correct
  pid=$(awk '/^\[update\.modrinth\]/{inblk=1} inblk && /^mod-id *=/ {gsub(/"/,""); print $3; exit}' "$f")
  url=${PID_URL[$pid]:-}
  if [ -z "$pid" ] || [ -z "$url" ]; then
    echo "FAIL (no map entry): $(basename "$f") pid='${pid:-?}'"; failed=$((failed+1)); continue
  fi
  name=$(basename "$f" .pw.toml)
  echo "Re-pinning $name -> ${url##*/}"
  rm "$f"
  if packwiz -y url add --force --meta-folder mods "$name" "$url"; then
    # Restore Modrinth metadata so "packwiz update" keeps working on this entry
    newfile=$(grep -rlF "$url" mods --include='*.pw.toml' | head -1)
    printf '\n[update]\n[update.modrinth]\nmod-id = "%s"\nversion = "%s"\n' \
      "$pid" "${PID_VID[$pid]}" >> "$newfile"
    repaired=$((repaired+1))
  else
    echo "FAILED: $url"; failed=$((failed+1))
  fi
  sleep 0.25
done
echo "== Done: $repaired repaired, $failed failed"
