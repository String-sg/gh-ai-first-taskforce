export interface Student {
  id: string
  name: string
  email: string
}

export interface Class {
  id: string
  name: string
  studentIds: string[]
}

export interface Assignment {
  id: string
  classId: string
  title: string
  dueDate: string
  maxScore: number
}

export interface Grade {
  studentId: string
  assignmentId: string
  score: number
  submittedAt: string
}

export type AppId = 'assignments'
