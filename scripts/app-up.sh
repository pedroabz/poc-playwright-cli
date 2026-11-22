#!/usr/bin/env bash
# Start the app in the background (if not already running) and wait until it responds.
# Safe to call repeatedly. Used by agents before browser verification.
set -euo pipefail
cd "$(dirname "$0")/.."

URL="${APP_URL:-http://localhost:5173}"
TIMEOUT="${APP_UP_TIMEOUT:-60}"

if curl -sf -o /dev/null "$URL"; then
  echo "app already up at $URL"
  exit 0
fi

nohup npm run dev > .app-up.log 2>&1 &
echo $! > .app-up.pid

for ((i = 0; i < TIMEOUT; i++)); do
  if curl -sf -o /dev/null "$URL"; then
    echo "app up at $URL (log: .app-up.log)"
    exit 0
  fi
  sleep 1
done

echo "app did not come up at $URL within ${TIMEOUT}s; last log lines:" >&2
tail -20 .app-up.log >&2
exit 1
