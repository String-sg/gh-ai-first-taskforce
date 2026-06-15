import { useAssignments } from './useAssignments'

interface AssignmentListProps {
  classId: string
}

export function AssignmentList({ classId }: AssignmentListProps) {
  const { assignments, isLoading, error } = useAssignments(classId)

  return (
    <section aria-label="assignments">
      {isLoading && <p>Loading assignments…</p>}
      {error != null && <p role="alert">{error}</p>}
      {!isLoading && error == null && assignments.length === 0 && (
        <p>No assignments yet.</p>
      )}
      {assignments.length > 0 && (
        <ul>
          {assignments.map(a => (
            <li key={a.id}>
              {a.title} — due {a.dueDate}
            </li>
          ))}
        </ul>
      )}
    </section>
  )
}
