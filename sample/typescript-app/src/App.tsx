import { useState } from 'react'
import { AppShell } from './components/AppShell/AppShell'
import { AssignmentList } from './features/assignments/AssignmentList'
import type { AppId } from './types'

export default function App() {
  const [activeApp, setActiveApp] = useState<AppId | null>(null)

  return (
    <AppShell activeApp={activeApp} onSelectApp={setActiveApp}>
      {activeApp === 'assignments' && <AssignmentList classId="class-1" />}
    </AppShell>
  )
}
