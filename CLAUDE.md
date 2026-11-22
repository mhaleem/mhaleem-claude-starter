# CLAUDE.md

Guidance for working on **this repository**: an open-source starter kit of best practices for using Claude Code in real projects. The kit itself lives in `src/` and is meant to be copied into other projects. Nothing in `src/` is application code.

## What the kit gives a project

- **Guidance** (`CLAUDE.md`): workflow, code style, git, security and AI-code rules that Claude follows.
- **Hard guardrails** (hooks plus `guardrails.json`): secret files, protected files, blocked commands, protected branches and force pushes are blocked. Format runs after every edit and tests run when a subagent finishes.
- **Deny rules** (`settings.json`): `.env` is denied at the permission level as well, so there's a second layer behind the hook.
- **A two-agent flow**: `implementer` writes the code, `code-reviewer` reviews it read-only, and the `/ship` command loops between them until the review is clean. A human merges.

## Repo layout

- `src/`: the kit. Everything in it is copied into target projects.
- `install.sh`: `./install.sh [--force] <project-path>` copies every file under `src/` into the project. Existing files are skipped unless you pass `--force`, and the hooks are made executable. It copies whatever is in `src/`, so new kit files need no script change. Don't put anything in `src/` that shouldn't ship.
- `README.md`: user-facing docs. `CLAUDE.md` (this file): contributor guidance. Neither one is copied.

## Layout of `src/`

```
src/
├── CLAUDE.md                   # Template project rules, copied into the target project (has <...> placeholders)
└── .claude/
    ├── settings.json           # Permission deny rules + wiring of the 3 hooks to Claude Code events
    ├── guardrails.json         # The one config file users edit per project
    ├── hooks/
    │   ├── guard.sh            # PreToolUse: enforces guardrails.json, exit 2 blocks the call
    │   └── checks.sh           # Runs commands.format (PostToolUse) or commands.test (SubagentStop)
    ├── agents/
    │   ├── implementer.md      # Branch, code + tests, test/lint, commit, open PR, fix review findings
    │   └── code-reviewer.md    # Read-only: reviews the PR diff, posts ranked findings and a verdict
    └── commands/
        └── ship.md             # /ship <task>: plan → implement → review loop (max 3 rounds) → hand over
```

### The 3 hooks (`src/.claude/settings.json`)

| Event | Matcher | Script | Purpose |
|-------|---------|--------|---------|
| `PreToolUse` | `Bash\|Read\|Grep\|Glob\|Edit\|Write\|MultiEdit\|NotebookEdit` | `guard.sh` | Block secrets, protected-file edits, blocked commands, pushes to protected branches, force pushes |
| `PostToolUse` | `Edit\|Write\|MultiEdit` | `checks.sh format` | Run the project's formatter/linter and feed failures back to Claude |
| `SubagentStop` | (all) | `checks.sh test` | Run tests before a subagent may hand over |

### `guardrails.json` keys

`secret_files`, `allowed_files`, `protected_files`, `blocked_commands`, `protected_branches`, `block_force_push`, `commands.format`, `commands.test`. The full table is in `README.md` under **Guardrails**.

## Invariants: keep these in sync

A change to one of these files usually means a change to another.

- **Tool names:** the `PreToolUse` matcher in `settings.json` and the `case` on `tool_name` at the end of `guard.sh` must cover the same tools.
- **Config keys:** a key added, renamed or removed in `guardrails.json` has to change in `guard.sh`/`checks.sh` and in the README **Guardrails** table.
- **Commands:** the default `commands` in `guardrails.json` have to match the Python column of the **Commands** table in `src/CLAUDE.md`.
- **Review flow:** the loop rules (verdict names, High/Medium/Low severity, max 3 rounds, human merges) are written down in four places: `src/CLAUDE.md` **Subagents**, `code-reviewer.md` **Output**, `ship.md`, and README **The workflow**. Change all four together.
- **Self-protection:** `protected_files` must always include `.claude/settings.json`, `.claude/guardrails.json` and `.claude/hooks/*`, so Claude can't loosen its own rules.
- **Reviewer stays read-only:** `code-reviewer.md` must never get `Edit`, `Write` or `NotebookEdit` in `tools`.
- **README tree and install steps:** the README tree and **Getting started** must match `src/` and how `install.sh` behaves (its flags, what gets skipped).

## Hook script conventions

- Bash plus `jq` only. No other runtimes or dependencies. Keep the scripts compatible with macOS's default bash 3.2: no associative arrays, no `${var,,}`, no `mapfile`.
- Exit `2` with a message on stderr blocks the action and sends that message to Claude. Messages say what was blocked and what to do instead.
- `guard.sh` **fails closed**: if `jq` or the config is missing, or the config is invalid, every call is blocked. `checks.sh` exits `1` (non-blocking) on a broken config, so a subagent can't get stuck in a loop. Keep this asymmetry.
- `set -f` in `guard.sh` is deliberate. Config patterns are glob-matched and must never expand against the filesystem.
- Language-agnostic: an empty `commands.format`/`commands.test` is a no-op. Never hardcode a stack in the scripts.
- The guardrails catch mistakes; they aren't a security boundary. Don't make them sound stronger than that in the docs.

## Testing hook changes

The kit's settings sit in `src/.claude/`, not the repo root, so they are **not active** while you work on this repo. Test the hooks by piping a tool-call JSON into them:

```bash
cd src
echo '{"tool_name":"Read","tool_input":{"file_path":".env"}}' \
  | CLAUDE_PROJECT_DIR=$PWD .claude/hooks/guard.sh; echo "exit=$?"   # expect 2
echo '{"tool_name":"Bash","tool_input":{"command":"git push --force origin feat/x"}}' \
  | CLAUDE_PROJECT_DIR=$PWD .claude/hooks/guard.sh; echo "exit=$?"   # expect 2
echo '{"tool_name":"Read","tool_input":{"file_path":"README.md"}}' \
  | CLAUDE_PROJECT_DIR=$PWD .claude/hooks/guard.sh; echo "exit=$?"   # expect 0
```

For every behavior change, check one case that should be blocked and one that should pass. Run `shellcheck` on the scripts if it's installed, and keep them executable (`chmod +x`).

## Writing style for kit files

- `src/CLAUDE.md` and the agent files are prompts that land in other people's projects. Keep them short, direct and generic, with no project-specific details beyond the `<...>` placeholders.
- Keep Python and Node as the two worked examples. Other stacks go in the README as one-line hints.
- Plain, concrete language. No marketing tone.

## Git

- Work on branches (`feat/...`, `fix/...`, `docs/...`) and open PRs. Don't push to `main` directly.
- One concern per commit, with a short imperative message.
