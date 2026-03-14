# Architecture Review Guide

Reference for Phase 2 of the code review workflow. Evaluate design fit and structural integrity of
the change. Architecture violations = 🟡 `[P2]`. Violations with blast radius risk = 🟠 `[P1]`.

---

## Layer Separation

Most backend services follow a layered architecture:

```
HTTP Handler / Controller
        ↓
  Service / Use Case
        ↓
  Repository / DAO
        ↓
  Database / External
```

**Rules:**
- Each layer may only call the layer directly below it
- No layer may skip a layer (e.g., handler calling repository directly)
- Domain/business logic must not live in handlers or repositories
- Infrastructure concerns (SQL, HTTP clients, file I/O) must not appear in the service layer

**Violations to flag:**

```go
// Handler calling repository directly — layer skip
func (h *OrderHandler) Create(w http.ResponseWriter, r *http.Request) {
    order, err := h.orderRepo.Save(r.Context(), ...) // SKIP: should go through service
}
```

```python
# Business logic in repository — wrong layer
class OrderRepository:
    def save(self, order: Order) -> Order:
        if order.total > 10000:               # business rule in repo — wrong layer
            order.status = "pending_approval"
        return self.db.add(order)
```

```typescript
// Infrastructure in service layer
class OrderService {
  async create(data: CreateOrderDto) {
    const conn = await pg.connect()           // raw DB in service — wrong layer
    await conn.query('INSERT INTO orders ...')
  }
}
```

**Severity:** 🟡 `[P2]` for minor bypasses. 🟠 `[P1]` if it creates a circular dependency or hides business logic in infrastructure.

---

## API Contract Stability

When reviewing changes to API endpoints or shared interfaces, classify the change:

### Breaking changes (require migration strategy)
- Removing a field from a response
- Renaming a field
- Changing the type of an existing field
- Removing an endpoint
- Changing required → optional semantics that callers depend on
- Changing HTTP method or status codes

### Additive (non-breaking, safe to ship)
- Adding new optional fields to a response
- Adding new endpoints
- Adding new optional query parameters
- Expanding an enum with new values (if clients handle unknowns gracefully)

**Flag breaking changes without a migration plan:**

```
ENDPOINT: DELETE /api/v1/users/:id/profile → removed without deprecation notice
FIELD: response.user.name → renamed to response.user.full_name (breaks existing clients)
```

**Migration patterns:**
1. **Versioning:** add `/api/v2/` route, keep v1 for N deprecation cycles
2. **Parallel fields:** add `full_name`, keep `name` for one release, then remove
3. **Feature flags:** gate the change behind a flag until clients are updated

**Severity:** Breaking change without strategy = 🟠 `[P1]`. Breaking change on a public/partner-facing API = 🔴 `[P0]`.

---

## Service Boundary Creep

Each service or module should own a clearly bounded domain. Flag when a service starts reaching
into another service's domain.

**Signals:**
- `OrderService` directly reads from `UserRepository` (should call `UserService` instead)
- `PaymentService` contains logic for generating email receipts (email is a separate concern)
- A new field is added to an entity to serve a single consumer that shouldn't own it

**Review questions:**
- Does this change cause one service to know too much about another's internals?
- Could this data/logic be owned by a more appropriate service?
- Is this adding coupling between previously independent modules?

**Anti-pattern:**
```go
// OrderService reaching into user domain directly
func (s *OrderService) Create(ctx context.Context, req CreateOrderReq) (Order, error) {
    user, _ := s.userRepo.FindByID(ctx, req.UserID) // should call UserService
    if !user.IsVerified { ... }
}
```

**Correct — call across service boundary:**
```go
func (s *OrderService) Create(ctx context.Context, req CreateOrderReq) (Order, error) {
    isVerified, err := s.userService.IsVerified(ctx, req.UserID)
    if err != nil { return Order{}, fmt.Errorf("checking user verification: %w", err) }
    if !isVerified { return Order{}, ErrUserNotVerified }
}
```

**Severity:** 🟡 `[P2]`. If it creates a circular dependency = 🟠 `[P1]`.

---

## Database Migrations

DB migrations are high-risk changes that can cause production incidents if not carefully reviewed.

### Zero-downtime deployment checklist

**Safe (backward-compatible) operations:**
- [ ] Adding a new nullable column
- [ ] Adding a new table
- [ ] Adding an index (`CREATE INDEX CONCURRENTLY` in Postgres)
- [ ] Adding a new enum value (check ORM behavior — may require restart)

**Risky operations (require special handling):**
- [ ] Adding a NOT NULL column without a default → locks table during backfill
- [ ] Dropping a column → may still be referenced by running code until deploy completes
- [ ] Renaming a column → breaks all queries before/after migration window
- [ ] Changing column type → may require rewrite of the entire table
- [ ] `ALTER TABLE` without `CONCURRENTLY` on large tables → full table lock

**Safe rename pattern (3-step deployment):**
1. Migration 1: Add new column, update writes to fill both
2. Deploy: Read from old column, write to both
3. Migration 2: Backfill old → new, then drop old column

**Review checklist for any migration file:**
- [ ] Is the migration reversible (has a `down` migration)?
- [ ] Does it lock tables in a way that causes downtime?
- [ ] Is there a backfill strategy for existing rows?
- [ ] Is the migration idempotent (safe to run twice)?
- [ ] Does the running application code handle both before/after states?

**Severity:** Missing `down` migration = 🟡 `[P2]`. Table-locking migration on large table = 🟠 `[P1]`. Dropping a column still referenced by running code = 🔴 `[P0]`.

---

## Dependency Direction

In clean architecture, dependencies must point inward:

```
External → Infrastructure → Application → Domain
```

- Domain layer: pure business logic, no imports from infrastructure
- Application layer: orchestrates domain; depends on interfaces, not concretions
- Infrastructure layer: implements interfaces; imports DB drivers, HTTP clients, etc.
- External layer: HTTP handlers, CLI commands, queue consumers

**Flag when:**
- Domain structs import infrastructure packages (`database/sql`, `net/http`, `os`)
- Application services import concrete infrastructure types instead of interfaces
- Circular imports between packages at the same layer

**Severity:** 🟡 `[P2]`. Circular dependency = 🟠 `[P1]`.
