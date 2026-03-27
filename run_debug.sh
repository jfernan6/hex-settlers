#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
GODOT_BIN="${GODOT_BIN:-$(command -v godot || true)}"
LOG_DIR="$PROJECT_DIR/debug/screenshots/latest_run"
LOG_FILE="$LOG_DIR/latest_run.log"
LATEST_FILE="$PROJECT_DIR/debug/screenshots/latest.png"

if [[ -z "$GODOT_BIN" ]]; then
  echo "Could not find godot on PATH. Set GODOT_BIN to the executable path." >&2
  exit 1
fi

mkdir -p "$LOG_DIR"

echo "=== Hex Settlers Debug Run ==="
echo "Project: $PROJECT_DIR"
echo "Godot:   $GODOT_BIN"

"$GODOT_BIN" --path "$PROJECT_DIR" -- --debug-screenshot 2>&1 | tee "$LOG_FILE"

echo
echo "=== Done ==="
if [[ -f "$LATEST_FILE" ]]; then
  echo "Screenshot: $LATEST_FILE"
else
  echo "No latest screenshot found. Check the log for errors." >&2
fi
echo "Log:        $LOG_FILE"
