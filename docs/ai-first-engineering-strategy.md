# AI-First Engineering Strategy

How engineering teams move toward an AI-first way of working — and how to do it safely.

This is a practitioner's strategy. It is written for the people doing the work: SWEs, PMs, DevOps, and non-engineer practitioners building production software with Claude Code. It names and connects the practices, skills, and guardrails already in this repo, and points where they are heading.

Parts 1–2 are for **practitioners** adopting AI-first ways of working. **Part 3** is for the **taskforce and contributors** who build and maintain the toolkit those teams rely on.

> **Core thesis:** Move from *human-drives / AI-assists* toward *AI-drives / human-verifies*. What makes that shift safe is **guardrails and verification — not blind trust.** Every stage of this strategy adds autonomy only after adding the guardrail that makes the autonomy safe.

---

# Part 1 — Roadmap

## 1. Why AI-first

AI can now do the bulk of the build loop — drafting issues, writing code, reviewing diffs, fixing what it finds. The bottleneck is no longer typing speed; it is **direction and verification**. Teams that win treat AI as the default builder and reinvest their human time into deciding *what* to build and confirming it was built correctly.

The risk is equally real: an AI that moves fast with no guardrails ships secrets, pulls in compromised dependencies, and produces plausible-but-wrong code at a rate no human reviewer can catch by reading alone. So the strategy is not "use more AI." It is "**increase AI autonomy and increase verification together**, one notch at a time."

## 2. The maturity model

Three stages. They describe the relationship between the human and the AI, not a tooling checklist. A team can be at different stages for different repos — that is fine. Use the hallmark to self-locate.

| Stage | What it means | Hallmark |
|---|---|---|
| **Co-pilot** | AI as an assistant. Individuals use Claude Code ad-hoc; humans drive, AI suggests. Guardrails are manual. | *"I ask the AI, then I do it."* |
| **Co-create** | AI as a building partner. Shared skills + `CLAUDE.md` live in the repo; AI drafts issues, implements, and reviews against agreed rules. Guardrails are wired in — hooks, cooldowns, review skills. | *"Our repo has skills and rules the whole team relies on."* |
| **Delegate** | AI runs the loop. AI drives issue → implement → review → fix; humans set direction and verify/approve. Trials feed gaps back into the skills; measurement is routine. | *"Humans set direction and verify; AI does the build loop."* |

**How to self-locate:** read the hallmarks and pick the one that sounds like a normal day on the repo in question. If your guardrails are still in your head rather than in the repo, you are at Co-pilot regardless of how much AI you use.

## 3. The adoption loop

Moving a repo up a stage is itself a repeatable loop — the same loop the taskforce uses to run trials:

1. **Pilot** the next-stage practice on a real piece of work (a trial, a feature branch). Don't roll it out broadly first.
2. **Wire the guardrail** that makes the new autonomy safe *before* relying on the autonomy — the hook, the review skill, the cooldown, the classification check.
3. **Measure** against the signals in Chapter 7 so you know the change helped.
4. **Feed gaps back** — when the AI does something the rules should have caught, capture it (in a trial's gaps log or the project's own backlog), then harden the `CLAUDE.md` rule or the skill so it can't recur. This is how the team's guardrails compound over time.

The loop never ends. Even a Delegate-stage repo keeps finding gaps and feeding them back — that is what keeps delegation safe.

---

# Part 2 — Playbook

Each practice below is tagged with the stage it belongs to: **[Co-pilot]**, **[Co-create]**, **[Delegate]**. Adopt the lower-stage practices first; they are the foundation the higher stages stand on.

## 4. SDLC workflow

AI across the dev lifecycle, mapped to the skills in this repo. The progression in each step is the same: a human does it with AI help, then the AI does it against shared rules, then the AI does it and a human verifies the output.

### Plan & scope
- **[Co-pilot]** Use the AI to think through an idea before writing it down. The `brainstorming` skill turns a rough idea into an agreed design before any code.
- **[Co-create]** Draft issues with `aif-create-issue` so every issue has a complete author and implementer section a coding agent can act on. Break large issues into atomic, single-PR pieces with `aif-split-issue`.
- **[Delegate]** Feed a goal in; let the AI propose the issue breakdown and you approve the scope, not the prose.

### Implement
- **[Co-pilot]** Pair with the AI on a branch; you keep your hand on each change.
- **[Co-create]** Run `aif-implement-issue` against a well-formed issue so implementation follows the repo's `CLAUDE.md` rules.
- **[Delegate]** Let the AI implement an approved issue end-to-end on its own branch; you review the resulting PR, not each keystroke.

### Review
- **[Co-pilot]** Ask the AI to review your diff before you push.
- **[Co-create]** Run `aif-code-review` on the branch — interactive local review or inline PR comments — against agreed standards.
- **[Delegate]** Make AI review a standing gate on every PR; humans adjudicate findings rather than hunt for them.

### Quality gates
- **[Co-create]** Set up linting/formatting with `aif-lint-setup`, then wire those checks into git hooks with `aif-git-hooks-setup` so nothing reaches `main` un-linted. Keep dependencies safe with `aif-update-npm-dependencies`.
- **[Delegate]** Gates run automatically on every change; a failed gate blocks the AI's own loop, not just the human's.

### Maintain
- **[Co-create]** Keep dependencies current and safe on a cadence with `aif-update-npm-dependencies` (7-day release cooldown — see Chapter 5).
- **[Delegate]** Schedule routine maintenance (audits, dependency bumps, doc refreshes) as recurring AI tasks with human sign-off on the result.

**What good looks like:** at Co-create, every step of your lifecycle has a named skill the whole team uses. At Delegate, a single approved goal can travel the whole loop with humans appearing only at the verify points.

## 5. Guardrails & trust

Guardrails are the price of autonomy. You earn the right to delegate by making the dangerous things impossible, not by hoping the AI behaves.

- **Verify before "done." [Co-pilot]** Never accept "it works" without evidence — run the command, read the output. Treat a success claim with no supporting output as unverified. (`verification-before-completion`.)
- **Review discipline. [Co-create]** A diff is reviewed by a skill against written standards, not skimmed. The human's job is to adjudicate findings, not to be the first line of detection.
- **Dependency cooldown. [Co-create]** Only adopt JavaScript dependency versions that are **≥ 7 days old**, so freshly-published malicious versions are caught before they reach your lockfile. `aif-update-npm-dependencies` enforces this automatically.
- **Secrets & hooks. [Co-create]** Scan staged changes for secrets and block direct pushes to `main` via pre-commit/pre-push hooks (this repo uses Lefthook + gitleaks). Guardrails in the repo beat guardrails in someone's memory.
- **Data sensitivity. [Co-create → Delegate]** Before code or data reaches an external model, know its classification. Match the work to an eligible environment (e.g. OPEN / OFFICIAL / OFFICIAL-CLOSED), and for restricted projects explore local-only scanning or data-masking before anything leaves the device.

**What good looks like:** every new autonomy you grant the AI has a corresponding guardrail in the repo. If you can't name the guardrail, you're not ready for the autonomy.

## 6. Roles & ways of working

AI-first doesn't remove roles; it moves each role *up the value chain* — from doing the work to directing and verifying it.

| Role | Co-pilot | Co-create | Delegate |
|---|---|---|---|
| **SWE** | Codes with AI help | Maintains the repo's skills, `CLAUDE.md`, and gates; reviews AI commits on a cadence | Sets technical direction; verifies and approves; hardens guardrails from gaps |
| **PM / practitioner** | Asks AI to draft and explain | Writes well-formed issues the AI can implement | Defines goals and acceptance; approves scope and outcomes |
| **DevOps** | Scripts with AI help | Wires hooks, CI gates, environment guardrails | Owns the automated gates that let the AI's loop run safely |

Cross-cutting ways of working:
- **Human-in-the-loop is non-negotiable.** Autonomy increases; accountability does not move. A human owns every merge to `main`.
- **Review cadence. [Co-create]** Daily async review of AI commits is the baseline; surface violations before they accumulate rather than at the end.
- **Skilling. [ongoing]** The team levels up by encoding what it learns into skills and rules — so the next person (and the next AI run) inherits it.

**What good looks like:** people spend their time on judgment — what to build, whether it's right — and almost none on mechanical production.

## 7. Measurement & adoption

You cannot delegate what you cannot measure. Track a small, honest set of signals and let trials generate the evidence.

**Signals to track:**
- **Productivity** — lead time from issue to merged PR; share of PRs primarily AI-implemented.
- **Quality** — review findings per PR and their severity; escaped defects; gate failure rate (a rising rate caught *before* `main` is healthy).
- **Adoption** — number of repos with shared skills + `CLAUDE.md`; which maturity stage each repo sits at; skill usage.

**The learning engine — trials and live projects.** Trials are the structured way a practice gets proven before it spreads, but they are not the only source: active development projects surface just as many gaps and toolkit ideas in the course of real work. Both feed the same backlog.

Trials follow a defined flow:
1. Set goals and success criteria up front (`templates/trial-goals.md`).
2. Run the build with the skills and guardrails in place.
3. Log gaps as they emerge — don't wait for the end.
4. Write the post-trial review (`templates/trial-review.md`) and **feed the gaps back** into `templates/CLAUDE.md` and the skills, so the whole community inherits the fix.

Active projects don't have a trial's ceremony, so make surfacing cheap: when a gap or a reusable idea appears mid-build, capture it the moment it's noticed and route it to the same backlog a trial would feed. A good idea from a live project is as valid a build signal as a logged trial gap.

**What good looks like:** every claim that "AI-first works here" is backed by evidence — a trial review or live-project metrics — and every gap surfaced, whether in a trial or active development, has become a rule or a skill that prevents its recurrence.

---

# Part 3 — Building the toolkit

Parts 1–2 are about *using* AI-first practices. This part is about *producing* them: how the taskforce sources, builds, tests, distributes, and maintains the skills, templates, guardrails, and tooling that teams consume. The audience here is the taskforce and its contributors.

## 8. How we build (principles)

The producer side mirrors the consumer thesis: **earn autonomy with verification.** A capability we ship grants its users autonomy (they trust it to do work); we pay for that the same way teams do — with proof it works before anyone relies on it.

- **Demand-driven, not speculative.** Capabilities come from real gaps that surface in real work — both structured trials and active development projects. A gap that recurs across projects is the signal to build. We don't build skills for problems no one has hit yet.
- **Dogfood the loop.** We build the toolkit using the same AI-first loop we advocate — brainstorm → issue → implement → review → verify — against this repo's own `CLAUDE.md`, hooks, and review skills. If a practice isn't good enough to build our own tools with, it isn't good enough to ship.
- **Generalize ruthlessly.** A capability sourced from one project must be stripped of project-specific names, commit hashes, and org-specific tooling — replaced with `[ ]` placeholders — and the originating gap cited in a comment. The rule that ships must be general even when the lesson was specific.
- **Earn trust before shipping.** Nothing distributes until it has cleared its quality bar (Chapter 10). An unproven skill is a liability: it fails silently inside someone else's workflow.

**What good looks like:** every capability traces back to a named gap, was built with our own loop, generalizes cleanly, and shipped only after it passed its bar.

## 9. The capability lifecycle

The spine of the build engine. Every capability — a rule, a skill, or a tool — moves through six phases:

1. **Surface.** A gap or opportunity shows up in real use — a trial's gaps log, or an active development project where a recurring pain point or a good idea points to a reusable capability. When it recurs across projects, it becomes a build candidate. (Trials capture these in `templates/trial-review.md` gaps logs; active projects surface them ad hoc — route them to the same backlog.)
2. **Build.** Choose the form (Chapter 10) and build it with the AI-first loop, using `skill-creator` / `writing-skills` for skills.
3. **Prove.** Validate against the quality bar (Chapter 10) — skill evals with variance analysis for skills, automated tests for tooling, plus the repo's lint, hooks, and secret scan.
4. **Generalize.** Strip project specifics to `[ ]` placeholders; cite the originating gap; confirm it reads cleanly with no project context.
5. **Distribute.** Ship via the `gh` extension `setup` flow, which installs every skill in `skills/` into `~/.claude/skills/`; register it in `skills/README.md` (Chapter 11).
6. **Maintain.** Track usage and adoption metrics; keep it current as Claude Code evolves; deprecate when superseded (Chapter 11).

The lifecycle is a loop, not a line: a capability in **Maintain** keeps surfacing new gaps from real use, which re-enter at **Surface**. This is the same feed-the-gaps-back loop from Chapter 3, viewed from the producer side.

**What good looks like:** a gap can be pointed to for every capability, and every shipped capability has a clear owner watching its Maintain phase.

## 10. Forms & the quality bar

**Three forms a capability can take** — pick the lightest one that solves the gap:

| Form | Use when | Lives in |
|---|---|---|
| **`CLAUDE.md` rule** | The gap is a behaviour or constraint the agent must always honour. | `templates/CLAUDE.md` |
| **Skill** | The gap needs a repeatable, invocable workflow (e.g. create-issue, code-review, lint-setup). | `skills/`, distributed to `~/.claude/skills/` |
| **Standalone tooling** | The gap needs executable logic beyond what a skill can express (e.g. the `setup` command itself). | `gh-ai-first-taskforce` (the `gh` extension entry point) |

**The quality bar — what a capability must clear before it ships:**

- **Skills:** pass their evals, with **variance analysis** to confirm the result is stable and not a lucky single run; the description must trigger reliably on the intended requests and not on unrelated ones.
- **Standalone tooling:** covered by automated tests for its core behaviour and failure paths.
- **Everything:** passes the repo's own gates — lint, pre-commit/pre-push hooks, and secret scan — and a human review before merge.

No capability skips the bar. A skill that ships untested doesn't just fail — it fails *inside someone else's workflow*, where it's hardest to diagnose.

**What good looks like:** the lightest viable form was chosen, and the bar was met with evidence (eval results, test runs) — not asserted.

## 11. Distribution & maintenance

**Distribution.** Capabilities reach teams through the `gh` CLI extension:

- Install: `gh extension install transformteamsg/gh-ai-first-taskforce`, then `gh ai-first-taskforce setup` to install skills into `~/.claude/skills/`.
- Upgrade: `gh extension upgrade ai-first-taskforce && gh ai-first-taskforce setup` to pull the latest.
- **Discovery:** each skill is a self-contained directory under `skills/` whose `SKILL.md` `name` and `description` tell agents when to trigger it — no central router needed. The `setup` command installs every skill directory it finds; register each one in `skills/README.md` so the catalogue stays current.

**Maintenance.**

- **Stay current with Claude Code.** Skills depend on platform behaviour; when Claude Code evolves, re-run evals and update skills that drift.
- **Close the metrics loop.** Adoption and quality signals from Chapter 7 point to which capabilities are used, which underperform, and which gaps remain — that evidence drives the next Surface.
- **Deprecate deliberately.** When a capability is superseded, mark it, point users to its replacement, and remove it once adoption has moved — don't let dead skills accumulate.

**What good looks like:** a team can install and upgrade in two commands, every shipped skill is self-describing and listed in `skills/README.md`, and nothing in the toolkit is stale or orphaned.

## 12. Platform ideas roadmap

Larger, net-new tooling (beyond skills and templates) progresses through four gates before it becomes a product. Today's exploratory pieces — the **local codebase sensitivity scanner** and the **data-masking pipeline** for restricted projects — sit early in this pipeline.

1. **Explore.** Frame the problem and the constraints; confirm it's worth building. *(Both ideas are here today.)*
2. **Prototype.** Build the smallest thing that proves the core mechanic works — e.g. a local-LLM scan that never lets data leave the device.
3. **Trial.** Run it on a real project through the trial flow (Chapter 7); capture gaps and a trial review.
4. **Productionize.** Generalize, meet the quality bar, and fold it into the distribution path.

Because these ideas exist precisely to handle sensitive code and data, the **data-sensitivity guardrails from Chapter 5 are a gate, not an afterthought**: a scanner or masking step must itself be safe to run on the very data it protects before it can advance.

**What good looks like:** every platform idea has a known gate, and no idea advances past Prototype without a guardrail story for the data it touches.

## 13. Contribution model

The toolkit grows fastest when teams contribute back what worked for them.

- **Contribute a skill** by following the structure of an existing one (e.g. any `skills/aif-*` directory) and opening a pull request.
- **The bar is the same** as for taskforce-built capabilities: sourced from a real gap, generalized with `[ ]` placeholders, past its quality bar (Chapter 10), and listed in `skills/README.md`.
- **Generalize before contributing.** Strip project-specific names, commit hashes, and org-specific tooling before anything lands in `templates/`.
- **Ownership.** A contributed capability needs someone accountable for its Maintain phase — contribution is a commitment, not a drop-off.

**What good looks like:** an outside team can take a gap they hit, turn it into a generalized capability that meets the bar, and ship it to everyone through a single reviewed PR.

---

## Appendix — Quick reference

Skill → SDLC stage → earliest maturity stage where it becomes standard.

| Skill | SDLC stage | Becomes standard at |
|---|---|---|
| `aif-create-issue` | Plan & scope | Co-create |
| `aif-split-issue` | Plan & scope | Co-create |
| `aif-implement-issue` | Implement | Co-create |
| `aif-code-review` | Review | Co-create |
| `aif-lint-setup` | Quality gates | Co-create |
| `aif-git-hooks-setup` | Quality gates | Co-create |
| `aif-update-npm-dependencies` | Quality gates / Maintain | Co-create |
| `brainstorming` † | Plan & scope | Co-pilot |
| `verification-before-completion` † | Guardrails (all stages) | Co-pilot |

The `aif-*` skills ship in this repo's `skills/` directory via the `gh` extension. † `brainstorming` and `verification-before-completion` are general Claude Code practices referenced in Chapters 4–5, not taskforce-specific skills.

**One-line summary:** grant the AI more of the build loop one notch at a time, and pay for each notch of autonomy with a guardrail in the repo and a way to verify the result.
