# Contributing to dev-skill

Thank you for wanting to extend this skill! The most common contribution is adding a new language or framework guide. This document explains exactly how to do that.

---

## Adding a New Language Guide

### Step 1 — Create the language file

Create a new file at:

```
references/language/<language-or-framework>.md
```

**Naming convention:**
- Use lowercase, hyphens for multi-word names
- Use the canonical technology name, not a brand name
- Examples: `react.md`, `vue.md`, `rust.md`, `swift.md`, `kotlin.md`, `java-spring.md`

### Step 2 — Required sections

Your language file must include all of the following sections (copy the structure from an existing guide like `go.md`):

| Section | Required content |
|---------|----------------|
| **Idioms** | Language-specific patterns the team should follow; common anti-patterns |
| **Error handling** | How errors/exceptions should be surfaced and wrapped; what to avoid |
| **Performance** | Common performance pitfalls unique to this language/runtime |
| **Security** | Language-specific security risks (e.g., unsafe deserialization, shell injection) |
| **Testing** | Test file conventions, recommended libraries, table-driven test patterns |

Each section should include:
- A clear rule or guideline
- A "violation" code example
- A "correct" code example
- A severity label (🔴 P0 / 🟠 P1 / 🟡 P2 / 🟢 P3)

### Step 3 — Register in `_index.md`

Open `references/language/_index.md` and add:

1. A row to the **Stack Fingerprints** table with the fingerprint file(s) and guide filename
2. An **Entry Point Patterns** section for your language/framework
3. A row to the **Test File Conventions** table

Example (adding React):

```markdown
## Stack Fingerprints (add this row)
| `src/App.tsx` or `vite.config.ts` | React/TypeScript | `references/language/react.md` |

## Entry Point Patterns (add this section)
### React
| Pattern | Purpose |
|---------|---------|
| `src/App.tsx`, `src/main.tsx` | Entry point |
| `src/components/**/*.tsx` | UI components |
| `src/hooks/**/*.ts` | Custom hooks |
| `src/pages/**/*.tsx` | Route-level pages |

## Test File Conventions (add this row)
| React | `*.test.tsx`, `*.spec.tsx` | `npm test` / `vitest` / `jest` |
```

### Step 4 — Add a tooling script (required)

Create `scripts/<language>-check.sh` following the existing scripts as a template. Each script must:

1. Output one line per tool in this format:
   ```
   TOOL: <tool-name>    STATUS: pass|fail|skip    DETAIL: <human-readable notes>
   ```
2. Use `pass` (exit 0, no issues), `fail` (issues found), or `skip` (tool not installed, optional only)
3. Mark required tools as `fail` with install instructions if missing (not `skip`)
4. Be executable standalone — no dependency on Claude or the skill runtime
5. Be runnable in CI as a pre-commit hook or in local dev

Add the script invocation to Phase 7 of `SKILL.md`:
```markdown
- <Language> → `bash code-review/scripts/<language>-check.sh`
```

---

### Step 5 — Update `SKILL.md` language table (if needed)

If your language guide uses a new fingerprint file not yet in the SKILL.md language table, add a row:

```markdown
| `vite.config.ts` | React/TypeScript | `references/language/react.md` |
```

---

## File Quality Standards

Before submitting your language guide, verify:

- [ ] All 5 required sections are present (Idioms, Error Handling, Performance, Security, Testing)
- [ ] Every rule has a violation example and a correct example
- [ ] Every finding has a severity label
- [ ] Code examples use the language's idiomatic style (not pseudo-code)
- [ ] The file references severity labels consistently (`🔴 [P0]`, `🟠 [P1]`, etc.)
- [ ] `_index.md` has been updated with fingerprints and entry points

---

## Severity Label Reference

| Label | Meaning |
|-------|---------|
| 🔴 `[P0]` | Critical — security, data loss, crash |
| 🟠 `[P1]` | High — logic error, reliability gap |
| 🟡 `[P2]` | Medium — design debt, test gap |
| 🟢 `[P3]` | Low — style, optional improvement |
| 💡 `[suggestion]` | Non-blocking idea |
| 📚 `[learning]` | Educational, no action needed |
| 🎉 `[praise]` | Positive acknowledgement |

---

## What Belongs in Quality vs Language References

| Content | Belongs in |
|---------|-----------|
| SOLID principles | `references/quality/solid-checklist.md` |
| OWASP-style security rules | `references/quality/security-checklist.md` |
| Naming, complexity, test coverage | `references/quality/code-quality-checklist.md` |
| Layer separation, API contracts | `references/quality/architecture-review-guide.md` |
| Language idioms, stdlib patterns | `references/language/<lang>.md` |
| Language-specific security (e.g., pickle) | `references/language/<lang>.md` (security section) |

If a rule applies to all languages equally, it belongs in `references/quality/`, not in a language file.

---

## Questions?

Open an issue or start a discussion in the repo. Include the language/framework you're adding and any questions about which sections apply.
