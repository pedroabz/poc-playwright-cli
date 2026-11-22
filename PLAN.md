# POC: Agents that verify frontend work in a real browser

> Status: F0 and F1 implemented. Open questions answered: all "yes" (Node API, GitHub Actions, screenshots + PR comment report, test creds in repo, hybrid specs in F7).

## Goal

When an agent (Claude Code or a skill) implements a frontend task, it should **open the app in a real browser, log in, click around, and confirm the change works** before it reports "done". This must work:

1. **Locally**, on a developer machine
2. **In an agentic pipeline** (GitHub Actions here; Azure DevOps at work, and we only write down the differences)

To make the check meaningful, the app needs real friction: a **login**, a **JWT-protected API**, and **role-based access (RBAC)**. That way the agent can't just load a static page; it has to authenticate and use features.

## Guiding principles

- **Small increments.** Each feature is a vertical slice that can be demoed and verified on its own.
- **Browser verification early.** Playwright CLI comes right after hello world, not at the end.
- **Every feature has an "agent verification" step.** It says what the agent should do in the browser to prove the feature works. This is the real thing we're testing.
- **The app domain doesn't matter.** We use a tiny "Notes" app (list, create, delete) because it gives RBAC natural actions.

---

## Proposed stack (default plan)

| Piece | Choice | Why |
|---|---|---|
| Frontend | React + Vite + TypeScript | As requested |
| API | Node + Fastify (or Express) + TypeScript | Same language as the frontend, one `npm install`, fast to scaffold |
| Auth | API issues its own JWT (HS256) from seeded users | No external IdP needed for a POC |
| Data | In-memory array, or a JSON file | Persistence isn't the point |
| Browser automation | `@playwright/cli` (`playwright-cli`) | Simple shell commands with token-efficient snapshots, well suited to agents |
| Pipeline | GitHub Actions + `anthropics/claude-code-action` | Closest public stand-in for an Azure DevOps agentic pipeline |
| Repo layout | Monorepo: `/web`, `/api`, `.claude/skills/` | One checkout for the agent |

### Seeded users / roles

| User | Password | Role | Can |
|---|---|---|---|
| `viewer@poc.local` | `viewer123` | viewer | read notes |
| `editor@poc.local` | `editor123` | editor | read + create notes |
| `admin@poc.local` | `admin123` | admin | read + create + delete notes, see `/admin` page |

---

## Epic

**EPIC: Browser-verified frontend development by AI agents**

*As a team using AI agents for frontend work, we want agents to check their changes in a real browser against an authenticated, role-protected app, locally and in CI, so that "done" means "seen working", not just "it compiles".*

**Epic done when:**
- An agent given a frontend task (e.g. "add a delete button for admins") implements it, starts the app, logs in as the relevant roles with `playwright-cli`, confirms both the allowed and the denied behaviour, and attaches screenshots as evidence.
- The same flow runs in GitHub Actions, triggered by an issue or PR comment.
- We have a short write-up of what changes for Azure DevOps.

---

## Features (in order)

### F0: Hello world frontend ✅
**Scope:** `npm create vite@latest web -- --template react-ts`. Page shows "Hello POC". Add `npm run dev` on a fixed port (e.g. `5173`, `strictPort: true`).

**Acceptance:**
- `npm run dev` serves the page at `http://localhost:5173`
- Page has a stable element to assert on, e.g. `<h1 data-testid="title">Hello POC</h1>`

**Agent verification:** none yet (that's F1).

---

### F1: Playwright CLI locally + a "verify in browser" skill ✅ (accepted: both acceptance tests passed via fresh subagents)
**Scope:**
- Install: `npm i -D @playwright/cli` (or global) plus browser install
- Add a project skill `.claude/skills/verify-in-browser/SKILL.md` that tells the agent to:
  1. Make sure the dev server is running (start it in the background if not, then wait for the port)
  2. `playwright-cli open http://localhost:5173`
  3. `playwright-cli snapshot`, then check that the expected text or elements are present
  4. `playwright-cli screenshot` and save to `./artifacts/`
  5. Close the browser, then report pass or fail **with evidence**
- Add a line to `CLAUDE.md`: *"After any change under `/web`, run the verify-in-browser skill before saying you're done."*

**Acceptance:**
- Ask Claude: *"Change the title to 'Hello Playwright'"*. It edits, opens the browser, confirms the new text, and saves a screenshot.
- Deliberately break something (e.g. a runtime error in the component). The agent notices it in the browser and doesn't report success.

**Agent verification:** the skill itself.

> 💡 Spike inside F1: check headed vs headless behaviour and how `playwright-cli` sessions/profiles work, since we need that for login state in F6.

---

### F2: Same thing in a pipeline (GitHub Actions)
**Scope:**
- Workflow `.github/workflows/agent.yml`, triggered by `@claude` on an issue or PR comment (`anthropics/claude-code-action`)
- Steps: checkout → setup Node → `npm ci` → install Playwright browsers + OS deps (`npx playwright install --with-deps chromium`) → run the agent
- Allow the agent to run `playwright-cli` and `npm` (allowed tools / permissions config)
- Upload `./artifacts/**` (screenshots) with `actions/upload-artifact`
- Secret: `ANTHROPIC_API_KEY`

**Acceptance:**
- Comment *"@claude change the title to 'Hello CI'"* on an issue. A PR is opened, and the run's artifacts include a screenshot showing "Hello CI".
- Headless mode works without a display (no xvfb hacks needed, or if they are, write that down).

**Alternative for F2 (simpler first step):** run Claude Code headless directly (`claude -p "..." --allowedTools ...`) in a plain workflow step, before bringing in the action. This is closer to how you'd do it in Azure DevOps, where the GitHub action isn't available.

---

### F3: API skeleton (no auth yet)
**Scope:** `/api` with Fastify on `:3000`. Endpoints `GET /health` and `GET /notes` (in-memory). Vite dev proxy `/api → :3000`. Frontend lists notes.

**Acceptance:** notes from the API render on the page. A single root command (`npm run dev` with `concurrently`) starts both.

**Agent verification:** skill updated to start **both** servers. The agent confirms that the notes list renders (not just the title).

---

### F4: JWT authentication on the API
**Scope:**
- `POST /auth/login` checks the seeded users and returns `{ token }` (JWT with `sub`, `role`, `exp`)
- Auth hook on `/notes*`: missing or invalid token returns `401`
- Secret from env (`JWT_SECRET`), with a default for local dev only

**Acceptance:** `curl` without a token returns 401; with a token it returns 200. Expired token returns 401.

**Agent verification:** the agent may use `curl` here, since this is API-only. The browser comes back in F5.

---

### F5: Login in the frontend
**Scope:**
- `/login` page (email + password), stores the token (memory + `sessionStorage` is fine for the POC)
- Protected routes redirect to `/login`. Logout button.
- Fetch wrapper adds `Authorization: Bearer …` and redirects to login on 401

**Acceptance:** you can't see notes without logging in. Log in, see notes, log out, get sent back to login.

**Agent verification:** the skill now includes a **login step**:
`open /login → fill email → fill password → click "Sign in" → snapshot → assert notes visible`.
Credentials come from a documented test-users file (`.claude/skills/verify-in-browser/test-users.md`), never hardcoded in the prompt.

---

### F6: RBAC (API + UI)
**Scope:**
- API: `POST /notes` needs editor or admin, `DELETE /notes/:id` needs admin, otherwise `403`
- UI: hide or disable actions the role can't perform. `/admin` page is admin-only.
- Optional: role badge in the header ("Logged in as editor")

**Acceptance:**
- viewer: no "New note" button; a direct `POST` returns 403
- editor: can create, no delete button
- admin: can create and delete, and can open `/admin`

**Agent verification:** the skill supports **"verify as role X"**. It logs in per role and checks both the allowed **and** the denied behaviour. Use `playwright-cli` saved state or separate sessions per role so it doesn't have to log in again for every check.

---

### F7: Dogfood: agent builds a feature end-to-end
**Scope:** give the agent a real feature ticket, with no hints about how to verify, e.g.:
> *"Admins should be able to edit a note's title. Editors and viewers must not."*

**Acceptance:**
- Locally and in GitHub Actions, the agent implements API + UI, then on its own verifies as admin (works) and as editor/viewer (blocked), with screenshots attached to the PR
- We note where it struggled (flaky waits, selectors, server startup, token usage) and feed that back into the skill

This is the **demo for work**.

---

### F8 (stretch): Azure DevOps notes
**Scope:** no implementation, just a short `AZURE_DEVOPS.md` covering:
- Running `claude -p` headless in an Azure Pipelines YAML job (no `claude-code-action`)
- Installing Playwright deps on Microsoft-hosted agents vs self-hosted agents
- Publishing screenshots with `PublishPipelineArtifact`
- Triggering: PR comment, work item, or manual run. How the agent pushes a branch and opens a PR (Azure DevOps CLI / REST)
- Secrets via variable groups / Key Vault

Optional: actually try it on a free Azure DevOps org.

---

## Alternatives considered

### Browser tool for the agent
| Option | Pros | Cons |
|---|---|---|
| **playwright-cli** *(chosen)* | Plain shell commands, compact snapshots, works the same in CI, easy to allow-list | Newer tool, smaller community |
| Playwright MCP | Rich, well-known | MCP setup in CI is more involved; heavier on context/tokens |
| Agent writes `@playwright/test` specs and runs them | Leaves behind reusable regression tests | Slower loop, the agent "verifies" through code it wrote itself, and it's not exploratory |
| **Hybrid** | CLI for exploratory checks during development, then the agent turns the key flows into `@playwright/test` specs in CI | More scope. A good **F9** if the POC works |

### API
- **Node/Fastify** *(chosen)*: fastest for a POC, one language.
- **.NET minimal API**: closer to a typical Azure shop. Worth it if work uses .NET, since the JWT/RBAC code would carry over.
- **Mock API (MSW / json-server + middleware)**: fastest, but RBAC is fake and the API isn't really exercised.

### Auth
- **Self-issued JWT** *(chosen)*: simple, no infra.
- **Keycloak / mock OIDC in Docker**: realistic redirect-based login (closer to Entra ID at work), but more setup and slower CI. Could be a later feature: *"swap login to OIDC and see if the agent still copes."*

### Pipeline trigger
- **`claude-code-action` on `@claude` comments** *(chosen for GitHub)*
- **Headless `claude -p` in a plain job**: more portable to Azure DevOps. We may do this first in F2.

---

## Open questions (to validate)

1. Is **Node** OK for the API, or should it be **.NET** to match work?
2. "GitHub desktop": I assumed you mean **GitHub Actions** for the pipeline. Correct?
3. Should verification evidence be **screenshots only**, or also a short markdown report posted as a PR comment?
4. Is it fine for test credentials to live in the repo (POC-only users)?
5. Should F7 also produce `@playwright/test` specs (hybrid), or keep it to exploratory checks only?
