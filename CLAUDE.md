# CLAUDE.md

Base rules for this project. Keep this file short and current. Hard rules (secrets, dangerous commands, protected files and branches, format and test checks) are enforced by hooks configured in `.claude/guardrails.json`; this file is guidance.

## Project

- **What it is:** <one or two sentences: purpose, users, main features>
- **Stack:** <language, package manager, framework>, e.g. `Python 3.14, uv, FastAPI` or `Node 22, npm, TypeScript, Express`
- **Structure:**
  - `src/` application code
  - `tests/` tests, mirroring `src/`
  - `.claude/` settings, guardrails, hooks, subagents and commands

## Commands

Keep the column for this project's stack and delete the other. The format and test commands must match `commands` in `.claude/guardrails.json`.

| Task | Python (uv) | Node (npm) |
|------|-------------|------------|
| Install | `uv sync` | `npm install` |
| Add dependency | `uv add <pkg>` | `npm install <pkg>` |
| Add dev dependency | `uv add --dev <pkg>` | `npm install -D <pkg>` |
| Test | `uv run pytest -q` | `npm test` |
| Format | `uv run ruff format .` | `npx prettier --write .` |
| Lint | `uv run ruff check --fix .` | `npx eslint --fix .` |
| Run | `uv run <entrypoint>` | `npm start` |

Never edit lockfiles (`uv.lock`, `package-lock.json`, `pnpm-lock.yaml`, ...) by hand; use the package manager.

## Workflow

1. **Plan first.** For any non-trivial task, propose a short plan (approach, files to change, tests) and wait for approval before writing code.
2. **Small steps.** Implement in small, reviewable increments. One concern per commit.
3. **Tests with every change.** New behavior needs a test; bug fixes need a test that fails before the fix.
4. **Verify before saying done.** Run tests and lint, and report the result honestly. Never claim something works without running it.
5. **Ask when unclear.** If requirements are ambiguous, ask instead of guessing.

## Subagents

Work is split so the agent that writes code is never the one that approves it.

- **Main session (orchestrator):** plans with the user, delegates to subagents, reports results. Does not skip the review step.
- **`implementer`:** writes code and tests on a feature branch, runs tests and lint, commits, opens the PR.
- **`code-reviewer`:** read-only. Reviews the PR diff (`git diff main...HEAD`) and posts findings ranked by severity. Never edits code.

Standard flow:
1. Orchestrator agrees the plan with the user.
2. `implementer` builds it on a branch and opens a PR.
3. **Review loop:**
   - `code-reviewer` reviews and posts findings.
   - If any high or medium finding is open, `implementer` fixes them and pushes.
   - `code-reviewer` reviews again, checking every previous finding and the new changes.
   - Repeat until the verdict has no open high or medium findings.
   - Maximum 3 review rounds. If issues remain after round 3, stop and report to the user with the open findings instead of continuing.
4. The user does the final review and merges.

## Code style

- Small, focused functions with clear names. Prefer readability over cleverness.
- No dead code, no commented-out code, no unused imports.
- Handle errors explicitly; never swallow them silently. Log useful context.
- Document public functions only when the name isn't enough.
- Follow existing patterns in the codebase before introducing new ones.
- **Python:** type hints on all functions; pydantic models for structured data and settings; no bare `except`.
- **Node / TypeScript:** TypeScript in strict mode, no `any`; validate external data with a schema library such as zod; no unhandled promise rejections.

## Git

- Never commit to or push `main` directly. Use branches: `feat/...`, `fix/...`, `chore/...`.
- Commit messages: short imperative summary, e.g. `Add monthly revenue endpoint`.
- Open PRs with `gh pr create` and a description of what changed, why, and how it was tested.
- Never force-push.

## Security and secrets

- Never read, print or edit `.env`. Use `.env.example` to see which variables exist.
- Read configuration from environment variables through a validated settings module (pydantic-settings, zod, ...), never hardcode keys.
- Never put secrets, tokens or personal data in code, tests, logs, commits or PR comments.
- Validate all external input.

## AI / LLM code (when relevant)

- Keep prompts in versioned files or constants, not scattered inline.
- Use structured outputs with schemas and validate every model response.
- Add timeouts, retries with backoff, and clear error handling around model calls.
- Log token usage and latency; never log secrets or full personal data.
- Every AI feature needs a small eval set and a test that runs against it.

## Don'ts

- Don't add dependencies without saying why.
- Don't change unrelated files.
- Don't disable tests or lint rules to make something pass.
- Don't edit lockfiles, `.env`, or files in `.claude/` unless asked.
