---
name: create-issue
description: Use when you need to create a well-structured GitHub issue with complete author and implementer sections for a coding agent to implement.
---

You are helping create a well-structured GitHub issue for the teacher-workspace repository. The issue will be implemented by a coding agent, so every section must be complete enough to act on without follow-up questions.

The issue has two parts separated by a divider:

- **Author sections** (written now): user story, acceptance criteria, out of scope, design assets, dependencies
- **Implementer sections** (filled during engineering grooming): technical context, data model, API contract, error contract, additional test scenarios, hard constraints

## Workflow

### Step 1: Gather author sections

Ask for the following. Do not invent answers — ask if the user has not provided them.

1. **Issue type and scope**: what type of change is this (`feat`, `fix`, `docs`, `refactor`, `chore`) and what area of the codebase does it touch (e.g. `session`, `middleware`, `assignments`)?
2. **User story**: who needs what, and why? Format: "As a [role], I want [capability], so that [benefit]."
3. **Background**: what problem does this solve? How often does it affect users? Are there links to specs, Slack threads, or recordings?
4. **Acceptance criteria**: at minimum one happy-path scenario and one error/edge-case scenario in Given-When-Then format. Names must be outcome-first (e.g. "Assignment is created", not "Create assignment"). Push back if scenarios describe implementation rather than observable behaviour.
5. **Out of scope**: at least one explicit exclusion. If none exist, ask the user to confirm nothing adjacent is in scope.
6. **Design assets**: Figma links or screenshots. If none are available, offer to produce a Mermaid diagram based on the described flow. State diagrams suit multi-step forms; sequence diagrams suit actor interactions.
7. **Dependencies**: what does this block, and what blocks it? `#NNN` references or "none".

### Step 1b: Evaluate for split

After gathering the acceptance criteria scenarios, evaluate them before continuing. Check for these signals:

- **Multiple actors**: scenarios describe actions by different roles with no shared outcome
- **Unrelated starting states**: scenarios have Givens that describe completely different parts of the system
- **Multiple unrelated endpoints**: the user has described what would become two or more unrelated API endpoints

If any signal is present, pause and surface it:

> "These scenarios describe two separate capabilities: [A] and [B]. Creating one issue would make it too large for a coding agent to implement safely in a single PR. Would you like to create two linked issues instead?"

If the user confirms a split: complete the author sections for each capability separately and create them as two issues with `Blocks` / `Blocked by` linking if one depends on the other. Run Steps 2 through 6 once per issue.

If the user wants to keep it as one issue: note it explicitly in the out of scope section and continue.

### Step 1c: Identify dependencies from the backlog

After the split evaluation, fetch open issues and surface any that are likely blockers or dependents before asking the author to fill in the Dependencies field manually.

Run:

```
gh issue list --state open --json number,title,body --limit 100
```

Read the titles and bodies. Compare each against the new issue's scope, user story, and acceptance criteria. Flag an issue as a likely **blocker** if it must be completed before this capability can work correctly (for example, an auth issue that this feature depends on, or a data model change this feature builds on). Flag an issue as a likely **dependent** if this new issue would unblock or enable it.

Present findings before asking the author anything:

> "I found these potentially related open issues:
>
> Possible blockers (this issue may depend on them):
>
> - #NNN — title
>
> Possible dependents (they may depend on this issue):
>
> - #NNN — title
>
> Are any of these actual dependencies, or are they unrelated?"

Let the author confirm or dismiss each suggestion. Use the confirmed ones to populate the Dependencies section (`Blocked by` / `Blocks`). If no related issues are found, proceed without prompting — do not ask the author to confirm a null result.

### Step 2: Ask about grooming state

Ask: "Are the technical sections already known, or will engineers fill those in during grooming?"

- If **already known**, gather the implementer sections now (see step 3).
- If **grooming pending**, skip step 3 and leave implementer sections with their placeholder text.

### Step 3: Gather implementer sections (if known)

1. **Relevant area of the codebase**: directory paths.
2. **Package/file placement**: where new files go and what they are named. Agents will guess from naming conventions if this is blank.
3. **Patterns to follow**: existing files that use the same pattern. Name a specific file path. Agents replicate the referenced pattern.
4. **Data model**: new or modified structs/types with field names, types, and constraints. Agents invent field names if this is blank.
5. **API contract**: method, path, full request and response shapes. Agents invent shapes if this is blank.
6. **Error contract**: for each error case, the HTTP status and response body. Agents make inconsistent choices if this is blank.
7. **Additional test scenarios**: non-user-observable scenarios worth testing (concurrent writes, boundary values, internal error paths). Use the same Given-When-Then format.
8. **Hard constraints**: things the implementer must NOT do (e.g. "do not add a new Go dependency").

### Step 4: Confirm grooming checklist

If implementer sections were filled, confirm each grooming checklist item can be checked:

- API contract filled or confirmed N/A
- Data model filled or confirmed N/A
- Patterns to follow named

If any item cannot be checked, ask the user to provide the missing information before continuing.

### Step 5: Preview and confirm

Render the complete issue body in a markdown code block and ask for confirmation before creating the issue.

### Step 6: Create the issue

Run:

```
gh issue create --title "<title>" --body "<body>"
```

The title must follow the commit convention from CLAUDE.md: `<type>(<scope>): <short description>` using backticks around the scope.

After creation, print the issue URL.

## Rules

- Never leave a section blank. Every section must be explicitly filled or marked `N/A`.
- Acceptance criteria must use Given-When-Then format and be outcome-first named.
- Do not describe implementation in acceptance criteria — write what a user or system actor observes.
- Pick one term per concept and use it consistently across all scenarios (e.g. always "teacher", never mixing with "user").
- The PR that implements this issue will squash-merge using the issue title as the commit message, so the title must be a valid commit message.
