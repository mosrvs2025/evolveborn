#!/usr/bin/env bash
# Exports the browser build into docs/, which is what GitHub Pages serves.
#
# The export MUST stay the single-threaded variant: GitHub Pages cannot send the
# COOP/COEP headers that the threaded build requires.
set -euo pipefail

# The Godot binary is not part of the repo; take it from $GODOT, the PATH, or
# the usual side-install locations.
GODOT="${GODOT:-}"
if [ -z "$GODOT" ]; then
  for cand in "$HOME/tools/godot" /home/claude/tools/godot "$(command -v godot || true)"; do
    if [ -n "$cand" ] && [ -x "$cand" ]; then GODOT="$cand"; break; fi
  done
fi
if [ -z "$GODOT" ]; then
  echo "godot binary not found; set GODOT=/path/to/godot" >&2
  exit 1
fi
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT"
mkdir -p docs
rm -f docs/index.* docs/*.wasm docs/*.pck docs/*.js docs/*.png

"$GODOT" --headless --path "$ROOT" --import
"$GODOT" --headless --path "$ROOT" --export-release "Web" "$ROOT/docs/index.html"

# Pages serves this directory verbatim; Jekyll would eat the underscore files.
touch docs/.nojekyll

echo
echo "docs/ contents:"
ls -lh docs/ | sed 's/^/  /'
