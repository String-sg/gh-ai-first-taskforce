---
theme: default
title: Example Deck
mermaid: true
---

# Example Deck

A sample slide to verify Slidev and Mermaid are working.

---

## Multi-Agent Workflow

```mermaid
graph LR
  A[PM — Generator] -->|PR| B[Pre-merge Audit Skill]
  B -->|gaps flagged| C[SWE — Evaluator]
  C -->|approved| D[Merge]
```

---

## Key Insight

- Generator and evaluator must be **separate contexts**
- Automation handles deterministic checks
- Human reviews accountability-sensitive decisions
