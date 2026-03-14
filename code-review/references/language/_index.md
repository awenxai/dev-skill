# Language Stack Index

Used in Phase 1 to auto-detect the language stack and determine which language guide to load in Phase 5.

---

## Stack Fingerprints

Scan the repo root (and common subdirectories) for these files in order:

| Fingerprint file | Language/Stack | Guide to load |
|-----------------|---------------|--------------|
| `go.mod` | Go | `references/language/go.md` |
| `pyproject.toml` | Python | `references/language/python.md` |
| `requirements.txt` (without `pyproject.toml`) | Python | `references/language/python.md` |
| `setup.py` (without `pyproject.toml`) | Python | `references/language/python.md` |
| `tsconfig.json` | TypeScript/Node.js | `references/language/typescript-nodejs.md` |
| `package.json` (without `tsconfig.json`) | JavaScript/Node.js | `references/language/typescript-nodejs.md` |

**Multiple stacks in one repo:** Load all matching language guides. Note the multi-stack nature in the Phase 1 summary.

**Unrecognized stack:** Note in the Phase 1 summary: "Language-specific rules not available for [stack]. Phase 5 will apply cross-language quality checks only." Do not load a language guide.

---

## How to detect the stack (Phase 1 procedure)

```bash
# Check for Go
ls go.mod 2>/dev/null && echo "Go"

# Check for Python
ls pyproject.toml requirements.txt setup.py 2>/dev/null

# Check for TypeScript/Node.js
ls tsconfig.json package.json 2>/dev/null
```

Or use Glob to search:
- Go: `**/go.mod`
- Python: `**/pyproject.toml`, `**/requirements.txt`
- TypeScript: `**/tsconfig.json`

---

## Entry Point Patterns

Use these to quickly orient the review to the right files:

### Go
| Pattern | Purpose |
|---------|---------|
| `cmd/*/main.go` or `main.go` | Application entry point |
| `internal/*/handler*.go` | HTTP handlers |
| `internal/*/router*.go` or `routes.go` | Route registration |
| `internal/*/service*.go` | Business logic |
| `internal/*/repository*.go` or `*_repo.go` | Data access |
| `internal/*/middleware*.go` | HTTP middleware |
| `pkg/` | Shared/reusable packages |

### Python
| Pattern | Purpose |
|---------|---------|
| `app/main.py`, `src/main.py`, `wsgi.py`, `asgi.py` | Entry point |
| `app/routers/*.py`, `app/views/*.py` | Route handlers |
| `app/services/*.py` | Business logic |
| `app/repositories/*.py`, `app/models/*.py` | Data access |
| `app/schemas/*.py` | Request/response schemas (Pydantic) |
| `alembic/versions/` | DB migrations |

### TypeScript/Node.js
| Pattern | Purpose |
|---------|---------|
| `src/index.ts`, `src/server.ts`, `src/app.ts` | Entry point |
| `src/routes/*.ts`, `src/controllers/*.ts` | Route handlers |
| `src/services/*.ts` | Business logic |
| `src/repositories/*.ts`, `src/models/*.ts` | Data access |
| `src/middleware/*.ts` | Express/Fastify middleware |
| `prisma/migrations/` or `migrations/` | DB migrations |

---

## Test File Conventions

| Stack | Test file pattern | Test command |
|-------|-----------------|-------------|
| Go | `*_test.go` (same directory) | `go test ./...` |
| Go (integration) | `*_test.go` with `//go:build integration` tag | `go test -tags integration ./...` |
| Python | `test_*.py` or `*_test.py` in `tests/` | `pytest` |
| Python (fixtures) | `conftest.py` | loaded automatically by pytest |
| TypeScript | `*.spec.ts` or `*.test.ts` | `npm test` / `jest` / `vitest` |
| TypeScript (e2e) | `*.e2e-spec.ts`, `test/*.ts` | `npm run test:e2e` |

---

## Migration File Patterns

| Stack | Migration tool | File pattern |
|-------|--------------|-------------|
| Go | golang-migrate | `migrations/*.up.sql` + `*.down.sql` |
| Go | Goose | `migrations/YYYYMMDDHHMMSS_*.go` or `.sql` |
| Python | Alembic | `alembic/versions/*.py` |
| Python | Django | `app/migrations/NNNN_*.py` |
| TypeScript | Prisma | `prisma/migrations/*/migration.sql` |
| TypeScript | TypeORM | `src/migrations/*.ts` |
| TypeScript | Knex | `migrations/*.js` / `*.ts` |

When a migration file appears in the diff, always run the **Database Migrations** checklist from `references/quality/architecture-review-guide.md`.

---

## Adding a New Language

To add a new language guide (e.g., React, Swift, Rust):

1. Create `references/language/<language>.md` (see CONTRIBUTING.md for required sections)
2. Add a fingerprint row to the **Stack Fingerprints** table above
3. Add entry point patterns to the relevant section
4. Add test file conventions to the table
5. Update `SKILL.md` Language Table if needed
