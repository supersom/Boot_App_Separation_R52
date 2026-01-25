#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' PIPE

# Picks the newest /tmp/fvp_log* when no argument is given (or uses the provided file).
# Writes counts to <log>.counts if available, otherwise to a unique /tmp/<log>.counts.XXXXXX.
# Verifies the four expected messages, exiting 2 if any are missing.
# If all are present, prints “All expected high-volume lines are present.” first, then shows the counts file path and the full counts list.

if [[ $# -ge 1 ]]; then
  log_file="$1"
else
  log_file=$(ls -t /tmp/fvp_log* 2>/dev/null | head -n1 || true)
  if [[ -z "$log_file" ]]; then
    echo "No fvp_log* file found in /tmp and no log specified." >&2
    exit 1
  fi
fi

if [[ ! -f "$log_file" ]]; then
  echo "Log not found: $log_file" >&2
  exit 1
fi

# Decide counts output file name
counts_file="${log_file}.counts"
if [[ -e "$counts_file" ]]; then
  counts_file=$(mktemp "/tmp/$(basename "$log_file").counts.XXXXXX")
fi

# Build counts after stripping optional HH:MM:SS: prefix
awk '{ line=$0; sub(/^[0-9]{2}:[0-9]{2}:[0-9]{2}:[[:space:]]*/, "", line); cnt[line]++ } END { for (l in cnt) printf "%d\t%s\n", cnt[l], l }' "$log_file" \
  | sort -nr > "$counts_file"

declare -A expected
expected["C00: Entered FIQ handler for SPI (35) triggered by DualTimer1"]=0
expected["C01: Entered FIQ handler for SGI (1) <- PPI (27) <- VirtualTimer"]=0
expected["C00: Entered FIQ handler for SGI (1) <- PPI (27) <- VirtualTimer"]=0
expected["C01: Entered FIQ handler for SPI (34) triggered by DualTimer0"]=0

missing=0
while IFS=$'\t' read -r count msg; do
  # Handle blank line (msg can be empty)
  if [[ -v expected[$msg] ]]; then
    expected[$msg]=$count
  fi
done < "$counts_file"

for msg in "${!expected[@]}"; do
  if [[ ${expected[$msg]} -eq 0 ]]; then
    echo "MISSING: $msg" >&2
    missing=1
  fi
done

if [[ $missing -ne 0 ]]; then
  exit 2
fi

echo "All expected high-volume lines are present."
echo "Counts written to: $counts_file"
echo "All lines (timestamp stripped):"
cat "$counts_file"
