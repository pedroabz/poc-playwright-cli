#!/usr/bin/env bash
# Stop the app started by app-up.sh.
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ -f .app-up.pid ]]; then
  pid="$(cat .app-up.pid)"
  # npm spawns vite as a child; kill the whole group.
  pkill -P "$pid" 2>/dev/null || true
  kill "$pid" 2>/dev/null || true
  rm -f .app-up.pid
  echo "app stopped"
else
  echo "no app started by app-up.sh"
fi
