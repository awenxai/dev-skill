# dev-skill

A curated collection of Claude Code skills for our backend development team. The goal is simple: keep our engineering standards in one place so every developer on the team — regardless of experience level — has a knowledgeable, consistent second pair of eyes built into their workflow.

Skills here cover the things that matter most to us: code quality, security, architecture discipline, and language idioms. As our practices evolve, so does this repo.

---

## Motivation

Good output from a dev team doesn't happen by accident. It comes from shared standards, enforced consistently, without slowing anyone down. These skills are our attempt to encode what "good" looks like for us — not as a wall of wiki pages nobody reads, but as active assistants that show up exactly when you need them.

> Inspired by [awesome-skills/code-review-skill](https://github.com/awesome-skills/code-review-skill) and [sanyuan0704/code-review-expert](https://github.com/sanyuan0704/code-review-expert). We merged their best ideas — structured workflow, precise severity levels, collaborative tone — and shaped them around our stack and the way our team actually works.

---

## Skills

| Directory | Skill | Description |
|-----------|-------|-------------|
| [`code-review/`](code-review/) | `code-review` | 7-phase code review with P0–P3 severity matrix. Covers Go, Python, TypeScript/Node.js. |

More skills will be added here as we identify patterns worth standardizing across the team.

---

## Installation

### Install a single skill

```bash
cp -r code-review/ ~/.claude/skills/code-review/
```

### Install all skills

```bash
for skill in */; do cp -r "$skill" ~/.claude/skills/"${skill%/}"/; done
```

---

## Repository structure

```
dev-skill/
├── README.md          ← this file
└── code-review/       ← code-review skill
    ├── SKILL.md
    ├── CONTRIBUTING.md
    ├── assets/
    │   └── review-output-template.md
    └── references/
        ├── quality/
        │   ├── architecture-review-guide.md
        │   ├── solid-checklist.md
        │   ├── security-checklist.md
        │   └── code-quality-checklist.md
        └── language/
            ├── _index.md
            ├── go.md
            ├── python.md
            └── typescript-nodejs.md
# Future: pr-summary/, commit-helper/, test-generator/, etc.
```

---

## Adding a new skill

1. Create a new directory: `mkdir <skill-name>/`
2. Add `SKILL.md` with frontmatter (`name`, `description`, `allowed-tools`) and the skill prompt
3. Add any reference files the skill loads at runtime
4. Add a row to the **Skills** table above
5. Document installation in the skill's own `README.md` or `CONTRIBUTING.md`
