import { render, screen } from '@testing-library/react'
import { AssignmentList } from './AssignmentList'
import { useAssignments } from './useAssignments'
import type { Assignment } from '../../types'

vi.mock('./useAssignments')

const ASSIGNMENT: Assignment = {
  id: 'a-1',
  classId: 'c-1',
  title: 'Essay draft',
  dueDate: '2026-06-20',
  maxScore: 100,
}

describe('AssignmentList', () => {
  it('shows a loading indicator while fetching', () => {
    vi.mocked(useAssignments).mockReturnValue({ assignments: [], isLoading: true, error: null })
    render(<AssignmentList classId="c-1" />)
    expect(screen.getByText('Loading assignments…')).toBeInTheDocument()
  })

  it('shows an alert when the fetch fails', () => {
    vi.mocked(useAssignments).mockReturnValue({
      assignments: [],
      isLoading: false,
      error: 'Failed to load assignments: 500',
    })
    render(<AssignmentList classId="c-1" />)
    expect(screen.getByRole('alert')).toHaveTextContent('Failed to load assignments: 500')
  })

  it('shows an empty state when the class has no assignments', () => {
    vi.mocked(useAssignments).mockReturnValue({ assignments: [], isLoading: false, error: null })
    render(<AssignmentList classId="c-1" />)
    expect(screen.getByText('No assignments yet.')).toBeInTheDocument()
  })

  it('renders each assignment title and due date', () => {
    vi.mocked(useAssignments).mockReturnValue({
      assignments: [ASSIGNMENT],
      isLoading: false,
      error: null,
    })
    render(<AssignmentList classId="c-1" />)
    expect(screen.getByText('Essay draft — due 2026-06-20')).toBeInTheDocument()
  })

  it('renders multiple assignments in order', () => {
    const second: Assignment = { ...ASSIGNMENT, id: 'a-2', title: 'Final essay', dueDate: '2026-07-01' }
    vi.mocked(useAssignments).mockReturnValue({
      assignments: [ASSIGNMENT, second],
      isLoading: false,
      error: null,
    })
    render(<AssignmentList classId="c-1" />)
    const items = screen.getAllByRole('listitem')
    expect(items[0]).toHaveTextContent('Essay draft')
    expect(items[1]).toHaveTextContent('Final essay')
  })
})
