#!/bin/sh
# Run the vim-dialogue-manager test suite.
#
#   sh tests/run.sh          # with vim (falls back to nvim)
#   sh tests/run.sh nvim     # with neovim
#
# Exits 0 when all tests pass.

cd "$(dirname "$0")" || exit 1

EDITOR_BIN="${1:-vim}"
if ! command -v "$EDITOR_BIN" >/dev/null 2>&1; then
  if command -v nvim >/dev/null 2>&1; then
    EDITOR_BIN=nvim
  else
    echo "Neither vim nor nvim found." >&2
    exit 127
  fi
fi

LOG="$(mktemp)"
"$EDITOR_BIN" -Nu NONE -U NONE -n -es -V1"$LOG" -S run.vim
code=$?

# Show the interesting bits of the log (test results, failures, errors).
grep -a "TESTS\|FAIL\|Error detected\|E[0-9][0-9]:" "$LOG" || cat "$LOG"
rm -f "$LOG"
exit $code
