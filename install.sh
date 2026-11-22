#!/usr/bin/env bash
# Copies the starter kit (src/CLAUDE.md and src/.claude/) into a project.
# Existing files are skipped unless --force is given.
# Usage: ./install.sh [--force] <project-path>
set -euo pipefail

usage() {
  echo "usage: $0 [--force] <project-path>" >&2
  exit 1
}

force=false
dest=""
for arg in "$@"; do
  case $arg in
    -f | --force) force=true ;;
    -h | --help) usage ;;
    -*) echo "unknown option: $arg" >&2; usage ;;
    *) [[ -z $dest ]] || usage; dest=$arg ;;
  esac
done
[[ -n $dest ]] || usage
[[ -d $dest ]] || { echo "destination is not a directory: $dest" >&2; exit 1; }

src_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/src"
dest=$(cd "$dest" && pwd)
[[ $dest != "$src_dir" ]] || { echo "destination is the kit itself" >&2; exit 1; }

copied=0
skipped=0
while IFS= read -r file; do
  rel=${file#"$src_dir"/}
  target="$dest/$rel"
  if [[ -e $target && $force == false ]]; then
    echo "skip   $rel (exists, use --force to overwrite)"
    skipped=$((skipped + 1))
    continue
  fi
  mkdir -p "$(dirname "$target")"
  cp "$file" "$target"
  echo "copy   $rel"
  copied=$((copied + 1))
done < <(find "$src_dir" -type f ! -name '.DS_Store' | sort)

chmod +x "$dest"/.claude/hooks/*.sh

echo
echo "Done: $copied copied, $skipped skipped into $dest"
command -v jq >/dev/null 2>&1 || echo "Warning: jq is not installed. The hooks need it (brew install jq / apt install jq)."
cat <<'EOF'

Next steps:
  1. Set commands.format and commands.test in .claude/guardrails.json
  2. Fill in the <...> placeholders in CLAUDE.md
  3. Add a .env.example with your variable names
  4. Start Claude Code, run /hooks to confirm, then /ship <task>
EOF
