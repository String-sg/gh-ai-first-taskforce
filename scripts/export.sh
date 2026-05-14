#!/usr/bin/env bash
set -euo pipefail

DECK="${1:-}"

if [[ -z "$DECK" ]]; then
  echo "Usage: ./scripts/export.sh <deck-name>"
  echo "Example: ./scripts/export.sh example"
  echo ""
  echo "Available decks:"
  ls decks/*.md 2>/dev/null | xargs -n1 basename | sed 's/\.md$//'
  exit 1
fi

DECK_PATH="decks/${DECK}.md"
OUTPUT_PATH="decks/${DECK}.pdf"

if [[ ! -f "$DECK_PATH" ]]; then
  echo "Error: $DECK_PATH not found."
  echo ""
  echo "Available decks:"
  ls decks/*.md 2>/dev/null | xargs -n1 basename | sed 's/\.md$//'
  exit 1
fi

# Export requires Playwright Chromium. If it's missing, prompt the user to install it.
if ! npx playwright install chromium --dry-run &>/dev/null; then
  echo "Playwright Chromium not found. Installing..."
  npx playwright install chromium
fi

npx slidev export "$DECK_PATH" --output "$OUTPUT_PATH"
echo ""
echo "Exported to $OUTPUT_PATH"
