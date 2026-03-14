# SOLID Principles Checklist

Reference for Phase 3 of the code review workflow. Evaluate each principle for the changed code.
Most violations = 🟡 `[P2]`. Violations that affect correctness or testability = 🟠 `[P1]`.

---

## S — Single Responsibility Principle

> A class or module should have exactly one reason to change.

**Questions to ask:**
- Does this type/module have more than one distinct concern?
- Would two different stakeholders ever ask you to change it for different reasons?
- Is the name accurate, or has the class grown beyond what its name implies?

**Signals of violation:**
- A service that handles business logic AND formats HTTP responses AND writes to a log file
- A "Manager" or "Helper" class with 10+ public methods spanning multiple domains
- Constructor that does meaningful work (fetches data, opens connections)

**Go example (violation):**
```go
// Bad: UserService does persistence, email, and HTTP response formatting
type UserService struct { db *sql.DB; smtp *mail.Client }
func (s *UserService) Register(w http.ResponseWriter, r *http.Request) { ... }
func (s *UserService) SendWelcomeEmail(user User) { ... }
func (s *UserService) SaveUser(user User) error { ... }
```

**Go example (correct):**
```go
type UserRepository interface { Save(ctx context.Context, user User) error }
type Mailer interface { SendWelcome(ctx context.Context, to string) error }
type UserService struct { repo UserRepository; mailer Mailer }
func (s *UserService) Register(ctx context.Context, req RegisterRequest) (User, error) { ... }
```

**Python example (violation):**
```python
class OrderService:
    def process_order(self, order): ...      # business logic
    def render_invoice_pdf(self, order): ... # presentation
    def send_confirmation_sms(self, order):  # comms
```

**TypeScript example (violation):**
```typescript
class ProductController {
  async create(req, res) { ... }         // HTTP concern
  calculateDiscount(product) { ... }    // domain logic — wrong layer
  formatCurrency(amount) { ... }        // presentation concern
}
```

**Severity:** 🟡 `[P2]` — refactor before next sprint.

---

## O — Open/Closed Principle

> Software entities should be open for extension but closed for modification.

**Questions to ask:**
- Does adding a new behavior require editing existing, tested code?
- Are there `switch`/`if-else` chains that grow with each new type?
- Are strategies, formatters, or handlers hardcoded by concrete type?

**Signals of violation:**
- `if type == "A" ... else if type == "B" ...` inside core logic
- Adding a new payment provider requires editing the payment processor class
- Feature flags scattered as conditionals inside business logic

**Go example (violation):**
```go
func ProcessPayment(method string, amount float64) error {
    switch method {
    case "stripe": return processStripe(amount)
    case "paypal": return processPaypal(amount)
    // Must edit this file for every new provider
    }
}
```

**Go example (correct):**
```go
type PaymentProvider interface { Charge(ctx context.Context, amount float64) error }

type PaymentProcessor struct { providers map[string]PaymentProvider }
func (p *PaymentProcessor) Process(ctx context.Context, method string, amount float64) error {
    provider, ok := p.providers[method]
    if !ok { return fmt.Errorf("unknown payment method: %s", method) }
    return provider.Charge(ctx, amount)
}
```

**TypeScript example (correct):**
```typescript
interface NotificationChannel { send(message: string): Promise<void> }

class NotificationService {
  constructor(private channels: NotificationChannel[]) {}
  async notify(message: string) {
    await Promise.all(this.channels.map(c => c.send(message)))
  }
}
```

**Severity:** 🟡 `[P2]`. If the switch causes incorrect routing or missed cases = 🟠 `[P1]`.

---

## L — Liskov Substitution Principle

> Subtypes must be substitutable for their base types without altering program correctness.

**Questions to ask:**
- Does any subtype throw exceptions the base type doesn't declare?
- Does any subtype ignore or weaken a postcondition the base type guarantees?
- Does any subtype require stricter preconditions than the base type?

**Signals of violation:**
- Override that throws `NotImplementedError` / `UnsupportedOperationError`
- Subclass that returns `nil`/`None` where the base guarantees a value
- Caller code that type-checks with `isinstance`/`type assertion` before calling methods

**Python example (violation):**
```python
class ReadOnlyRepository(Repository):
    def save(self, entity):
        raise NotImplementedError("This repository is read-only")  # LSP violation
```

**Python example (correct):**
```python
class ReadableRepository(ABC):
    @abstractmethod
    def find(self, id: int) -> Optional[Entity]: ...

class WritableRepository(ReadableRepository):
    @abstractmethod
    def save(self, entity: Entity) -> None: ...
```

**Go example (violation):**
```go
// Interface promises non-nil User; implementation returns nil without error
func (r *CachedUserRepo) FindByID(ctx context.Context, id int) (*User, error) {
    if r.cache == nil { return nil, nil } // caller expects (nil, error) OR (*User, nil)
}
```

**Severity:** 🟡 `[P2]` normally. If substitution causes runtime panics or data corruption = 🔴 `[P0]`.

---

## I — Interface Segregation Principle

> Clients should not be forced to depend on methods they do not use.

**Questions to ask:**
- Does any interface have methods that some implementations leave empty or panic on?
- Are interfaces defined at the provider rather than the consumer?
- Does a single interface serve multiple very different consumers?

**Signals of violation:**
- `UserRepository` with 15 methods; most services only use 2–3
- Implementing an interface just to satisfy a type constraint, with most methods as no-ops
- Importing a package just to use one function from a large interface

**Go example (violation):**
```go
type UserRepository interface {
    FindByID(ctx context.Context, id int) (*User, error)
    FindByEmail(ctx context.Context, email string) (*User, error)
    Save(ctx context.Context, user *User) error
    Delete(ctx context.Context, id int) error
    ListAll(ctx context.Context) ([]*User, error)
    Search(ctx context.Context, query string) ([]*User, error)
    CountByRole(ctx context.Context, role string) (int, error)
    // ... 8 more methods most callers never use
}
```

**Go example (correct — consumer-defined interfaces):**
```go
// In the auth package, define only what auth needs
type UserFinder interface {
    FindByEmail(ctx context.Context, email string) (*User, error)
}

// In the admin package, define only what admin needs
type UserLister interface {
    ListAll(ctx context.Context) ([]*User, error)
    CountByRole(ctx context.Context, role string) (int, error)
}
```

**TypeScript example (correct):**
```typescript
interface Readable<T> { findById(id: string): Promise<T | null> }
interface Writable<T> { save(entity: T): Promise<void>; delete(id: string): Promise<void> }
interface UserReader extends Readable<User> { findByEmail(email: string): Promise<User | null> }
```

**Severity:** 🟡 `[P2]`.

---

## D — Dependency Inversion Principle

> High-level modules must not depend on low-level modules. Both should depend on abstractions.

**Questions to ask:**
- Does business logic import concrete infrastructure types (DB clients, HTTP clients, file systems)?
- Are dependencies constructed inside the class rather than injected?
- Is it possible to unit test this code without spinning up infrastructure?

**Signals of violation:**
- `import "github.com/lib/pq"` inside a domain service
- `new(ConcreteEmailSender)` inside a constructor that should receive an interface
- Global singletons used inside business logic (`db.Query(...)` called directly)

**Go example (violation):**
```go
type OrderService struct {
    db *sql.DB // concrete dependency — hard to test, tight coupling
}
```

**Go example (correct):**
```go
type OrderRepository interface {
    Save(ctx context.Context, order Order) error
    FindByID(ctx context.Context, id int) (Order, error)
}

type OrderService struct {
    repo OrderRepository // depends on abstraction
}
```

**Python example (violation):**
```python
class ReportService:
    def generate(self, report_id: int) -> Report:
        db = psycopg2.connect(DATABASE_URL)  # concrete infra inside domain
        ...
```

**Python example (correct):**
```python
class ReportRepository(Protocol):
    def find(self, report_id: int) -> Optional[Report]: ...

class ReportService:
    def __init__(self, repo: ReportRepository) -> None:
        self.repo = repo
```

**TypeScript example (correct):**
```typescript
interface Logger { info(msg: string, meta?: object): void }

class OrderService {
  constructor(
    private repo: OrderRepository,  // abstraction
    private logger: Logger          // abstraction
  ) {}
}
```

**Severity:** 🟡 `[P2]`. If the tight coupling makes a bug unfixable without a large refactor = 🟠 `[P1]`.
