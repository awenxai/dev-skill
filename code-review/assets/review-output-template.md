# Code Review Output Template

Copy this template when producing the Phase 8 findings report. Replace all `{{placeholder}}` tokens.
Delete sections that have no findings (e.g., remove the P0 section if there are no critical issues).

---

## Code Review — {{YYYY-MM-DD}} — {{branch-name or PR title}}

### Summary

| Field | Value |
|-------|-------|
| Files changed | {{N}} |
| Lines added | +{{N}} |
| Lines removed | -{{N}} |
| Stack | {{Go / Python / TypeScript/Node.js}} |
| Change type | {{feature / bugfix / refactor / config / infra / docs}} |
| Risk level | {{Low / Medium / High}} |
| Reviewer | Claude {{model-version}} |

---

### Findings

#### 🔴 Critical — Block Merge (P0)

> Security vulnerabilities, data loss, or crash-inducing bugs.

- 🔴 `[P0]` `{{path/to/file.ext:LINE}}` — {{description of issue}}
  **Recommendation:** {{what to do to fix it}}

<!-- Add more P0 items or delete this section if none -->

---

#### 🟠 High — Block Merge (P1)

> Logic errors, missing error handling, performance regressions.

- 🟠 `[P1]` `{{path/to/file.ext:LINE}}` — {{description of issue}}
  **Recommendation:** {{what to do to fix it}}

<!-- Add more P1 items or delete this section if none -->

---

#### 🟡 Medium — Fix Before Next Sprint (P2)

> SOLID violations, test gaps, design debt.

- 🟡 `[P2]` `{{path/to/file.ext:LINE}}` — {{description of issue}}
  **Recommendation:** {{what to do to fix it}}

<!-- Add more P2 items or delete this section if none -->

---

#### 🟢 Low / NIT (P3)

> Style, naming, minor improvements. Optional.

- 🟢 `[P3]` `{{path/to/file.ext:LINE}}` — {{description of issue}}
  **Recommendation:** {{what to do to fix it}}

<!-- Add more P3 items or delete this section if none -->

---

#### 💡 Suggestions

> Non-blocking alternative approaches or ideas.

- 💡 `[suggestion]` `{{path/to/file.ext:LINE}}` — {{description of suggestion}}

---

#### 🎉 Praise

> Acknowledge genuinely good work.

- 🎉 `[praise]` `{{path/to/file.ext:LINE}}` — {{what was done well and why it matters}}

---

### Tooling Results

> Populated from Phase 7 script output. Omit rows for tools not applicable to this stack.

| Tool | Status | Notes |
|------|--------|-------|
| `go build` | ✅ pass / ❌ fail / ⚠️ not available | {{details or N/A}} |
| `go vet` | ✅ pass / ❌ fail | {{N issues found}} |
| `go test` | ✅ pass / ❌ fail | {{N failed / N passed}} |
| `go test -race` | ✅ pass / ❌ fail | {{details}} |
| `goimports` | ✅ clean / ❌ fail / ⚠️ not available | {{files with drift}} |
| `golangci-lint` | ✅ pass / ❌ fail / ⚠️ not available | {{N issues}} |

<!-- Replace rows above with the tools relevant to the detected language stack. -->

---

### Metrics

| Category | Count |
|----------|-------|
| 🔴 P0 Critical | {{N}} |
| 🟠 P1 High | {{N}} |
| 🟡 P2 Medium | {{N}} |
| 🟢 P3 Low | {{N}} |
| 💡 Suggestions | {{N}} |
| 🎉 Praise | {{N}} |

**Merge recommendation:** {{BLOCK / APPROVE WITH COMMENTS / APPROVE}}

> BLOCK = any P0 or P1 findings present
> APPROVE WITH COMMENTS = only P2/P3 findings
> APPROVE = no findings or praise/suggestions only

---

*Reviewed by Claude {{model-version}} on {{YYYY-MM-DD}}*
*Skill: dev-skill/code-review*

---

**Review complete.** Which findings would you like me to implement?
Options: "fix all", "fix P0 and P1", "fix {{specific finding}}", "skip — just the review", or list specific line references.
I will not make any code changes until you confirm.
