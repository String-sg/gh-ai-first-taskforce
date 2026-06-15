---
name: aif-create-issue
description: Use when you need to create a well-structured GitHub issue with complete author and implementer sections for a coding agent to implement.
---

You are helping create a well-structured GitHub issue for the teacher-workspace repository. The issue will be implemented by a coding agent, so every section must be complete enough to act on without follow-up questions.

The issue has two parts separated by a `---` divider:

- **Author sections** (written now): user story, background, acceptance criteria, out of scope, design assets
- **Implementer sections** (filled during engineering grooming): technical context, implementation details, additional test scenarios, hard constraints

Dependencies live outside the body: link blockers and dependents with GitHub's native issue relationships (the "Relationships" panel: blocked by / blocks), so the links stay accurate as issues move and close.

## Issue template

This is the canonical structure. Fill every section. Until grooming, leave each implementer section as its placeholder `_Pending grooming._` (do not delete the heading).

```markdown
## User story

As a [role], I want [capability], so that [benefit].

## Background

<problem this solves, how often it affects users, links to specs / Slack threads / recordings>

## Acceptance criteria

### <Outcome-first scenario name (happy path)>

- **Given** <starting state>
- **When** <action>
- **Then** <observable outcome>

### <Outcome-first scenario name (error / edge case)>

- **Given** <starting state>
- **When** <action>
- **Then** <observable outcome>

## Out of scope

- <explicit exclusion>

## Design assets

<Figma links, screenshots, a Mermaid diagram, or N/A>

---

## Technical context

_Pending grooming._

## Implementation details

_Pending grooming._

## Additional test scenarios

_Pending grooming._

## Hard constraints

_Pending grooming._
```

## Workflow

### Step 1: Gather author sections

Ask for the following. Do not invent answers: ask if the user has not provided them.

1. **Issue type and scope**: what type of change is this (`feat`, `fix`, `docs`, `refactor`, `chore`) and what area of the codebase does it touch (e.g. `session`, `middleware`, `assignments`)?
2. **User story**: who needs what, and why? Format: "As a [role], I want [capability], so that [benefit]."
3. **Background**: what problem does this solve? How often does it affect users? Are there links to specs, Slack threads, or recordings?
4. **Acceptance criteria**: at minimum one happy-path scenario and one error/edge-case scenario in Given-When-Then format. Names must be outcome-first (e.g. "Assignment is created", not "Create assignment"). Push back if scenarios describe implementation rather than observable behaviour.
5. **Out of scope**: at least one explicit exclusion. If none exist, ask the user to confirm nothing adjacent is in scope.
6. **Design assets**: Figma links or screenshots. If none are available, offer to produce a Mermaid diagram based on the described flow. State diagrams suit multi-step forms; sequence diagrams suit actor interactions.

### Step 1b: Evaluate for split

After gathering the acceptance criteria scenarios, evaluate them before continuing. Check for these signals:

- **Multiple actors**: scenarios describe actions by different roles with no shared outcome
- **Unrelated starting states**: scenarios have Givens that describe completely different parts of the system
- **Multiple unrelated endpoints**: the user has described what would become two or more unrelated API endpoints

If any signal is present, pause and surface it:

> "These scenarios describe two separate capabilities: [A] and [B]. Creating one issue would make it too large for a coding agent to implement safely in a single PR. Would you like to create two linked issues instead?"

If the user confirms a split: complete the author sections for each capability separately and create them as two issues. Run Steps 2 through 5 once per issue, then link them with GitHub's blocked-by / blocks relationship if one depends on the other.

If the user wants to keep it as one issue: note it explicitly in the out of scope section and continue.

### Step 1c: Identify dependencies from the backlog

After the split evaluation, fetch open issues and surface any that are likely blockers or dependents. These are linked as GitHub relationships after the issue is created (Step 5), not written into the body.

Run:

```sh
gh issue list --state open --json number,title,body --limit 100
```

Read the titles and bodies. Compare each against the new issue's scope, user story, and acceptance criteria. Flag an issue as a likely **blocker** if it must be completed before this capability can work correctly (for example, an auth issue that this feature depends on, or a data model change this feature builds on). Flag an issue as a likely **dependent** if this new issue would unblock or enable it.

Present findings before asking the author anything:

> "I found these potentially related open issues:
>
> Possible blockers (this issue may depend on them):
>
> - #NNN: title
>
> Possible dependents (they may depend on this issue):
>
> - #NNN: title
>
> Are any of these actual dependencies, or are they unrelated?"

Let the author confirm or dismiss each suggestion. Keep the confirmed ones to link as relationships in Step 5. If no related issues are found, proceed without prompting: do not ask the author to confirm a null result.

### Step 2: Ask about grooming state

Ask: "Are the technical sections already known, or will engineers fill those in during grooming?"

- If **already known**, gather the implementer sections now (see step 3).
- If **grooming pending**, skip step 3 and leave the implementer sections as their `_Pending grooming._` placeholders.

### Step 3: Gather implementer sections (if known)

1. **Technical context**: relevant directory paths.
2. **Implementation details**: a single section whose mini-sections you derive from this specific task. Do not start from the list below, and do not reproduce it as a default set.
   - First, write down every decision an implementer would otherwise have to guess to build *this* task: what to name things, where code lives, data shapes, contracts, edge/error handling, concurrency, migrations, config, ordering, idempotency, and so on. Each distinct decision becomes one mini-section.
   - Name each mini-section after its actual subject when a generic label would lose detail (e.g. "Assignment dedup key" or "Roster sync ordering", not just "Data model"). Most issues need at least one mini-section that is not in the reference list below.
   - Only after deriving the task's mini-sections, skim the reference list to catch a category you missed. Include an item from it only if it applies; skip the rest.
     - **Package/file placement**: where new files go and what they are named. Agents guess from naming conventions if omitted.
     - **Patterns to follow**: existing files that use the same pattern. Name a specific file path. Agents replicate the referenced pattern.
     - **Data model**: new or modified structs/types with field names, types, and constraints. Agents invent field names if omitted.
     - **API contract**: method, path, full request and response shapes. Include when building or changing an endpoint. Agents invent shapes if omitted.
     - **Error contract**: for each error case, the HTTP status and response body. Pairs with the API contract. Agents make inconsistent choices if omitted.
3. **Additional test scenarios**: non-user-observable scenarios worth testing (concurrent writes, boundary values, internal error paths). Use the same Given-When-Then format.
4. **Hard constraints**: things the implementer must NOT do (e.g. "do not add a new Go dependency").

Before continuing, check that the Implementation details mini-sections were derived from this task (at least one should be task-specific, not just reference-list categories) and that any patterns-to-follow mini-section names a specific file path. If a decision an implementer would have to guess is still uncovered, ask the user for it.

### Step 4: Preview and confirm

Assemble the title from the type and scope gathered in Step 1 plus a short description of the change: `<type>(<scope>): <short description>`. This title becomes the squash-merge commit message, so it must be a valid commit message.

Render the title and the complete issue body in a markdown code block and ask for confirmation before creating the issue.

### Step 5: Create the issue

The body is markdown containing backticks and other shell-special characters, so pass it via a file rather than inline (an inline `--body "..."` would let the shell interpret backticks as command substitution). Write the confirmed body to a temp file and create the issue with `--body-file`:

```sh
gh issue create --title "<title>" --body-file /tmp/issue-body.md
```

After creation, print the issue URL.

Then link any dependencies confirmed in Step 1b/1c using GitHub's native issue relationships. `gh issue` has no relationship subcommand, but the GraphQL `addBlockedBy` mutation does it. It takes node IDs, so first resolve each issue number to its node ID, then call the mutation. "Blocked by" is set on the new issue; "Blocks" is the inverse, set on the dependent issue.

```sh
# Resolve an issue number to its node ID
gh issue view <number> --json id --jq .id

# This issue is BLOCKED BY #NNN
gh api graphql -f query='mutation($issue:ID!,$blocker:ID!){addBlockedBy(input:{issueId:$issue,blockingIssueId:$blocker}){clientMutationId}}' -f issue=<this-issue-id> -f blocker=<blocker-id>

# This issue BLOCKS #NNN (set the relationship on the dependent)
gh api graphql -f query='mutation($issue:ID!,$blocker:ID!){addBlockedBy(input:{issueId:$issue,blockingIssueId:$blocker}){clientMutationId}}' -f issue=<dependent-id> -f blocker=<this-issue-id>
```

If no dependencies were confirmed, skip this.

## Rules

- Never leave a section blank. Every section must be explicitly filled or marked `N/A`.
- Acceptance criteria must use Given-When-Then format and be outcome-first named.
- Do not describe implementation in acceptance criteria: write what a user or system actor observes.
- Pick one term per concept and use it consistently across all scenarios (e.g. always "teacher", never mixing with "user").
- Do not use em-dashes (`—`) in the issue title or body. Use colons, parentheses, or separate sentences instead.
- The PR that implements this issue will squash-merge using the issue title as the commit message, so the title must be a valid commit message.
