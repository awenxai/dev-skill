# TypeScript / Node.js Language Guide

Reference for Phase 5 of the code review workflow. Load this file when the stack fingerprint includes `tsconfig.json` or `package.json`.

---

## Type Safety

### Rules
- **No `any`** — use `unknown` for untrusted external data, then narrow with type guards or validation libraries.
- **Strict null checks** — `tsconfig.json` must have `"strictNullChecks": true`. Flag code that assumes values are non-null without proof.
- **Non-null assertion `!`** — flag every use; most can be replaced with a proper null check or type guard.
- **Type assertions `as T`** — flag when used to silence TS errors rather than to genuinely narrow types.

```typescript
// VIOLATION — any escapes the type system entirely
function processRequest(req: any) {
  return req.body.user.email  // no safety
}

// CORRECT — unknown + validation
import { z } from 'zod'
const CreateUserSchema = z.object({
  email: z.string().email(),
  name: z.string().min(1),
})

function processRequest(req: Request) {
  const body = CreateUserSchema.parse(req.body)  // throws ZodError if invalid
  return body.email  // typed: string
}
```

```typescript
// VIOLATION — non-null assertion hides potential runtime error
const user = users.find(u => u.id === id)!
console.log(user.name)  // crashes if not found

// CORRECT
const user = users.find(u => u.id === id)
if (!user) throw new NotFoundError(`User ${id} not found`)
console.log(user.name)
```

**Severity:** `any` in security/validation code = 🟠 `[P1]`. `any` in internal code = 🟡 `[P2]`. Non-null assertion = 🟡 `[P2]`.

---

## Promise Handling

### Rules
- Every `Promise` must be `await`ed or have `.catch()` attached — no floating promises.
- Prefer `Promise.allSettled()` over `Promise.all()` when partial success is acceptable.
- `async` functions in Express/Fastify must have their errors caught — either via wrapper or explicit try/catch.

```typescript
// VIOLATION — floating promise: rejection is silently swallowed
function handleRequest(req, res) {
  doAsyncWork()  // not awaited, error is lost
  res.json({ ok: true })
}

// VIOLATION — Promise.all fails fast, losing successful results
const results = await Promise.all(items.map(i => processItem(i)))
// If one item fails, all results are lost

// CORRECT — Promise.allSettled for partial success
const results = await Promise.allSettled(items.map(i => processItem(i)))
const succeeded = results.filter(r => r.status === 'fulfilled').map(r => r.value)
const failed = results.filter(r => r.status === 'rejected')
```

```typescript
// VIOLATION — async handler without error handling in Express
app.get('/orders', async (req, res) => {
  const orders = await orderService.findAll()  // unhandled rejection crashes process
  res.json(orders)
})

// CORRECT — wrapper or try/catch
const asyncHandler = (fn: RequestHandler): RequestHandler =>
  (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next)

app.get('/orders', asyncHandler(async (req, res) => {
  const orders = await orderService.findAll()
  res.json(orders)
}))
```

**Severity:** Unhandled promise rejection = 🟠 `[P1]`. Missing error middleware for async routes = 🟠 `[P1]`.

---

## Error Handling Middleware

### Express
```typescript
// Error middleware MUST have 4 parameters — Express detects this signature
app.use((err: Error, req: Request, res: Response, next: NextFunction) => {
  const status = err instanceof AppError ? err.statusCode : 500
  const message = err instanceof AppError ? err.message : 'Internal server error'

  logger.error('Unhandled error', {
    error: err.message,
    stack: err.stack,
    path: req.path,
    method: req.method,
  })

  res.status(status).json({ error: message })
})
```

### Fastify
```typescript
fastify.setErrorHandler((error, request, reply) => {
  const status = error.statusCode ?? 500
  reply.status(status).send({ error: error.message })
})
```

### NestJS
Use `ExceptionFilter` with `@Catch()` decorator. Ensure `HttpExceptionFilter` is applied globally.

**Flag when:**
- No error middleware is registered in an Express/Fastify app
- Error middleware is registered before routes (must be after all routes)
- Error middleware has only 3 parameters (Express won't treat it as error middleware)

**Severity:** Missing error middleware = 🟠 `[P1]`.

---

## Input Validation

All external input (request body, query params, path params, headers) must be validated before use.

### Preferred libraries
- **Zod** — schema-first, TypeScript-native, excellent error messages
- **Joi** — mature, runtime validation, less TypeScript-integrated
- **class-validator** — decorator-based, good for NestJS DTOs

```typescript
// Zod — validates AND types the data
import { z } from 'zod'

const CreateOrderSchema = z.object({
  userId: z.string().uuid(),
  items: z.array(z.object({
    productId: z.string().uuid(),
    quantity: z.number().int().positive(),
  })).min(1),
  discountCode: z.string().optional(),
})

type CreateOrderDto = z.infer<typeof CreateOrderSchema>

async function createOrder(req: Request, res: Response) {
  const dto = CreateOrderSchema.parse(req.body)  // throws ZodError on invalid input
  const order = await orderService.create(dto)
  res.status(201).json(order)
}
```

**Flag when:**
- `req.body` fields are accessed without prior validation
- `req.params.id` is passed directly to a DB query without parsing/validation
- Validation is present but errors are not handled (try/catch missing around `.parse()`)

**Severity:** Missing validation on user input = 🟠 `[P1]`. Missing validation on DB-bound values = 🔴 `[P0]`.

---

## Security Headers & Middleware

### helmet
Every Express/Fastify app must use `helmet` (or equivalent) to set security headers.

```typescript
import helmet from 'helmet'
app.use(helmet())  // sets CSP, HSTS, X-Frame-Options, etc.
```

**Flag:** App without `helmet` or equivalent = 🟡 `[P2]`.

### Rate limiting
Authentication and sensitive endpoints must have rate limiting.

```typescript
import rateLimit from 'express-rate-limit'

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,  // 15 minutes
  max: 10,                    // 10 attempts per window
  message: { error: 'Too many attempts, try again later' },
})

app.post('/auth/login', authLimiter, loginHandler)
```

**Flag:** Auth endpoint without rate limit = 🟡 `[P2]`.

### CORS
```typescript
import cors from 'cors'

// VIOLATION — allows all origins in production
app.use(cors({ origin: '*', credentials: true }))  // credentials + wildcard is rejected by browsers anyway

// CORRECT
app.use(cors({
  origin: process.env.ALLOWED_ORIGINS?.split(',') ?? [],
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE'],
}))
```

**Flag:** `origin: '*'` with `credentials: true` = 🟠 `[P1]`. Missing CORS config = 🟡 `[P2]`.

---

## Event Loop Blocking

Node.js is single-threaded — blocking the event loop stalls all requests.

### Rules
- No synchronous file I/O in request handlers (`fs.readFileSync`, `fs.writeFileSync`)
- No CPU-intensive work in the main thread (parsing huge files, complex crypto)
- No `JSON.parse` on very large payloads (> 10MB) without streaming

```typescript
// VIOLATION — blocks event loop for all concurrent requests
app.get('/report', (req, res) => {
  const data = fs.readFileSync('/var/data/report.csv', 'utf-8')  // BLOCKING
  res.send(data)
})

// CORRECT
app.get('/report', async (req, res) => {
  const data = await fs.promises.readFile('/var/data/report.csv', 'utf-8')
  res.send(data)
})

// For CPU-intensive work: use worker_threads
import { Worker } from 'worker_threads'
```

**Severity:** Sync I/O in request handler = 🟠 `[P1]`. CPU-intensive work in main thread = 🟠 `[P1]`.

---

## Database & Connection Pooling

### Rules
- Use a connection pool — never create a new connection per request.
- Always release connections in `finally` blocks or use connection pool APIs that auto-release.
- Parameterized queries only — no string interpolation in SQL.

```typescript
// VIOLATION — new connection per request
app.get('/users', async (req, res) => {
  const client = new pg.Client(connectionString)  // new connection!
  await client.connect()
  const result = await client.query('SELECT * FROM users')
  await client.end()
  res.json(result.rows)
})

// CORRECT — shared pool
const pool = new pg.Pool({ connectionString, max: 10 })

app.get('/users', async (req, res) => {
  const result = await pool.query('SELECT * FROM users WHERE active = $1', [true])
  res.json(result.rows)
})
```

**Severity:** Connection per request = 🟠 `[P1]`. SQL injection via string interpolation = 🔴 `[P0]`.

---

## Common TypeScript/Node.js Anti-Patterns

| Anti-pattern | Correct approach | Severity |
|-------------|-----------------|---------|
| `any` type | `unknown` + type guards / Zod | 🟡 P2 |
| Non-null assertion `!` | Null check + early return | 🟡 P2 |
| Floating promise (no await/catch) | `await` or `.catch()` | 🟠 P1 |
| `Promise.all` without allSettled | `Promise.allSettled` where appropriate | 🟡 P2 |
| `req.body` used without validation | Zod/Joi schema validation | 🟠 P1 |
| `fs.readFileSync` in request handler | `fs.promises.readFile` | 🟠 P1 |
| No error middleware | Add 4-param error handler | 🟠 P1 |
| `console.log` in production paths | Structured logger (winston, pino) | 🟡 P2 |
| `origin: '*'` + credentials | Explicit origin whitelist | 🟠 P1 |
| No `helmet` | Add `helmet()` middleware | 🟡 P2 |
| New DB connection per request | Shared connection pool | 🟠 P1 |
| SQL string interpolation | Parameterized queries | 🔴 P0 |
