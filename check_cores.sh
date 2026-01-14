#!/usr/bin/env bash
# check_cores.sh: Verify all four core "alive" messages appear in an FVP log and report counts.
# Usage: ./check_cores.sh /path/to/fvp_log [timeout_seconds]
set -euo pipefail

LOG=${1:-}
TIMEOUT=${2:-20}

if [[ -z "$LOG" ]]; then
  LOG=$(ls -t /tmp/fvp_log.* 2>/dev/null | head -n 1 || true)
fi

if [[ -z "$LOG" || ! -f "$LOG" ]]; then
  echo "Usage: $0 /path/to/fvp_log [timeout_seconds]"
  exit 1
fi

cores=("core 00" "core 01" "core 10" "core 11")

for c in "${cores[@]}"; do
  start_time=$SECONDS
  count=0
  while (( SECONDS - start_time < TIMEOUT )); do
    count=$(grep -c "$c" "$LOG" || true)
    if (( count > 0 )); then
      break
    fi
    sleep 0.5
  done

  if (( count == 0 )); then
    echo "MISSING: $c"
    exit 2
  fi

  echo "saw $c $count times"
done

echo "All cores seen in output."
