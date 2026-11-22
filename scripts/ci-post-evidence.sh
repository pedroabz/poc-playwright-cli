#!/usr/bin/env bash
# Post the agent's verification report + screenshots to GitHub.
#   ci-post-evidence.sh pr-create <branch> <title>   open a PR from <branch> with the evidence as body
#   ci-post-evidence.sh comment <issue|pr> <number>  comment the evidence on an issue or PR
# Needs GH_TOKEN. Screenshots are attached inline when gh supports --attach (2.99+);
# otherwise the body links to the workflow run, where they are uploaded as an artifact.
set -euo pipefail
cd "$(dirname "$0")/.."

mode="$1"
run_url="${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY:-}/actions/runs/${GITHUB_RUN_ID:-}"

body="$(mktemp)"
if [[ -f artifacts/report.md ]]; then
  cat artifacts/report.md > "$body"
else
  echo "⚠️ The agent did not write \`artifacts/report.md\`. Treat this change as **not verified**." > "$body"
fi
printf '\n\n---\nRun: %s (screenshots and logs are in the `browser-evidence` artifact)\n' "$run_url" >> "$body"

attach=()
if gh pr create --help 2>/dev/null | grep -q -- '--attach'; then
  shopt -s nullglob
  for png in artifacts/*.png; do attach+=(--attach "$png"); done
fi

case "$mode" in
  pr-create)
    gh pr create --draft --head "$2" --title "$3" --body-file "$body" "${attach[@]}"
    ;;
  comment)
    gh "$2" comment "$3" --body-file "$body" "${attach[@]}"
    ;;
  *)
    echo "unknown mode: $mode" >&2
    exit 2
    ;;
esac
