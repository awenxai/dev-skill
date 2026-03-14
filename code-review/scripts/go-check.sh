#!/usr/bin/env bash
set -euo pipefail

# goimports — REQUIRED; print install guide if missing
if ! command -v goimports &>/dev/null; then
  echo "TOOL: goimports    STATUS: fail    DETAIL: not installed — run: go install golang.org/x/tools/cmd/goimports@latest"
  exit 1
fi
drift=$(goimports -l . 2>&1)
if [[ -n "$drift" ]]; then
  echo "TOOL: goimports    STATUS: fail    DETAIL: $drift"
else
  echo "TOOL: goimports    STATUS: pass    DETAIL:"
fi

# go build
build_out=$(go build ./... 2>&1)
if [[ -n "$build_out" ]]; then
  echo "TOOL: go build     STATUS: fail    DETAIL: $(echo "$build_out" | head -5)"
else
  echo "TOOL: go build     STATUS: pass    DETAIL:"
fi

# go vet
vet_out=$(go vet ./... 2>&1)
if [[ -n "$vet_out" ]]; then
  echo "TOOL: go vet       STATUS: fail    DETAIL: $vet_out"
else
  echo "TOOL: go vet       STATUS: pass    DETAIL:"
fi

# go test
test_out=$(go test ./... 2>&1)
if echo "$test_out" | grep -q 'FAIL'; then
  echo "TOOL: go test      STATUS: fail    DETAIL: $(echo "$test_out" | grep FAIL)"
else
  echo "TOOL: go test      STATUS: pass    DETAIL:"
fi

# go test -race
race_out=$(go test -race ./... 2>&1)
if echo "$race_out" | grep -qE 'DATA RACE|FAIL'; then
  echo "TOOL: go test -race  STATUS: fail    DETAIL: race condition or test failure detected"
else
  echo "TOOL: go test -race  STATUS: pass    DETAIL:"
fi

# golangci-lint — optional
if command -v golangci-lint &>/dev/null; then
  lint_out=$(golangci-lint run 2>&1)
  if [[ -n "$lint_out" ]]; then
    echo "TOOL: golangci-lint  STATUS: fail    DETAIL: $(echo "$lint_out" | wc -l) issues"
  else
    echo "TOOL: golangci-lint  STATUS: pass    DETAIL:"
  fi
else
  echo "TOOL: golangci-lint  STATUS: skip    DETAIL: not installed (optional)"
fi
