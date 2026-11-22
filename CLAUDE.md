# POC: agents that verify frontend work in a real browser

See `PLAN.md` for the epic and the feature roadmap.

## Layout

- `web/`: React + Vite + TypeScript frontend, served at http://localhost:5173 (fixed port)
- `scripts/app-up.sh` / `scripts/app-down.sh`: start/stop the app in the background (`npm run app:up` / `npm run app:down`)
- `.claude/skills/verify-in-browser/`: our verification workflow
- `.claude/skills/playwright-cli/`: upstream playwright-cli command reference (installed via `npx playwright-cli install --skills`)

## Rules

- **After any change under `web/`, use the `verify-in-browser` skill before saying you're done.**
  A frontend task isn't done until it has been seen working in the browser, with a screenshot in `artifacts/`.
- Use the pinned local `npx playwright-cli`, never a global install.
- Add `data-testid` attributes to elements that verification depends on.
