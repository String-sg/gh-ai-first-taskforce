import { renderHook, waitFor } from '@testing-library/react'
import { useAssignments } from './useAssignments'
import type { Assignment } from '../../types'

const ASSIGNMENT: Assignment = {
  id: 'a-1',
  classId: 'c-1',
  title: 'Essay draft',
  dueDate: '2026-06-20',
  maxScore: 100,
}

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
    expect(result.current.error).toBeNull()
  })

  it('starts in a loading state', () => {
    vi.mocked(fetch).mockReturnValueOnce(new Promise(() => {}))
    const { result } = renderHook(() => useAssignments('c-1'))
    expect(result.current.isLoading).toBe(true)
    expect(result.current.assignments).toEqual([])
  })

  it('returns an error when the server responds with a non-OK status', async () => {
    vi.mocked(fetch).mockResolvedValueOnce(new Response(null, { status: 500 }))
    const { result } = renderHook(() => useAssignments('c-1'))
    await waitFor(() => expect(result.current.isLoading).toBe(false))
    expect(result.current.error).toBe('Failed to load assignments: 500')
    expect(result.current.assignments).toEqual([])
  })

  it('re-fetches when classId changes', async () => {
    vi.mocked(fetch)
      .mockResolvedValueOnce(new Response(JSON.stringify([ASSIGNMENT]), { status: 200 }))
      .mockResolvedValueOnce(new Response(JSON.stringify([]), { status: 200 }))

    const { result, rerender } = renderHook(({ id }) => useAssignments(id), {
      initialProps: { id: 'c-1' },
    })
    await waitFor(() => expect(result.current.isLoading).toBe(false))
    expect(result.current.assignments).toHaveLength(1)

    rerender({ id: 'c-2' })
    await waitFor(() => expect(result.current.isLoading).toBe(false))
    expect(result.current.assignments).toHaveLength(0)
  })
})
