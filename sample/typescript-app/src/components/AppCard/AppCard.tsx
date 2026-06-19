interface AppCardProps {
  label: string
  isActive: boolean
  onClick: () => void
}

export function AppCard({ label, isActive, onClick }: AppCardProps) {
  return (
    <button onClick={onClick} aria-pressed={isActive}>
      {label}
    </button>
  )
}
