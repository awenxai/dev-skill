# Code Quality Checklist

Reference for Phase 5 of the code review workflow. Applies to all languages before loading the
language-specific guide. Style issues = 🟢 `[P3]`. Test gaps and complexity violations = 🟡 `[P2]`.

---

## Naming

**Principles:**
- Names should explain *why* and *what*, not *how*
- Avoid abbreviations unless universally understood in the domain (`ctx`, `id`, `HTTP`)
- Boolean names should read as a predicate (`isActive`, `hasPermission`, `canDelete`)
- Functions should be verb phrases (`createOrder`, `validateToken`, `findByEmail`)
- Avoid generic names: `manager`, `helper`, `util`, `data`, `info`, `temp`

**Flag these:**
```
// Ambiguous
func process(d interface{}) error
var x int

// Misleading (does more than name implies)
func GetUser(id int) (User, error)  // actually creates the user if not found

// Inconsistent casing / terminology across the codebase
getUserByID() and fetch_user_by_id() and FindUser()  // pick one convention
```

**Severity:** 🟢 `[P3]`

---

## Function / Method Size

**Targets:**
- **Lines:** < 20 lines of business logic (excluding error handling boilerplate)
- **Cyclomatic complexity:** < 10 (count `if`, `else`, `for`, `switch case`, `&&`, `||`, `?`)
- **Parameters:** ≤ 4; beyond that, use a struct/object

**How to count cyclomatic complexity (simplified):**
Start at 1. Add 1 for each: `if`, `else if`, `for`, `while`, `case`, `catch`, `&&`, `||`, ternary `?`.

**Flag when:**
- A function has 3+ levels of nesting
- A function has 5+ parameters
- A function handles multiple distinct concerns (setup + business logic + formatting)
- Long function that could be named differently in each half

**Refactoring signal:**
```go
// 60-line function with 3 concerns — split into:
func validateOrderRequest(req OrderRequest) error { ... }    // 10 lines
func applyDiscounts(order *Order, rules []DiscountRule) { ... } // 15 lines
func persistOrder(ctx context.Context, order Order) error { ... } // 12 lines
```

**Severity:** 🟡 `[P2]`

---

## Test Coverage

**Required coverage paths:**
- [ ] Happy path: the normal, expected input produces expected output
- [ ] Error paths: each error return site is tested (invalid input, DB failure, network failure)
- [ ] Edge cases: empty collections, zero values, max values, boundary conditions
- [ ] Concurrency: if code uses goroutines/async, test for race conditions where applicable

**Anti-patterns to flag:**
```go
// Tests only the happy path — missing error coverage
func TestCreateUser(t *testing.T) {
    user, err := service.Create(ctx, validInput)
    assert.NoError(t, err)
    assert.NotNil(t, user)
    // Missing: what happens when DB fails? when email is duplicate?
}
```

```python
# Test that only asserts no exception — not behavior
def test_process_order():
    service.process(mock_order)  # no assertions
```

**Coverage expectations for changed code:**
- New functions/methods: 100% of cases that can reasonably be triggered
- Modified functions: existing tests must still pass; add tests for new branches
- Bug fixes: test that reproduces the bug must be added

**Severity:** Missing error path tests = 🟡 `[P2]`. No tests at all for new logic = 🟠 `[P1]`.

---

## Structured Logging

**Required:**
- Use the team's structured logger (zerolog, zap, structlog, winston) — never `fmt.Printf` or `console.log` in production paths
- Log entries must include a trace/request ID for distributed tracing
- Log at the correct level: `DEBUG` for dev diagnostics, `INFO` for lifecycle events, `WARN` for degraded state, `ERROR` for failures

**PII rules:**
- Never log email addresses, phone numbers, passwords, tokens, credit card numbers, or full names
- Use anonymized identifiers (user ID, hashed email) in logs

**Flag these:**
```go
// Level too high for debug info
log.Error("processing request", "user_id", userID)  // should be INFO

// PII leak
log.Info("user logged in", "email", user.Email)     // log user.ID instead

// Unstructured
fmt.Printf("error processing order %d: %v\n", id, err)  // not queryable
```

**Correct pattern:**
```go
logger.InfoContext(ctx, "order created",
    slog.String("order_id", order.ID),
    slog.String("user_id", order.UserID),
    slog.String("trace_id", tracing.FromContext(ctx)),
)
```

**Severity:** PII leak = 🔴 `[P0]`. Unstructured production logging = 🟡 `[P2]`. Wrong level = 🟢 `[P3]`.

---

## Configuration

**Principles:**
- No magic numbers: extract to named constants with explanatory names
- No hardcoded environment assumptions: use env vars or config files
- Timeouts, retries, limits must be configurable — not hardcoded

**Flag these:**
```go
time.Sleep(5 * time.Second)              // magic number — name it
if len(items) > 100 { ... }             // magic limit — extract constant
db, _ := sql.Open("postgres", "localhost:5432/mydb")  // hardcoded env
```

**Correct:**
```go
const maxBatchSize = 100
const defaultTimeout = 5 * time.Second

timeout := cfg.RequestTimeout // from config struct loaded from env
```

**Severity:** 🟢 `[P3]`

---

## Dead Code

**Flag these:**
- Unused imports (should fail linting, flag anyway)
- Unused variables or function return values being discarded with `_` without explanation
- Commented-out code blocks (delete; git history preserves them)
- Functions that are defined but never called anywhere in the codebase
- `TODO` comments without a ticket reference or date that are > 6 months old

**Go specifics:**
```go
import _ "unused/package" // blank import only valid for side effects — verify intent
result, _ := riskyOperation() // discarded error — must be justified or handled
```

**Severity:** Commented-out code = 🟢 `[P3]`. Discarded errors without comment = 🟡 `[P2]`.

---

## Error Handling

**Principles:**
- Every error must be checked — no silent discard
- Errors must be wrapped with context: `fmt.Errorf("creating order: %w", err)`
- Distinguish recoverable errors (return to caller) from unrecoverable (log + fail fast)
- Avoid panic in library code; reserve it for programmer errors in main()

**Flag these:**
```go
result, _ := json.Marshal(data)          // unchecked error
os.Remove(tmpFile)                        // unchecked — was file removed?
go func() { doWork() }()                 // goroutine errors silently dropped
```

**Correct:**
```go
data, err := json.Marshal(payload)
if err != nil {
    return fmt.Errorf("marshaling payment request: %w", err)
}
```

**Python:**
```python
# Too broad — swallows real bugs
try:
    process()
except Exception:
    pass

# Correct — specific exception, logged, re-raised if needed
try:
    process()
except ValueError as e:
    logger.warning("invalid input", exc_info=True)
    raise
```

**Severity:** Discarded errors = 🟡 `[P2]`. Discarded errors on security-sensitive paths = 🟠 `[P1]`.
