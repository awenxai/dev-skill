# Security Checklist

Reference for Phase 4 of the code review workflow. Security issues = 🔴 `[P0]`. Reliability gaps = 🟠 `[P1]`.

---

## Injection Vulnerabilities

### SQL Injection
Never interpolate user input into SQL strings. Always use parameterized queries or prepared statements.

**Go (violation):**
```go
query := fmt.Sprintf("SELECT * FROM users WHERE email = '%s'", email) // INJECTION
rows, err := db.QueryContext(ctx, query)
```

**Go (correct):**
```go
rows, err := db.QueryContext(ctx, "SELECT * FROM users WHERE email = $1", email)
```

**Python (violation):**
```python
cursor.execute(f"SELECT * FROM orders WHERE id = {order_id}")  # INJECTION
```

**Python (correct):**
```python
cursor.execute("SELECT * FROM orders WHERE id = %s", (order_id,))
```

**TypeScript (violation):**
```typescript
const result = await db.query(`SELECT * FROM users WHERE id = ${req.params.id}`) // INJECTION
```

**TypeScript (correct — Prisma/parameterized):**
```typescript
const user = await prisma.user.findUnique({ where: { id: userId } })
// Or for raw: db.query('SELECT * FROM users WHERE id = $1', [userId])
```

**Severity:** 🔴 `[P0]`

---

### Command Injection
User input must never reach shell execution without strict sanitization.

**Go (violation):**
```go
exec.Command("sh", "-c", "convert "+userInput).Run() // INJECTION
```

**Go (correct):**
```go
exec.Command("convert", userInput).Run() // args array — no shell interpolation
```

**Python (violation):**
```python
os.system(f"ffmpeg -i {filename} output.mp4")     # INJECTION
subprocess.run(f"ls {directory}", shell=True)      # INJECTION
```

**Python (correct):**
```python
subprocess.run(["ffmpeg", "-i", filename, "output.mp4"], check=True)
subprocess.run(["ls", directory], check=True)
```

**Severity:** 🔴 `[P0]`

---

### Path Traversal
Validate and sanitize file paths to prevent directory traversal.

**Go (violation):**
```go
http.ServeFile(w, r, "/var/uploads/"+r.URL.Query().Get("file")) // traversal: ../../etc/passwd
```

**Go (correct):**
```go
filename := filepath.Clean(r.URL.Query().Get("file"))
if strings.HasPrefix(filename, "..") { http.Error(w, "invalid", 400); return }
http.ServeFile(w, r, filepath.Join("/var/uploads", filename))
```

**Severity:** 🔴 `[P0]`

---

### Template Injection
Never render user-supplied data as templates.

**Go (violation):**
```go
tmpl, _ := template.New("t").Parse(userInput) // executes arbitrary Go template directives
```

**Python (violation):**
```python
Template(user_input).render(**context)  # Jinja2/Mako with user-controlled template string
```

**Severity:** 🔴 `[P0]`

---

## Authentication & Authorization

### Missing Authorization Guards
Every non-public endpoint must verify both identity (AuthN) and permission (AuthZ).

**Checklist:**
- [ ] Does each handler verify a valid, unexpired token/session?
- [ ] Is the resource owner checked, not just authentication? (IDOR risk)
- [ ] Are admin/privileged routes behind a role check?
- [ ] Are failed auth checks returning immediately with `401`/`403` (not silently continuing)?

**Go (IDOR violation):**
```go
func (h *Handler) GetOrder(w http.ResponseWriter, r *http.Request) {
    id := chi.URLParam(r, "id")
    order, _ := h.repo.FindByID(r.Context(), id)
    // No check that order.UserID == currentUser.ID — IDOR
    json.NewEncoder(w).Encode(order)
}
```

**Severity:** 🔴 `[P0]` (missing AuthZ) / 🟠 `[P1]` (weak AuthZ)

---

### JWT Validation
All JWT claims must be validated — not just decoded.

**Checklist:**
- [ ] Signature verified with the correct key
- [ ] `exp` claim checked (token not expired)
- [ ] `iss` and `aud` claims checked if applicable
- [ ] Algorithm explicitly specified (reject `alg: none`)

**Go (violation):**
```go
token, _ := jwt.Parse(tokenStr, func(t *jwt.Token) (interface{}, error) {
    return []byte("secret"), nil // accepts any algorithm including "none"
})
```

**Go (correct):**
```go
token, err := jwt.Parse(tokenStr, func(t *jwt.Token) (interface{}, error) {
    if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
        return nil, fmt.Errorf("unexpected signing method: %v", t.Header["alg"])
    }
    return jwtSecret, nil
}, jwt.WithExpirationRequired())
```

**Severity:** 🔴 `[P0]`

---

## Secrets Management

### Hardcoded Credentials
Secrets must never appear in source code, logs, or version control.

**Patterns to flag:**
- API keys, tokens, passwords assigned to string literals
- Connection strings containing credentials inline
- Private keys or certificates committed to the repo
- Secrets interpolated into log messages

**Go (violation):**
```go
const jwtSecret = "super-secret-key-1234"   // HARDCODED
db, _ := sql.Open("postgres", "postgres://admin:password@localhost/prod") // HARDCODED
```

**Python (violation):**
```python
STRIPE_KEY = "sk_live_abc123xyz"             # HARDCODED
logger.info(f"Auth with token: {api_token}") # LEAKS TO LOG
```

**Correct pattern (all languages):** Use environment variables or a secrets manager.
```go
jwtSecret := os.Getenv("JWT_SECRET") // or from Vault/AWS Secrets Manager
```

**Severity:** 🔴 `[P0]`

---

## Insecure Deserialization

### Python: pickle / yaml.load
`pickle` and `yaml.load` execute arbitrary code from untrusted input.

```python
# DANGEROUS
data = pickle.loads(request.data)
config = yaml.load(user_input)          # must be yaml.safe_load

# Correct
config = yaml.safe_load(user_input)
# For user data: use json.loads or Pydantic validation instead of pickle
```

**Severity:** 🔴 `[P0]`

### Go: Unmarshaling into interface{}
Avoid unmarshaling untrusted JSON into `interface{}` then type-asserting without validation.

```go
// Risky: no schema validation
var data interface{}
json.Unmarshal(body, &data)

// Correct: use a typed struct with validation
var req CreateOrderRequest
if err := json.Unmarshal(body, &req); err != nil { ... }
if err := validate.Struct(req); err != nil { ... }
```

**Severity:** 🟠 `[P1]`

---

## Cryptography

### Weak Hash Algorithms
Do not use MD5 or SHA-1 for security-sensitive purposes (passwords, signatures, integrity checks).

```go
// WEAK — do not use for passwords or integrity
h := md5.Sum(data)
h := sha1.Sum(data)

// Correct — use SHA-256+ for integrity, bcrypt/argon2 for passwords
import "golang.org/x/crypto/bcrypt"
hash, _ := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
```

**Severity:** 🔴 `[P0]` for passwords; 🟠 `[P1]` for integrity hashes

### Predictable Random Numbers
Use cryptographically secure random sources for tokens, nonces, and IDs.

```go
// WEAK — predictable
rand.Seed(time.Now().UnixNano())
token := rand.Int63()

// Correct
import "crypto/rand"
b := make([]byte, 32)
rand.Read(b)
token := hex.EncodeToString(b)
```

```python
# WEAK
import random; token = random.randint(0, 1<<32)

# Correct
import secrets; token = secrets.token_urlsafe(32)
```

**Severity:** 🔴 `[P0]`

---

## Language-Specific Security Notes

### Go
- **Goroutine leaks:** ensure goroutines respect `context.Done()` to avoid leaks under cancellation
- **Race conditions:** shared state accessed from multiple goroutines must use `sync.Mutex` or channels
- **`defer` in loops:** `defer` inside a loop doesn't run until function return — may hold resources too long
- Use `golangci-lint` with `gosec` linter for automated scanning

### Python
- **`subprocess.run` with `shell=True`:** always avoid when input is not fully controlled
- **`eval` / `exec`:** never call with untrusted input
- **Django:** use `request.user.has_perm()` for AuthZ; never trust `request.POST` directly without form validation
- **SQLAlchemy:** use `.filter()` with bound parameters; avoid raw `text()` with string interpolation

### TypeScript / Node.js
- **`helmet`:** use on all Express/Fastify apps to set security headers
- **`express-rate-limit`:** apply to auth endpoints to prevent brute force
- **CORS:** explicitly whitelist origins; never use `origin: '*'` in production for credentialed requests
- **Parameterized queries:** use `pg` prepared statements or an ORM; no template literals in SQL
- **`JSON.parse` without validation:** wrap in `try/catch` and validate with Zod/Joi before using
- **Prototype pollution:** avoid `Object.assign({}, req.body)` with untrusted deep-merged objects

---

## Reliability Gaps (P1)

- Unhandled errors that leave the system in a partially-committed state
- Missing transaction rollback on error paths
- Database connections not released on error (missing `defer rows.Close()`, `defer tx.Rollback()`)
- Retry logic without exponential backoff or circuit breaker — amplifies cascading failures
- Timeout not set on outbound HTTP calls — can block goroutines/threads indefinitely
- Panic recovery missing in goroutines / background workers

**Go reliability pattern:**
```go
ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
defer cancel()

tx, err := db.BeginTx(ctx, nil)
if err != nil { return err }
defer tx.Rollback() // safe no-op if committed

// ... do work ...

return tx.Commit()
```
