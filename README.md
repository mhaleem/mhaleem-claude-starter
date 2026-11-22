# Claude Code Starter Kit

A language-agnostic starter kit for projects built with [Claude Code](https://docs.claude.com/en/docs/claude-code). It gives every new project the same rules, guardrails, subagents and delivery workflow: plan → implement → independent review → human merge.

Install it into a new or existing project with one command, pick your stack (examples for **Python** and **Node** below), and start working.

## What's inside

```
.
├── install.sh                   # Copies the kit into a project: ./install.sh <project-path>
├── CLAUDE.md                    # Rules for contributing to this repo (not copied)
└── src/                         # The kit: everything here is copied into your project
    ├── CLAUDE.md                # Project rules Claude reads every session
    └── .claude/
        ├── guardrails.json      # Your config: secret/protected files, blocked commands, branches, format/test commands
        ├── settings.json        # Deny rules + wires the hooks to Claude Code (rarely needs editing)
        ├── hooks/
        │   ├── guard.sh         # Runs before every tool call, enforces guardrails.json
        │   └── checks.sh        # Runs the format and test commands from guardrails.json
        ├── agents/
        │   ├── implementer.md   # Writes code + tests, opens the PR
        │   └── code-reviewer.md # Read-only reviewer, posts findings on the PR
        └── commands/
            └── ship.md          # /ship: plan → implement → review loop → hand over
```

Paths in the rest of this README (`CLAUDE.md`, `.claude/...`) refer to the copies in your project.

- **`CLAUDE.md`** is guidance: workflow, code style, git and security rules. Claude follows it, but nothing forces it to.
- **Hooks** are the hard rules. They are shell commands that Claude Code itself runs automatically at fixed points (before a tool runs, after a file is edited, when a subagent finishes). They run every time, whatever the prompt says. A hook that exits with code `2` blocks the action, and its message goes back to Claude.
- **`guardrails.json`** is the one file you edit to change those rules. It's this kit's own config, not a built-in Claude Code file. The hook scripts read it on every call, so changes apply immediately, with no restart and no `settings.json` edits.

## Prerequisites

- [Claude Code](https://docs.claude.com/en/docs/claude-code)
- `git` and the [`gh` CLI](https://cli.github.com/), logged in with `gh auth login`
- `jq`, used by the hooks to read JSON (`brew install jq` / `apt install jq`)
- Your stack's tools, e.g. [uv](https://docs.astral.sh/uv/) for Python or Node + npm

## Getting started

1. **Install the kit into your project.**

   ```bash
   git clone https://github.com/mhaleem/mhaleem-claude-starter.git
   ./mhaleem-claude-starter/install.sh path/to/your-project
   ```

   The script copies `src/CLAUDE.md` and `src/.claude/` into the project and makes the hooks executable. Files that already exist are skipped and listed, so your own `CLAUDE.md` or `settings.json` is never overwritten by accident. Pass `--force` to overwrite them:

   ```bash
   ./mhaleem-claude-starter/install.sh --force path/to/your-project
   ```

   If you skipped an existing file, merge the kit's version into it by hand. For example, add the `hooks` and `permissions` blocks to your own `.claude/settings.json`.

   To update the kit in a project later, run the script again with `--force`. Back up your edited `guardrails.json` and `CLAUDE.md` first, because those get overwritten too.

2. **Set up your stack** if the project is new (see [Python](#python) or [Node](#node) below).

3. **Set the format and test commands** in `.claude/guardrails.json` under `commands`. Leave a command empty to skip that check.

4. **Fill in `CLAUDE.md`.** Replace the `<...>` placeholders under **Project**, and keep only your stack's column in the **Commands** table.

5. **Add a `.env.example`** that lists the environment variable names your app needs, without values. Claude can't read `.env`, so this is how it learns which variables exist.

6. **Start Claude Code** in the project folder. Run `/hooks` once to confirm the hooks are loaded, then run `/ship <task>`.

## Stack examples

### Python

```bash
git init
uv init --package
uv add --dev pytest ruff
```

`.claude/guardrails.json`:

```json
"commands": {
  "format": "uv run ruff format . && uv run ruff check --fix .",
  "test": "uv run pytest -q"
}
```

Add at least one test before running subagents. pytest fails when it finds no tests, and the test check would then block every hand-over.

### Node

```bash
git init
npm init -y
npm install -D prettier eslint vitest
npm pkg set scripts.test="vitest run" scripts.lint="eslint ." scripts.format="prettier --write ."
```

`.claude/guardrails.json`:

```json
"commands": {
  "format": "npm run format && npm run lint",
  "test": "npm test"
}
```

Use the same idea for pnpm, yarn or bun, or for other languages such as Go (`gofmt -w . && go vet ./...`, `go test ./...`) and Rust (`cargo fmt && cargo clippy`, `cargo test`).

## Guardrails

Everything below is set in `.claude/guardrails.json`:

```json
{
  "secret_files": [".env", ".env.*", "*.pem", "*.key", "id_rsa*", "credentials.json"],
  "allowed_files": [".env.example"],
  "protected_files": ["uv.lock", "package-lock.json", "pnpm-lock.yaml", "yarn.lock",
                      ".claude/settings.json", ".claude/guardrails.json", ".claude/hooks/*"],
  "blocked_commands": ["rm -rf", "rm -fr", "git reset --hard", "git clean -f", "git branch -D"],
  "protected_branches": ["main", "master"],
  "block_force_push": true,
  "commands": { "format": "", "test": "" }
}
```

| Key | What it does |
|-----|--------------|
| `secret_files` | Glob patterns Claude can't read, edit, search or mention in a shell command (e.g. `cat .env`) |
| `allowed_files` | Exceptions to the two file lists, e.g. `.env.example` |
| `protected_files` | Glob patterns Claude can read but not edit. Lockfiles and the guardrail files are included so Claude can't loosen its own rules |
| `blocked_commands` | Plain-text fragments; any shell command that contains one is blocked |
| `protected_branches` | Blocks `git push` while you're on one of these branches, pushes that target one (`origin main`, `HEAD:main`) and `--all` / `--mirror` |
| `block_force_push` | Blocks `-f`, `--force`, `--force-with-lease` and `+refspec` pushes |
| `commands.format` | Runs after every file edit. If it fails, its output goes back to Claude to fix |
| `commands.test` | Runs when a subagent finishes. If tests fail, the subagent has to fix them before handing over |

**Patterns:** file patterns are shell globs, matched against both the project-relative path (`.claude/hooks/*`) and the file name (`*.key`). Command patterns are plain text, and repeated spaces are collapsed before matching.

**Changing the rules:** edit `guardrails.json` yourself, in your editor. It's protected, so Claude will refuse to change it and will ask you instead.

**Fails closed:** if `jq` or `guardrails.json` is missing, or the JSON is invalid, `guard.sh` blocks every tool call and says why. The format and test checks only warn in that case, so a broken config can't trap a subagent in a loop.

**Limits:** these guardrails catch mistakes; they are not a security boundary. A determined command can get around text matching (for example `rm -r -f`, or `grep -r KEY .` reading `.env` indirectly). Keep real secrets out of the repo, and review the PRs.

## The workflow

The kit separates the agent that writes code from the agent that approves it.

| Role | Who | Does |
|------|-----|------|
| Orchestrator | Main Claude session | Agrees the plan with you, delegates, reports results |
| `implementer` | Subagent | Creates a branch, writes code and tests, runs tests and lint, commits, opens the PR |
| `code-reviewer` | Subagent (read-only) | Reviews the PR diff, runs tests and lint, posts findings ranked High / Medium / Low |
| You | Human | Final review and merge |

### `/ship <task>`

1. **Plan.** Claude proposes an approach, the files to change and the tests, then waits for your approval.
2. **Implement.** `implementer` builds it on a `feat/...` or `fix/...` branch and opens a PR.
3. **Review loop**, at most 3 rounds:
   - `code-reviewer` reviews and posts a verdict: **Approve**, **Approve with minor changes** or **Changes required**.
   - On **Changes required** (any open High or Medium finding), `implementer` fixes the findings and pushes.
   - The next review re-checks every earlier finding and reviews the new commits.
   - If round 3 still ends in **Changes required**, Claude stops and reports the open findings to you.
4. **Hand over.** You get the PR link, the number of rounds, the fixes made in each round, any remaining Low findings and the test and lint status. Claude never merges.

```
/ship Add a /health endpoint that returns the app version
```

You can also call the agents directly, for example: *"Use the code-reviewer agent to review PR #12."*

## Customizing

- **Rules:** edit `.claude/guardrails.json`.
- **Project guidance:** edit `CLAUDE.md`. Keep it short; long instruction files are followed less reliably.
- **Agents:** edit `.claude/agents/*.md`. The frontmatter sets each agent's tools, model and effort. The reviewer has no `Edit`/`Write` tools, which keeps it read-only.
- **Commands:** add a Markdown file to `.claude/commands/`. The file name becomes the slash command, and `$ARGUMENTS` holds whatever you type after it.
- **Hook wiring:** `.claude/settings.json` connects the scripts to Claude Code's hook events. You only need to touch it to add a new kind of hook. Put personal, machine-specific overrides in `.claude/settings.local.json` and keep that file out of git.

## Principles

- Plan before code, and get approval before non-trivial work.
- Make small, reviewable changes, with tests for every change.
- Verify before saying something is done. Tests and lint have to pass for real.
- The author never approves their own code.
- Keep secrets out of reach. `.env` is off-limits and config comes from environment variables.
- A human makes the final call and does the merge.

## Contributing

The kit lives in `src/`, and `install.sh` copies it into projects. The root `CLAUDE.md` describes how the pieces fit together, which files have to stay in sync, and how to test hook changes. Read it before opening a PR.
