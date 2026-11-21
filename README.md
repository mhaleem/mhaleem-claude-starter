# Claude Code Python Starter

A starter kit for Python projects built with [Claude Code](https://docs.claude.com/en/docs/claude-code). It contains project rules, guardrail hooks, two subagents and a `/ship` command, so every new project starts with the same plan → implement → review workflow and the same safety settings.

Copy it into a new or existing Python project, fill in the project details in `CLAUDE.md`, and start working.

## What's inside

```
.
├── CLAUDE.md                    # Project rules Claude reads every session
└── .claude/
    ├── settings.json            # Permissions and hooks (the hard rules)
    ├── agents/
    │   ├── implementer.md       # Writes code + tests, opens the PR
    │   └── code-reviewer.md     # Read-only reviewer, posts findings on the PR
    └── commands/
        └── ship.md              # /ship: plan → implement → review loop → hand over
```

`CLAUDE.md` holds the guidance: workflow, code style, git rules and AI/LLM practices. `.claude/settings.json` holds the rules that must not depend on the model remembering them, so they are enforced by permissions and hooks.

## Stack assumptions

- Python 3.14 managed with [uv](https://docs.astral.sh/uv/)
- [ruff](https://docs.astral.sh/ruff/) for formatting and linting
- [pytest](https://docs.pytest.org/) for tests
- pydantic / pydantic-settings for data models and configuration
- Git and GitHub, with the [`gh` CLI](https://cli.github.com/) for PRs

If your project uses different tools, update the commands in `CLAUDE.md`, the agents and the hooks to match.

## Prerequisites

- [Claude Code](https://docs.claude.com/en/docs/claude-code)
- `uv`
- `git` and `gh` (logged in with `gh auth login`)
- `jq`, which the guardrail hooks use to parse tool input

## Getting started

1. **Copy the kit into your project.**

   ```bash
   cp -R path/to/mhaleem-claude-starter/{CLAUDE.md,.claude} your-project/
   cd your-project
   ```

2. **Set up the Python project** if it doesn't exist yet:

   ```bash
   git init
   uv init --package
   uv add --dev pytest ruff
   ```

3. **Add at least one test.** The `SubagentStop` hook runs `uv run pytest -q` and blocks the hand-over if it fails. pytest exits with an error when it collects no tests, so a project without tests will block every subagent.

4. **Fill in `CLAUDE.md`.** Replace the `<...>` placeholders under **Project** (purpose, stack, package name, entrypoint).

5. **Add a `.env.example`** listing the environment variable names your app needs, without values. Claude is blocked from reading `.env`, so this is how it learns which variables exist.

6. **Start Claude Code** in the project folder and run `/ship <task>`.

## The workflow

The kit separates the agent that writes code from the agent that approves it.

| Role | Who | Does |
|------|-----|------|
| Orchestrator | Main Claude session | Agrees the plan with you, delegates, reports results |
| `implementer` | Subagent | Creates a branch, writes code and tests, runs tests and lint, commits, opens the PR |
| `code-reviewer` | Subagent (read-only) | Reviews the PR diff, runs tests and lint, posts findings ranked High / Medium / Low |
| You | Human | Final review and merge |

### `/ship <task>`

The `/ship` command runs the whole flow:

1. **Plan.** Claude proposes an approach, the files to change and the tests, then waits for your approval.
2. **Implement.** `implementer` builds it on a `feat/...` or `fix/...` branch and opens a PR.
3. **Review loop**, at most 3 rounds:
   - `code-reviewer` reviews the PR and posts a verdict: **Approve**, **Approve with minor changes** or **Changes required**.
   - On **Changes required** (any open High or Medium finding), `implementer` fixes the findings and pushes.
   - The next review re-checks every earlier finding and reviews the new commits.
   - If round 3 still ends in **Changes required**, Claude stops and reports the open findings to you.
4. **Hand over.** You get the PR link, the number of rounds, the fixes made in each round, any remaining Low findings and the test and lint status. Claude never merges.

Example:

```
/ship Add a /health endpoint that returns the app version
```

You can also call the agents directly, for example: *"Use the code-reviewer agent to review PR #12."*

## Guardrails

These live in `.claude/settings.json` and run every time, whatever the prompt says.

### Permissions

| Rule | Effect |
|------|--------|
| `deny: Read/Edit(.env, .env.*)` | Claude cannot read or change secrets files |

### Hooks

| Hook | Trigger | What it does |
|------|---------|--------------|
| `PreToolUse` | Bash | Blocks `rm -rf`, `git push --force` and pushes to `main`/`master` |
| `PreToolUse` | Edit / Write | Blocks edits to `.env` and `uv.lock` |
| `PostToolUse` | Edit / Write | Runs `ruff format` and `ruff check --fix` after every file change |
| `SubagentStop` | Any subagent finishing | Runs `pytest -q`; if tests fail, the subagent has to fix them before handing over |

A hook that exits with code `2` blocks the action, and its message goes back to Claude so it can change course.

## Customizing

- **Project rules:** edit `CLAUDE.md`. Keep it short; long instruction files are followed less reliably.
- **Agent behavior:** edit `.claude/agents/*.md`. The frontmatter sets each agent's tools, model and effort. The reviewer has no `Edit`/`Write` tools, which keeps it read-only.
- **More commands:** add a Markdown file to `.claude/commands/`. The file name becomes the slash command, and `$ARGUMENTS` holds whatever you type after it.
- **More guardrails:** add hooks or permission rules to `.claude/settings.json`. Put personal, machine-specific overrides in `.claude/settings.local.json` and keep that file out of git.

## Principles

- Plan before code, and get approval before non-trivial work.
- Make small, reviewable changes, with tests for every change.
- Verify before saying something is done. Tests and lint have to pass for real.
- The author never approves their own code.
- Keep secrets out of reach. `.env` is off-limits and config comes from environment variables.
- A human makes the final call and does the merge.
