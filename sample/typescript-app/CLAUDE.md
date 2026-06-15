# CLAUDE.md — typescript-app

Conventions for this sample app. This is a Vite + React + TypeScript frontend shell that hosts domain tools as feature modules.

---

## Commands

| Purpose | Command |
|---|---|
| Run tests | `pnpm test` |
| Start dev server | `pnpm dev` |
| Type-check | `pnpm build` |

---

## Project structure

```
src/
  types/index.ts              # shared domain types
  components/                 # shell UI (AppShell, AppCard)
  features/<name>/            # one directory per feature
```

### Feature module pattern

Every feature lives in `src/features/<name>/` and follows this layout exactly:

```
src/features/assignments/
  useAssignments.ts       # data-access hook: fetch, loading state, error
  useAssignments.test.ts  # hook tests via renderHook
  AssignmentList.tsx      # display component — consumes the hook
  AssignmentList.test.tsx # component tests via render + vi.mock on the hook
```

Reference `src/features/assignments/` as the canonical pattern for any new feature.

---

## TypeScript

- `strict: true` is on — no `any`, no non-null assertions without an explanatory comment
- All component props are typed as a local `interface` immediately above the component
- Domain types come from `../../types` — never re-declare them inside a feature

---

## Testing

Framework: Vitest + Testing Library. `describe`, `it`, `expect`, `vi`, `beforeEach`, `afterEach` are global — no import needed.

### Hook tests

Spy on `fetch`; restore after each test:

```typescript
describe('useAssignments', () => {
  beforeEach(() => { vi.spyOn(global, 'fetch') })
  afterEach(() => { vi.restoreAllMocks() })

  it('returns assignments on a successful fetch', async () => {
    vi.mocked(fetch).mockResolvedValueOnce(
      new Response(JSON.stringify([ASSIGNMENT]), { status: 200 })
    )
    const { result } = renderHook(() => useAssignments('c-1'))
    await waitFor(() => expect(result.current.isLoading).toBe(false))
    expect(result.current.assignments).toEqual([ASSIGNMENT])
  })
})
```

### Component tests

Mock the data hook — component tests cover rendering only, not data fetching:

```typescript
vi.mock('./useAssignments')

describe('AssignmentList', () => {
  it('renders each assignment title and due date', () => {
    vi.mocked(useAssignments).mockReturnValue({
      assignments: [ASSIGNMENT],
      isLoading: false,
      error: null,
    })
    render(<AssignmentList classId="c-1" />)
    expect(screen.getByText('Essay draft — due 2026-06-20')).toBeInTheDocument()
  })
})
```

### Naming

- `describe`: the module or component name
- `it`: outcome-first, present tense — "returns assignments on success", not "should return assignments"
- No `.skip` or `.only` in committed tests

---

## Commit messages

Format: `<type>(\`<scope>\`): <short description>`

- `type`: `feat`, `fix`, `refactor`, `test`, `chore`
- `scope`: feature or component name in kebab-case (`assignments`, `app-card`, `gradebook`)
- Subject line names the behaviour, not the mechanism

---

## Style rules

- No em-dashes in code, comments, JSX text, or documentation
- No Tailwind, no CSS-in-JS — plain inline styles only when layout requires it
- No new npm/pnpm dependencies without an explicit hard constraint confirming it
