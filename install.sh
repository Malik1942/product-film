#!/bin/bash
# product-film installer — installs the skill for Claude Code, Codex and/or Cursor.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/Malik1942/product-film/main/install.sh | bash
#   ./install.sh                      # all supported agents (personal scope)
#   ./install.sh --claude --codex     # only the agents you name
#   ./install.sh --project [DIR]      # install into DIR (default: cwd) instead of $HOME
#   ./install.sh /custom/path         # single explicit destination
#
# One real copy is downloaded; the other agents' directories become symlinks to it,
# so `git pull` in the real copy updates every agent at once.
set -euo pipefail

REPO_TARBALL="https://github.com/Malik1942/product-film/archive/refs/heads/main.tar.gz"
SKILL="product-film"

WANT_CLAUDE=0; WANT_CODEX=0; WANT_CURSOR=0
SCOPE="personal"; ROOT="$HOME"; EXPLICIT_DEST=""

while [ $# -gt 0 ]; do
  case "$1" in
    --claude) WANT_CLAUDE=1 ;;
    --codex)  WANT_CODEX=1 ;;
    --cursor) WANT_CURSOR=1 ;;
    --all)    WANT_CLAUDE=1; WANT_CODEX=1; WANT_CURSOR=1 ;;
    --project)
      SCOPE="project"
      if [ $# -gt 1 ] && [ "${2:0:1}" != "-" ]; then ROOT="$2"; shift; else ROOT="$PWD"; fi
      ;;
    -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) echo "unknown option: $1" >&2; exit 2 ;;
    *)  EXPLICIT_DEST="$1" ;;
  esac
  shift
done

# Default: every supported agent.
if [ $((WANT_CLAUDE + WANT_CODEX + WANT_CURSOR)) -eq 0 ]; then
  WANT_CLAUDE=1; WANT_CODEX=1; WANT_CURSOR=1
fi

# Skill directories each agent reads. Codex's documented path is .agents/skills;
# .codex/skills is kept as a compatibility target for older Codex builds.
TARGETS=()
if [ -n "$EXPLICIT_DEST" ]; then
  TARGETS=("$EXPLICIT_DEST")
else
  [ "$WANT_CLAUDE" = 1 ] && TARGETS+=("$ROOT/.claude/skills/$SKILL")
  [ "$WANT_CODEX"  = 1 ] && TARGETS+=("$ROOT/.agents/skills/$SKILL" "$ROOT/.codex/skills/$SKILL")
  [ "$WANT_CURSOR" = 1 ] && TARGETS+=("$ROOT/.cursor/skills/$SKILL")
fi

# The first target holds the real files; the rest symlink to it.
REAL="${TARGETS[0]}"

if [ -e "$REAL/SKILL.md" ] && [ ! -L "$REAL" ]; then
  echo "product-film already installed at $REAL — updating in place."
fi

mkdir -p "$REAL"
curl -fsSL "$REPO_TARBALL" | tar xz --strip-components=1 -C "$REAL"
echo "✓ installed to $REAL"

for dest in "${TARGETS[@]:1}"; do
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    echo "  ! $dest exists and is not a symlink — left untouched"
    continue
  fi
  mkdir -p "$(dirname "$dest")"
  # Project-scope links must be relative — an absolute link committed to a repo
  # is broken for every other clone. Both paths are $ROOT/<agent-dir>/skills/$SKILL.
  if [ "$SCOPE" = "project" ]; then
    target="../../${REAL#"$ROOT"/}"
  else
    target="$REAL"
  fi
  ln -sfn "$target" "$dest"
  echo "✓ linked   $dest -> $target"
done

echo
echo "Ask your agent for a product film — it discovers the skill automatically."
echo "  Claude Code  skills are read from .claude/skills/"
echo "  Codex        skills are read from .agents/skills/"
echo "  Cursor       reads .cursor/skills/, .agents/skills/, and the two above"
echo "Requirements: macOS + Xcode Command Line Tools (swift on PATH)."
