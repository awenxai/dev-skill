# Go Language Guide

Reference for Phase 5 of the code review workflow. Load this file when the stack fingerprint is `go.mod`.

---

## Error Handling

Go errors are values — treat them seriously.

### Rules
- **Always check returned errors.** No `result, _ := fn()` without a comment explaining why.
- **Wrap errors with context** using `fmt.Errorf("doing X: %w", err)` — never return bare `err`.
- **No bare `panic`** in library or application code (only acceptable in `main()` for unrecoverable startup failure).
- **Sentinel errors** should be exported and named `ErrXxx` for comparison with `errors.Is()`.
- **Custom error types** implement the `error` interface and can be inspected with `errors.As()`.

```go
// VIOLATION — bare error, no context
func (s *Service) CreateOrder(ctx context.Context, req Request) (Order, error) {
    user, err := s.userRepo.FindByID(ctx, req.UserID)
    if err != nil {
        return Order{}, err  // caller can't tell where it failed
    }
    order, err := s.orderRepo.Save(ctx, req.ToOrder())
    if err != nil {
        return Order{}, err  // same
    }
    return order, nil
}

// CORRECT — wrapped errors with context
func (s *Service) CreateOrder(ctx context.Context, req Request) (Order, error) {
    user, err := s.userRepo.FindByID(ctx, req.UserID)
    if err != nil {
        return Order{}, fmt.Errorf("finding user %s: %w", req.UserID, err)
    }
    order, err := s.orderRepo.Save(ctx, req.ToOrder(user))
    if err != nil {
        return Order{}, fmt.Errorf("saving order for user %s: %w", req.UserID, err)
    }
    return order, nil
}
```

**Severity:** Unchecked errors = 🟡 `[P2]`. Unchecked errors on DB write / external call = 🟠 `[P1]`.

---

## Goroutines & Concurrency

### Goroutine lifecycle rules
- Every goroutine launched must have a clear exit condition.
- Goroutines must respect `context.Done()` for cancellation.
- Goroutines that do background work must communicate errors back to the caller (via channel or errgroup).
- Goroutines inside HTTP handlers are dangerous — the handler returns before the goroutine finishes.

```go
// VIOLATION — goroutine leak: no cancellation, errors lost
go func() {
    result, err := doSlowWork()
    // err silently dropped, no way to stop this goroutine
}()

// CORRECT — errgroup with context propagation
g, gCtx := errgroup.WithContext(ctx)
g.Go(func() error {
    return doSlowWork(gCtx)
})
if err := g.Wait(); err != nil {
    return fmt.Errorf("slow work: %w", err)
}
```

### context.Context propagation
- Every function that does I/O (DB, HTTP, cache) must accept `context.Context` as its first parameter.
- Never store context in a struct — pass it through the call chain.
- `context.Background()` is only acceptable at the top of the call chain (main, test setup).

```go
// VIOLATION
type Service struct { ctx context.Context }  // don't store ctx in struct

// CORRECT
func (s *Service) FindUser(ctx context.Context, id string) (*User, error)
```

### Race conditions
- Shared mutable state accessed from multiple goroutines must use `sync.Mutex`, `sync.RWMutex`, or atomic operations.
- Use `-race` flag in tests: `go test -race ./...`
- Prefer channels and `sync/atomic` over raw mutex when possible.

**Severity:** Goroutine leak = 🟠 `[P1]`. Race condition on shared state = 🔴 `[P0]`.

---

## Interface Design

### Consumer-defined interfaces
Go interfaces should be defined by the consumer (the package that uses them), not the provider.
Keep interfaces small — prefer 1–3 methods.

```go
// VIOLATION — large interface defined by provider
// auth/repository.go
type UserRepository interface {
    FindByID(ctx context.Context, id string) (*User, error)
    FindByEmail(ctx context.Context, email string) (*User, error)
    Save(ctx context.Context, user *User) error
    Delete(ctx context.Context, id string) error
    List(ctx context.Context) ([]*User, error)
    // ... 5 more methods
}

// CORRECT — small interfaces defined per consumer
// auth/service.go (auth only needs email lookup)
type UserFinder interface {
    FindByEmail(ctx context.Context, email string) (*User, error)
}

// admin/service.go (admin needs listing)
type UserLister interface {
    List(ctx context.Context) ([]*User, error)
}
```

### Interface placement
- Interfaces belong in the package that *uses* them, not the package that implements them.
- Exception: shared `pkg/` interfaces used across many packages.

**Severity:** 🟡 `[P2]`

---

## Package Structure

### `internal/` package
- Business logic, domain types, and service implementations go in `internal/`.
- Code in `internal/` cannot be imported by external packages — enforce strong boundaries.
- Prefer many small focused packages over one large package.

### Recommended layout
```
cmd/
  server/
    main.go           ← entry point, wires dependencies
internal/
  order/
    handler.go        ← HTTP layer
    service.go        ← business logic
    repository.go     ← data access interface
    model.go          ← domain types
  user/
    ...
pkg/
  middleware/         ← shared HTTP middleware
  config/             ← config loading
  database/           ← DB connection setup
```

### Common anti-patterns
- `utils.go` or `helpers.go` — split into focused packages
- `types.go` at the root — domain types should live near their behavior
- Circular imports between `internal/` packages — restructure to break the cycle

**Severity:** Circular imports = 🟠 `[P1]`. Structural issues = 🟡 `[P2]`.

---

## Testing

### Table-driven tests
Use table-driven tests for functions with multiple input/output cases.

```go
func TestValidateEmail(t *testing.T) {
    tests := []struct {
        name    string
        input   string
        wantErr bool
    }{
        {"valid email", "user@example.com", false},
        {"missing @", "userexample.com", true},
        {"empty string", "", true},
        {"local only", "user@", true},
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            err := ValidateEmail(tt.input)
            if (err != nil) != tt.wantErr {
                t.Errorf("ValidateEmail(%q) error = %v, wantErr %v", tt.input, err, tt.wantErr)
            }
        })
    }
}
```

### Integration tests
- Tag integration tests with `//go:build integration` to keep unit tests fast.
- Use `testcontainers-go` or a local Docker Compose setup for DB integration tests.
- Never mock the database for integration tests.

```go
//go:build integration

func TestOrderRepository_Save(t *testing.T) {
    db := setupTestDB(t)
    repo := NewOrderRepository(db)
    // ... test with real DB
}
```

### Test helpers
- Use `t.Helper()` in test helper functions for correct line number reporting.
- Use `t.Cleanup()` instead of `defer` in tests for proper cleanup ordering.
- Avoid global state in tests — each test should be independent.

**Severity:** Missing error path tests = 🟡 `[P2]`. No tests for new logic = 🟠 `[P1]`.

---

## Performance

- **Avoid premature optimization** — flag only when there's a measurable concern.
- **String building in loops:** use `strings.Builder` instead of `+` concatenation.
- **Slice pre-allocation:** use `make([]T, 0, knownLen)` when length is known.
- **`defer` in tight loops:** `defer` doesn't execute until function return — moves it out of the loop or restructure.
- **`sync.Pool`:** use for expensive-to-allocate objects reused frequently (e.g., buffers).
- **Avoid reflection** in hot paths.

```go
// VIOLATION — O(n) string concatenation
result := ""
for _, item := range items {
    result += item.Name + ", "  // allocates new string each iteration
}

// CORRECT
var sb strings.Builder
for _, item := range items {
    sb.WriteString(item.Name)
    sb.WriteString(", ")
}
result := sb.String()
```

**Severity:** Correctness-impacting performance issues = 🟠 `[P1]`. Optimization opportunities = 🟢 `[P3]`.

---

## Common Go Anti-Patterns

| Anti-pattern | Correct approach | Severity |
|-------------|-----------------|---------|
| `err != nil` check missing | Always check | 🟡 P2 |
| `panic` in library code | Return error | 🟠 P1 |
| Storing `context.Context` in struct | Pass as parameter | 🟡 P2 |
| Large interfaces (>5 methods) | Split per consumer | 🟡 P2 |
| `_` discarding important errors | Handle or document | 🟡 P2 |
| Goroutine without exit condition | Use context/errgroup | 🟠 P1 |
| `init()` with side effects | Explicit initialization | 🟡 P2 |
| Package-level vars for app state | Dependency injection | 🟡 P2 |
| Bare `http.Error` without structured response | Use consistent error envelope | 🟢 P3 |
