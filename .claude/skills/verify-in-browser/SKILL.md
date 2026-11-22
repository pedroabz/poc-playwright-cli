---
name: verify-in-browser
description: Verify a frontend change in a real browser with playwright-cli before reporting it done. Use after ANY change under web/, or when asked to check, test or validate that the app works.
allowed-tools: Bash(npm run app:up) Bash(npm run app:down) Bash(npx playwright-cli:*) Bash(mkdir -p artifacts)
---

# Verify in browser

You changed the frontend. Prove it works by using it the way a user would, in a real browser.
"It compiles" is not verification. Never report a frontend task as done without completing these steps.

For the full command reference, see the `playwright-cli` skill. In this repo always call the
pinned local binary as `npx playwright-cli` (not a global `playwright-cli`).

## 1. Decide what to check

Before opening the browser, write down 2–5 concrete checks derived from the task, for example:
- "heading reads 'Hello Playwright'"
- "clicking 'Save' adds the note to the list"
- "no console errors on load"

Include at least one check that would **fail if your change were missing or broken**.
Always include "no console errors".

## 2. Make sure the app is running

```bash
npm run app:up
```

Idempotent: starts the dev server in the background if needed and waits until
http://localhost:5173 responds. If it fails, read `.app-up.log`, fix the problem, and retry.
A failure here is a failed verification, not something to skip.

## 3. Open the app and check

```bash
npx playwright-cli open http://localhost:5173
```

If a browser is already open, use `npx playwright-cli goto http://localhost:5173` instead.
The output shows the page title, a `Console: N errors` line when there are errors, and a link
to a snapshot file. Then, per check:

- **Text / element present:** `npx playwright-cli find "<text>"` (or read the snapshot file)
- **Interactions:** `npx playwright-cli snapshot` to get refs, then `click <ref>`, `fill <ref> "<text>"`, …
  and snapshot again to see the result
- **Console:** `npx playwright-cli console error` must show no errors
- **Network (once there is an API):** `npx playwright-cli requests`, then look for 4xx/5xx

Prefer refs from snapshots. If a ref is stale after the page changed, take a new snapshot.

## 4. Capture evidence

```bash
mkdir -p artifacts
npx playwright-cli screenshot --filename=artifacts/<short-task-slug>.png
```

Take one screenshot per meaningful state (e.g. before/after an action). Use descriptive names.

## 5. Clean up

```bash
npx playwright-cli close
```

Leave the dev server running for the user locally. In CI, also run `npm run app:down`.

## 6. Report

End your answer with a short verification report:

```
### Browser verification
| Check | Result |
|---|---|
| Heading reads "Hello Playwright" | ✅ |
| No console errors | ✅ |

Evidence: artifacts/hello-playwright.png
```

**In CI** (env `CI=true`) also write that report, plus a one-paragraph summary of what you changed,
to `artifacts/report.md`. The pipeline posts it on the PR and attaches every `artifacts/*.png`;
to place a screenshot inline, reference it by that exact path: `![Heading after change](artifacts/hello-playwright.png)`.

If any check fails, fix the code and run the verification again. If you can't make it pass,
say so plainly, with the failing check and what you saw. Never claim success you didn't observe.
