import type { ReactNode } from 'react'
import { AppCard } from '../AppCard/AppCard'
import type { AppId } from '../../types'

interface AppShellProps {
  activeApp: AppId | null
  onSelectApp: (app: AppId | null) => void
  children: ReactNode
}

export function AppShell({ activeApp, onSelectApp, children }: AppShellProps) {
  function toggle(id: AppId) {
    onSelectApp(activeApp === id ? null : id)
  }

  return (
    <div>
      <header role="banner">
        <h1>Sample App</h1>
      </header>
      <nav aria-label="apps">
        <AppCard
          label="Assignments"
          isActive={activeApp === 'assignments'}
          onClick={() => toggle('assignments')}
        />
      </nav>
      <main>{children}</main>
    </div>
  )
}
