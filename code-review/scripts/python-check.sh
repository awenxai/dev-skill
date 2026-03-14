#!/usr/bin/env bash
set -euo pipefail

# ruff check (preferred) or flake8
if command -v ruff &>/dev/null; then
  ruff_out=$(ruff check . 2>&1)
  [[ -n "$ruff_out" ]] \
    && echo "TOOL: ruff check   STATUS: fail    DETAIL: $ruff_out" \
    || echo "TOOL: ruff check   STATUS: pass    DETAIL:"
  # ruff format check
  fmt_out=$(ruff format --check . 2>&1)
  [[ -n "$fmt_out" ]] \
    && echo "TOOL: ruff format  STATUS: fail    DETAIL: format drift detected" \
    || echo "TOOL: ruff format  STATUS: pass    DETAIL:"
elif command -v flake8 &>/dev/null; then
  flake_out=$(flake8 . 2>&1)
  [[ -n "$flake_out" ]] \
    && echo "TOOL: flake8       STATUS: fail    DETAIL: $flake_out" \
    || echo "TOOL: flake8       STATUS: pass    DETAIL:"
else
  echo "TOOL: ruff         STATUS: skip    DETAIL: not installed (optional)"
fi

# mypy or pyright
if command -v mypy &>/dev/null; then
  mypy_out=$(mypy . 2>&1)
  echo "$mypy_out" | grep -q 'error:' \
    && echo "TOOL: mypy         STATUS: fail    DETAIL: $(echo "$mypy_out" | grep -c 'error:') errors" \
    || echo "TOOL: mypy         STATUS: pass    DETAIL:"
else
  echo "TOOL: mypy         STATUS: skip    DETAIL: not installed (optional)"
fi

# pytest
if command -v pytest &>/dev/null; then
  pytest_out=$(pytest 2>&1)
  echo "$pytest_out" | grep -qE 'failed|error' \
    && echo "TOOL: pytest       STATUS: fail    DETAIL: $(echo "$pytest_out" | tail -1)" \
    || echo "TOOL: pytest       STATUS: pass    DETAIL:"
else
  echo "TOOL: pytest       STATUS: skip    DETAIL: not installed (optional)"
fi
