import { useState, useEffect } from 'react'
import type { Assignment } from '../../types'

interface UseAssignmentsResult {
  assignments: Assignment[]
  isLoading: boolean
  error: string | null
}

export function useAssignments(classId: string): UseAssignmentsResult {
  const [assignments, setAssignments] = useState<Assignment[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    let cancelled = false
    setIsLoading(true)
    setError(null)

    fetch(`/api/classes/${classId}/assignments`)
      .then(res => {
        if (!res.ok) throw new Error(`Failed to load assignments: ${res.status}`)
        return res.json() as Promise<Assignment[]>
      })
      .then(data => {
        if (!cancelled) {
          setAssignments(data)
          setIsLoading(false)
        }
      })
      .catch((err: Error) => {
        if (!cancelled) {
          setError(err.message)
          setIsLoading(false)
        }
      })

    return () => { cancelled = true }
  }, [classId])

  return { assignments, isLoading, error }
}
