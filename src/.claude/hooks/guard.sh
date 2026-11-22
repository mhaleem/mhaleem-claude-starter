#!/usr/bin/env bash
# PreToolUse guardrail hook. Rules live in .claude/guardrails.json.
# Blocks dangerous commands, pushes to protected branches, force pushes,
# access to secret files and edits to protected files.
# Exit 2 blocks the tool call and sends the message back to Claude.
set -uo pipefail
set -f # no pathname expansion: patterns from the config are matched, never expanded

block() {
  echo "Blocked by guardrails: $*" >&2
  exit 2
}

command -v jq >/dev/null 2>&1 || block "jq is required by the guardrail hooks. Please install jq."

input=$(cat)
project_dir=${CLAUDE_PROJECT_DIR:-$(jq -r '.cwd // empty' <<<"$input")}
project_dir=${project_dir:-$PWD}
config="$project_dir/.claude/guardrails.json"

[[ -f $config ]] || block "config file not found: $config"
jq empty "$config" 2>/dev/null || block "$config is not valid JSON."

config_list() {
  jq -r --arg key "$1" '.[$key] // [] | .[]' "$config"
}

field() {
  jq -r "$1 // empty" <<<"$input"
}

# True if the value matches any glob pattern in the config list.
matches_pattern() {
  local value=$1 key=$2 pattern
  while IFS= read -r pattern; do
    # shellcheck disable=SC2053 # unquoted on purpose: glob match
    [[ -n $pattern && $value == $pattern ]] && return 0
  done < <(config_list "$key")
  return 1
}

# True if the value equals any entry in the config list.
in_list() {
  local value=$1 key=$2 entry
  while IFS= read -r entry; do
    [[ -n $entry && $value == "$entry" ]] && return 0
  done < <(config_list "$key")
  return 1
}

# Matches a path against a list, both as a project-relative path and by file name.
path_matches() {
  local path=${1#./} key=$2
  local relative=${path#"$project_dir"/}
  local name=${path##*/}
  matches_pattern "$relative" "$key" || matches_pattern "$name" "$key"
}

check_path() {
  local path=$1 mode=$2
  [[ -z $path ]] && return 0
  path_matches "$path" allowed_files && return 0
  if path_matches "$path" secret_files; then
    block "'$path' is a secret file. Use .env.example to see variable names."
  fi
  if [[ $mode == edit ]] && path_matches "$path" protected_files; then
    block "'$path' is protected. Ask the user to change it by hand."
  fi
}

tokens() {
  tr ';|&<>()"`=' ' ' <<<"$1" | tr "'" ' ' | tr -s '[:space:]' '\n'
}

check_blocked_commands() {
  local command=$1 pattern
  while IFS= read -r pattern; do
    [[ -n $pattern && $command == *"$pattern"* ]] && block "command contains '$pattern'."
  done < <(config_list blocked_commands)
}

check_secret_mentions() {
  local token
  while IFS= read -r token; do
    [[ -z $token || $token == -* ]] && continue
    path_matches "$token" allowed_files && continue
    if path_matches "$token" secret_files; then
      block "command touches secret file '$token'. Use .env.example to see variable names."
    fi
  done < <(tokens "$1")
}

check_git_push() {
  local command=$1
  local push_re='(^|[;&|( ])git( +[^ ;&|]+)* +push( |$)'
  [[ $command =~ $push_re ]] || return 0

  local push_args
  push_args=$(sed -E 's/.*git( +[^ ;&|]+)* +push//; s/[;&|].*//' <<<"$command")

  local block_force
  block_force=$(jq -r '.block_force_push // false' "$config")

  local current_branch
  current_branch=$(git -C "$project_dir" branch --show-current 2>/dev/null || true)
  if [[ -n $current_branch ]] && in_list "$current_branch" protected_branches; then
    block "you are on protected branch '$current_branch'. Create a feature branch and open a PR."
  fi

  local arg target
  while IFS= read -r arg; do
    [[ -z $arg ]] && continue
    if [[ $block_force == true ]]; then
      case $arg in
        -f | --force | --force-with-lease* | --force-if-includes | +*)
          block "force push is not allowed."
          ;;
      esac
    fi
    case $arg in
      --all | --mirror)
        block "'git push $arg' would push protected branches."
        ;;
    esac
    target=${arg#+}
    target=${target##*:}
    target=${target#refs/heads/}
    if in_list "$target" protected_branches; then
      block "pushing to protected branch '$target'. Use a feature branch and a PR."
    fi
  done < <(tokens "$push_args")
}

check_command() {
  local command
  command=$(tr -s '[:space:]' ' ' <<<"$1")
  check_blocked_commands "$command"
  check_secret_mentions "$command"
  check_git_push "$command"
}

case $(field '.tool_name') in
  Bash)
    check_command "$(field '.tool_input.command')"
    ;;
  Read)
    check_path "$(field '.tool_input.file_path')" read
    ;;
  Grep)
    check_path "$(field '.tool_input.path')" read
    check_path "$(field '.tool_input.glob')" read
    ;;
  Glob)
    check_path "$(field '.tool_input.path')" read
    check_path "$(field '.tool_input.pattern')" read
    ;;
  Edit | Write | MultiEdit)
    check_path "$(field '.tool_input.file_path')" edit
    ;;
  NotebookEdit)
    check_path "$(field '.tool_input.notebook_path')" edit
    ;;
esac

exit 0
