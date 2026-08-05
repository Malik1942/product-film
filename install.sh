#!/bin/bash
# product-film installer — copies the skill into Claude Code's personal skills directory.
# Usage: curl -fsSL https://raw.githubusercontent.com/Malik1942/product-film/main/install.sh | bash
#        ./install.sh [destination]
set -euo pipefail

DEST="${1:-$HOME/.claude/skills/product-film}"
REPO_TARBALL="https://github.com/Malik1942/product-film/archive/refs/heads/main.tar.gz"

if [ -e "$DEST/SKILL.md" ]; then
  echo "product-film already installed at $DEST — updating in place."
fi

mkdir -p "$DEST"
curl -fsSL "$REPO_TARBALL" | tar xz --strip-components=1 -C "$DEST"

echo "✓ product-film installed to $DEST"
echo "  Open Claude Code and ask for a product film — the skill triggers automatically."
echo "  Requirements: macOS + Xcode Command Line Tools (swift on PATH)."
