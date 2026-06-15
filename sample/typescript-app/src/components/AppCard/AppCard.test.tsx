import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { AppCard } from './AppCard'

describe('AppCard', () => {
  it('renders the label as a button', () => {
    render(<AppCard label="Assignments" isActive={false} onClick={() => {}} />)
    expect(screen.getByRole('button', { name: 'Assignments' })).toBeInTheDocument()
  })

  it('sets aria-pressed false when inactive', () => {
    render(<AppCard label="Assignments" isActive={false} onClick={() => {}} />)
    expect(screen.getByRole('button', { name: 'Assignments' })).toHaveAttribute(
      'aria-pressed',
      'false'
    )
  })

  it('sets aria-pressed true when active', () => {
    render(<AppCard label="Assignments" isActive={true} onClick={() => {}} />)
    expect(screen.getByRole('button', { name: 'Assignments' })).toHaveAttribute(
      'aria-pressed',
      'true'
    )
  })

  it('calls onClick when clicked', async () => {
    const onClick = vi.fn()
    render(<AppCard label="Assignments" isActive={false} onClick={onClick} />)
    await userEvent.click(screen.getByRole('button', { name: 'Assignments' }))
    expect(onClick).toHaveBeenCalledTimes(1)
  })
})
