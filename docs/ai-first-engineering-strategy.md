# AI-First Engineering Strategy

This document sets out how we intend to modernize software engineering with AI, and how teams can adopt it.

**What does AI-first software engineering look like, and how do we get there?** Coding agents can now carry out much of the mechanical build loop — drafting issues, writing code, reviewing changes, and fixing what they find. The value is not in using more AI for its own sake; it is in moving that work from scattered, individual experimentation to a **structured, repeatable, and safe** way of working. People spend less time typing and more time deciding what to build and confirming it was built correctly, while agents do the build loop within clear guardrails.

This strategy describes where that journey leads, how teams move along it, and how we keep it safe. Sections 1–5 are for the people doing the work — SWEs, PMs, designers, and DevOps. Section 6 is for the taskforce and contributors who build the supporting toolkit.

## 1. What changes

Two things change when agents take on the build loop.

First, the bottleneck moves. When writing code is no longer the constraint, the work that matters is **direction** — deciding what to build — and **verification** — confirming it was built correctly. Teams reinvest their time there.

Second, the risk profile changes. An agent working quickly without guardrails can commit secrets, pull in a compromised dependency, or produce plausible-but-wrong code faster than a person can catch by reading. So the modernization is not simply "adopt AI"; it is adopting agentic engineering together with the guardrails and verification that make it safe.

The rest of this document is about doing both at once: increasing what we hand to agents while increasing the structure that keeps it trustworthy.

## 2. The progression

Modernization is a continuum, not a set of rigid gates. A team can sit anywhere along it, and at different points for different repos.

```
●──────────────●──────────────●──────────────●──────────────●
Traditional    AI-assisted    Ad-hoc AI      Agentic        Structured agentic
development    coding         delegation     workflows      software engineering
```

| # | Checkpoint | What changes vs. the previous step |
|---|---|---|
| 1 | **Traditional development** | No AI in the loop; the team writes and reviews everything. |
| 2 | **AI-assisted coding** | AI speeds up the person at the keyboard — autocomplete, inline suggestions, quick Q&A. A human still drives every change. |
| 3 | **Ad-hoc AI delegation** | Whole tasks are handed to AI ("build this", "fix that"), but informally — per person, with no shared rules or guardrails. |
| 4 | **Agentic workflows** | Agents are wired into the team's workflow with shared rules and automated checks, running defined steps that humans review. |
| 5 | **Structured agentic software engineering** | Agents run the end-to-end build loop within that structure; humans set direction and verify rather than oversee each step. |

To place a repo, ask two things: how much of the build loop it hands to agents, and how much shared structure — rules, checks, reviews — catches their mistakes. Both low is traditional or AI-assisted (1–2); handing work to agents without that structure is ad-hoc delegation (3); both high is agentic workflows or structured engineering (4–5). A team can sit at a different point for each repo, so place each repo on its own.

The checkpoints are a shared vocabulary for where a team is today and what the next step looks like — not labels to rank teams by.

## 3. Advancing safely

Teams move along the continuum one step at a time, and each increase in what agents do is matched by a guardrail that makes it safe. The pattern is the same at every step:

1. **Try it** on one real task — hand an agent the next slice of work you would normally do by hand — rather than rolling it out broadly first.
2. **Add the guardrail** that makes the new autonomy safe before relying on it — usually by installing a shared capability (a rule, a check, or a review workflow) rather than building one from scratch.
3. **Check it helped**, using the signals in Section 5.
4. **Feed back what you learn** — when an agent does something the rules should have caught, turn that into a rule or check so it cannot recur.

For instance, a team might hand an agent the next issue to implement (try it), then add a review step that checks each change against its agreed standards before relying on the output (add the guardrail), track review findings and lead time to confirm it helped (check, using Section 5), and fold any finding that slips through back into those standards so it cannot recur (feed back).

The guardrails that make agentic work safe:

- **Direction stays human.** Agents implement; humans own the architecture and how work is decomposed into issues. Autonomy grows over how work gets built — not over what to build, or how the system is shaped.
- **Verification over trust.** A "done" claim stays unverified until there is evidence — the command was run, the output read, the tests pass.
- **Review against written standards.** Changes are reviewed against agreed standards rather than skimmed, so the human's role is to adjudicate findings rather than be the first line of detection.
- **Dependency cooldown.** Don't adopt a dependency release the moment it's published — wait out a short cooldown so freshly-published malicious versions are caught before they enter the project (our default is ≥ 7 days).
- **Secrets and branch protection.** Scan changes for secrets before they land, and block direct pushes to the main branch so work goes through review — enforced with automated checks (we use git hooks).
- **Data sensitivity.** A project's data classification is known before code or data reaches an external model, and the work is matched to an environment approved for that classification (in our setup, the Greenlane OPEN / OFFICIAL / OFFICIAL-CLOSED tiers). For restricted projects, sensitive material stays on-device.

This is why the shift is carried by a shared toolkit, not by exhortation. A team does not reach the structured end of the continuum by resolving to try harder; it gets there because each guardrail above exists as something it can **install** instead of rebuilding it. Every capability a team adopts is a concrete step up the progression, with the matching guardrail already in hand. The toolkit installs as a `gh` extension — see the repository README to set it up, and the skills catalogue (`skills/README.md`) for what is available today. Section 6 covers how that toolkit is produced.

## 4. What changes for people

Agentic engineering does not remove roles; it moves each one toward direction and verification, and away from mechanical production.

Two lenses describe this. **Build-loop stages** — planning and architecture, issue authoring, implementation, review, deployment — are what agents increasingly carry. **Roles** are the people who direct and verify across those stages. Architecture and direction-setting are not a stage that moves to agents; they are what humans keep as the stages shift to agents.

Role behaviour shifts meaningfully only twice along the continuum, so the five checkpoints fall into three groups here — traditional (no AI), unstructured AI use (checkpoints 2–3), and structured agentic engineering (checkpoints 4–5):

| Role | Traditional development | Unstructured AI use | Structured agentic engineering |
|---|---|---|---|
| **SWE** | Writes and reviews all code | Codes with AI help | Maintains the repo's shared rules and checks; sets technical direction; verifies and approves changes |
| **PM / practitioner** | Writes specs and tracks work by hand | Asks AI to draft and explain | Writes clear issues agents can implement; defines goals and acceptance; approves outcomes |
| **Designer** | Hands off mockups and redlines for engineers to build | Generates design variations, copy, and asset drafts with AI | Maintains the design system agents build against; specifies design intent and acceptance; verifies built UI against intent |
| **DevOps** | Manually scripts and operates | Scripts with AI help | Wires the checks and branch protection that let agent and human work merge safely |

These roles are illustrative, not a closed list — the same shift from mechanical production to direction and verification applies to any contributor, including QA, data, and security.

Some things hold regardless of how far a team has progressed:

- **A human is accountable for every merge.** Autonomy increases; accountability does not move.
- **Review stays close.** Reviewing agent contributions on a regular cadence keeps issues from accumulating.
- **Teams improve by capturing what they learn** as shared rules and checks, so the next person — and the next agent run — inherits it.

## 5. Measuring progress

Adoption should be backed by evidence drawn from real project work, rather than asserted.

Signals worth tracking:

- **Productivity** — lead time from issue to merged PR; throughput.
- **Quality** — review findings per change and their severity; escaped defects; how often the automated checks catch problems before the main branch.
- **Adoption** — how many repos have shared rules and checks in place; where each repo sits on the progression; the share of changes primarily implemented by agents.

Learning comes mainly from real projects. As the practices are used on live product work, the gaps and ideas that surface there are the main signal for what to improve next. A dedicated trial — goals set up front, gaps logged as they emerge, a short review afterward — still has its place when a new stack or practice needs proving before it spreads. Either way, a gap surfaced in real work becomes a rule or check that prevents it recurring.

## 6. Building the toolkit

The sections above are about adopting agentic engineering. This section is about producing what teams adopt — the shared rules, checks, and skills that make the structured end of the continuum possible. These are the **capabilities** this document refers to; a *skill* is simply a capability packaged as an invocable workflow. It is for the taskforce and its contributors; the mechanics of installing, contributing, and distributing live in the repository's `README` and `CONTRIBUTING` guide.

The toolkit is what makes the progression reachable in practice. Each capability packages a piece of structure — a guardrail, a review standard, a repeatable workflow — that a team would otherwise have to build for itself. By installing what the community has already proven, a team advances from ad-hoc delegation toward agentic workflows and structured agentic software engineering without reinventing the supporting structure each time. Every capability we add lowers the cost of moving up a checkpoint, which is how the progression in Section 2 turns from an aspiration into something teams can actually adopt.

We build by a few principles:

- **Demand-driven.** Capabilities come from real gaps that surface in real work, not from speculation. A gap that recurs across projects is the signal to build.
- **Dogfooded.** We build the toolkit using the same agentic loop and guardrails we advocate. If a practice is not good enough to build our own tools with, it is not ready to ship.
- **Generalized.** A capability drawn from one project is stripped of project-specific detail before it is shared, so it applies broadly.
- **Proven before shipping.** Nothing is distributed until it has been evaluated and reviewed; an unproven capability fails quietly inside someone else's work.

Each capability follows the same lifecycle: a gap **surfaces** in real use, it is **built** in the lightest form that solves it — a rule, a check, or a skill — it is **proven** against evaluations and the repo's own checks, it is **generalized**, it is **distributed** to teams, and it is **maintained**, where continued use surfaces the next gap. That loop mirrors the adoption loop in Section 3, seen from the producer's side.

---

In short: hand agents more of the build loop step by step, while growing the structure and verification that keep each step safe — modernizing how we build software without trading away trust.
