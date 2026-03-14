#!/usr/bin/env bash
set -euo pipefail

# tsc --noEmit
if npx tsc --version &>/dev/null 2>&1; then
  tsc_out=$(npx tsc --noEmit 2>&1)
  [[ -n "$tsc_out" ]] \
    && echo "TOOL: tsc          STATUS: fail    DETAIL: $(echo "$tsc_out" | wc -l) type errors" \
    || echo "TOOL: tsc          STATUS: pass    DETAIL:"
else
  echo "TOOL: tsc          STATUS: skip    DETAIL: not installed (optional)"
fi

# eslint
if npx eslint --version &>/dev/null 2>&1; then
  eslint_out=$(npx eslint . --ext .ts,.tsx 2>&1)
  [[ -n "$eslint_out" ]] \
    && echo "TOOL: eslint       STATUS: fail    DETAIL: $(echo "$eslint_out" | grep -c 'error\|warning') issues" \
    || echo "TOOL: eslint       STATUS: pass    DETAIL:"
else
  echo "TOOL: eslint       STATUS: skip    DETAIL: not installed (optional)"
fi

# prettier --check
if npx prettier --version &>/dev/null 2>&1; then
  fmt_out=$(npx prettier --check . 2>&1)
  echo "$fmt_out" | grep -q 'Code style issues' \
    && echo "TOOL: prettier     STATUS: fail    DETAIL: format drift detected" \
    || echo "TOOL: prettier     STATUS: pass    DETAIL:"
else
  echo "TOOL: prettier     STATUS: skip    DETAIL: not installed (optional)"
fi

# npm test
if [[ -f package.json ]] && jq -e '.scripts.test' package.json &>/dev/null; then
  test_out=$(npm test 2>&1)
  echo "$test_out" | grep -qiE 'failed|error' \
    && echo "TOOL: npm test     STATUS: fail    DETAIL: test failures detected" \
    || echo "TOOL: npm test     STATUS: pass    DETAIL:"
else
  echo "TOOL: npm test     STATUS: skip    DETAIL: no test script in package.json"
fi
