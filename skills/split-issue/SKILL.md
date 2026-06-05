---
name: split-issue
description: Use when you need to decompose a GitHub issue numbered $ARGUMENTS into atomic child issues, each small enough for a coding agent to implement in a single PR.
---

## Step 1: Fetch and read the issue

Run:

```
gh issue view $ARGUMENTS --json number,title,body,labels,state
```

Read the entire issue body. Extract:

- All acceptance criteria scenarios (Given-When-Then)
- The user story and background
- The out of scope list
- The dependencies (blocked by / blocks)
- All implementer sections if present

## Step 2: Analyse and propose a split

Group the acceptance criteria scenarios by coherent capability. Two scenarios belong in the same group when they share the same actor, the same area of the system, and would touch overlapping files. Scenarios that describe independent capabilities belong in separate groups.

For each proposed child issue, identify:

- Which acceptance criteria scenarios it contains
- The coherent capability those scenarios describe (one sentence)
- Whether the child depends on another child being implemented first

Present the proposed split clearly before taking any action:

```
Proposed split of #$ARGUMENTS into N issues:

Issue A — <capability name>
  Scenarios: <list>
  Depends on: none / Issue B

Issue B — <capability name>
  Scenarios: <list>
  Depends on: none / Issue A
```

Ask the developer to confirm the grouping or adjust it before proceeding. Do not create any issues until confirmed.

## Step 3: Create child issues

For each confirmed child issue, create it using the feature template structure. Populate the sections as follows:

**Author sections** (carry over from the parent):

- User story: the parent user story, narrowed to the child's scope
- Background: the parent background unchanged
- Acceptance criteria: only the scenarios assigned to this child
- Out of scope: the parent out of scope list, plus an explicit entry for the other child issues ("other capabilities split into #NNN")
- Design assets: same links as the parent
- Dependencies: "Blocked by: #NNN" if this child depends on another child; otherwise "none"

**Implementer sections**: leave all fields at their placeholder text. The child issues must go back through grooming before implementation begins. The grooming checklist must be unchecked.

Run for each child:

```
gh issue create \
  --title "<type>(`<scope>`): <child capability, following commit convention>" \
  --body "<populated body>"
```

Record each created issue number.

## Step 4: Update the original issue

Add a comment to the original issue listing the child issues and close it:

```
gh issue comment $ARGUMENTS --body "Split into:
- #NNN — <child A title>
- #NNN — <child B title>

These child issues need grooming before implementation begins."
```

Then close the original:

```
gh issue close $ARGUMENTS --reason "not planned"
```

## Step 5: Report to the developer

Report:

1. Child issues created: title and URL for each
2. Dependency order: which must be implemented first, if any
3. Next step: each child issue needs engineering grooming (technical sections and grooming checklist) before `/implement-issue` can be run on it
