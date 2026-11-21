#!/usr/bin/env bash
# Runs the "format" or "test" command from .claude/guardrails.json.
# An empty command is skipped, so the kit works in any language.
# Usage: checks.sh format|test
set -uo pipefail

kind=${1:-}
case $kind in
  format | test) ;;
  *)
    echo "usage: checks.sh format|test" >&2
    exit 1
    ;;
esac

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required by the guardrail hooks. Please install jq." >&2
  exit 1
fi

project_dir=${CLAUDE_PROJECT_DIR:-$PWD}
config="$project_dir/.claude/guardrails.json"

if ! jq empty "$config" 2>/dev/null; then
  echo "Skipping $kind check: $config is missing or not valid JSON." >&2
  exit 1
fi

command=$(jq -r --arg kind "$kind" '.commands[$kind] // empty' "$config")
[[ -z $command ]] && exit 0

cd "$project_dir" || exit 1

if ! output=$(bash -c "$command" 2>&1); then
  if [[ $kind == test ]]; then
    echo "Tests are failing ($command). Fix them before handing over:" >&2
  else
    echo "Format or lint failed ($command). Fix these issues:" >&2
  fi
  printf '%s\n' "$output" | tail -n 40 >&2
  exit 2
fi

exit 0
