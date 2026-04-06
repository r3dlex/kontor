import { test, expect } from '@playwright/test'

const MOCK_EVENTS = [
  {
    id: 1,
    title: 'Standup',
    start_time: new Date(Date.now() + 3600000).toISOString(),
    end_time: new Date(Date.now() + 5400000).toISOString(),
    provider: 'google',
    attendees: ['alice@example.com', 'bob@example.com'],
    location: null
  },
  {
    id: 2,
    title: 'Sprint Review',
    start_time: new Date(Date.now() + 7200000).toISOString(),
    end_time: new Date(Date.now() + 10800000).toISOString(),
    provider: 'microsoft',
    attendees: ['charlie@example.com'],
    location: 'Conference Room A'
  }
]

async function setupAuth(page) {
  await page.addInitScript(() => {
    localStorage.setItem('kontor_token', 'test-token')
    localStorage.setItem('kontor_user', JSON.stringify({ id: 1, name: 'Test User' }))
  })
}

test.describe('Calendar page (unauthenticated redirect)', () => {
  test('redirects to login when accessing calendar without auth', async ({ page }) => {
    await page.goto('/calendar')
    await expect(page).toHaveURL(/login/, { timeout: 10000 })
  })
})

test.describe('Calendar page', () => {
  test.beforeEach(async ({ page }) => {
    await setupAuth(page)

    await page.route('/api/v1/calendar/today', (route) => {
      route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({ events: MOCK_EVENTS })
      })
    })

    await page.route('/socket/**', (route) => route.abort())

    await page.goto('/calendar')
  })

  test('renders event cards for each event', async ({ page }) => {
    await expect(page.locator('.event-card')).toHaveCount(2)
  })

  test('displays event titles', async ({ page }) => {
    await expect(page.locator('h3').first()).toContainText('Standup')
  })

  test('displays provider badges', async ({ page }) => {
    await expect(page.locator('.provider-badge').first()).toContainText('google')
  })

  test('shows location when present', async ({ page }) => {
    await expect(page.locator('.location').first()).toContainText('Conference Room A')
  })

  test('shows "No events today." when events list is empty', async ({ page }) => {
    await page.route('/api/v1/calendar/today', (route) => {
      route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({ events: [] })
      })
    })
    await page.goto('/calendar')
    await expect(page.locator('.empty')).toContainText('No events today.')
  })
})
