import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import App from './App'

vi.mock('./features/assignments/useAssignments', () => ({
  useAssignments: () => ({ assignments: [], isLoading: false, error: null }),
}))

describe('App', () => {
  it('renders the workspace shell on load', () => {
    render(<App />)
    expect(screen.getByRole('banner')).toBeInTheDocument()
    expect(screen.getByText('Sample App')).toBeInTheDocument()
  })

  it('shows the assignments section when the assignments card is clicked', async () => {
    render(<App />)
    await userEvent.click(screen.getByRole('button', { name: /assignments/i }))
    expect(screen.getByRole('region', { name: /assignments/i })).toBeInTheDocument()
  })

  it('hides the assignments section when the card is clicked a second time', async () => {
    render(<App />)
    await userEvent.click(screen.getByRole('button', { name: /assignments/i }))
    await userEvent.click(screen.getByRole('button', { name: /assignments/i }))
    expect(screen.queryByRole('region', { name: /assignments/i })).not.toBeInTheDocument()
  })
})
