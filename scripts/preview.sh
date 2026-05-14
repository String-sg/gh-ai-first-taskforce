#!/usr/bin/env bash
set -euo pipefail

DECK="${1:-}"

if [[ -z "$DECK" ]]; then
  echo "Usage: ./scripts/preview.sh <deck-name>"
  echo "Example: ./scripts/preview.sh example"
  echo ""
  echo "Available decks:"
  ls decks/*.md 2>/dev/null | xargs -n1 basename | sed 's/\.md$//'
  exit 1
fi

DECK_PATH="decks/${DECK}.md"

if [[ ! -f "$DECK_PATH" ]]; then
  echo "Error: $DECK_PATH not found."
  echo ""
  echo "Available decks:"
  ls decks/*.md 2>/dev/null | xargs -n1 basename | sed 's/\.md$//'
  exit 1
fi

npx slidev "$DECK_PATH"
