import { test, expect } from '@playwright/test'

const MOCK_EVENTS = [
  {
    id: 'evt-1',
    title: 'Weekly Sync',
    start_time: '2026-04-06T09:00:00Z',
    end_time: '2026-04-06T09:30:00Z',
    attendees: ['alice@example.com', 'bob@example.com'],
    location: 'Conference Room A',
    briefing_markdown: null
  },
  {
    id: 'evt-2',
    title: 'Product Review',
    start_time: '2026-04-06T14:00:00Z',
    end_time: '2026-04-06T15:00:00Z',
    attendees: ['carol@example.com'],
    location: null,
    briefing_markdown: '## Agenda\n- Review roadmap\n- Prioritize features'
  }
]

async function setupAuth(page) {
  await page.addInitScript(() => {
    localStorage.setItem('kontor_token', 'test-token')
    localStorage.setItem('kontor_user', JSON.stringify({ id: 1, name: 'Test User' }))
  })
}

test.describe('Back Office', () => {
  test.beforeEach(async ({ page }) => {
    await setupAuth(page)

    await page.route('/api/v1/backoffice', (route) => {
      route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({ events: MOCK_EVENTS })
      })
    })

    // Stub out Phoenix WebSocket
    await page.route('/socket/**', (route) => route.abort())

    await page.goto('/backoffice')
  })

  test('renders the Back Office heading', async ({ page }) => {
    await expect(page.locator('h2')).toContainText('Back Office')
  })

  test('renders today\'s date', async ({ page }) => {
    const dateEl = page.locator('.date')
    await expect(dateEl).toBeVisible()
    // Should contain a day-of-week word
    await expect(dateEl).toHaveText(/Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday/)
  })

  test('renders a card for each meeting', async ({ page }) => {
    await expect(page.locator('.meeting-card')).toHaveCount(2)
  })

  test('renders meeting title for each event', async ({ page }) => {
    const cards = page.locator('.meeting-card')
    await expect(cards.nth(0).locator('h3')).toContainText('Weekly Sync')
    await expect(cards.nth(1).locator('h3')).toContainText('Product Review')
  })

  test('renders meeting time for each event', async ({ page }) => {
    await expect(page.locator('.meeting-time').first()).toBeVisible()
  })

  test('renders attendees for each meeting', async ({ page }) => {
    const attendees = page.locator('.meeting-card').first().locator('.attendee')
    await expect(attendees).toHaveCount(2)
    await expect(attendees.first()).toContainText('alice@example.com')
  })

  test('renders meeting location when present', async ({ page }) => {
    await expect(page.locator('.location').first()).toContainText('Conference Room A')
  })

  test('renders existing briefing content as HTML', async ({ page }) => {
    const briefing = page.locator('.meeting-card').nth(1).locator('.briefing-content')
    await expect(briefing).toBeVisible()
    await expect(briefing.locator('h4').first()).toContainText('Agenda')
  })

  test('shows "Generate Briefing" button when briefing_markdown is null', async ({ page }) => {
    const generateBtn = page.locator('.meeting-card').first().locator('button', { hasText: 'Generate Briefing' })
    await expect(generateBtn).toBeVisible()
  })

  test('Generate Briefing button calls the refresh API', async ({ page }) => {
    let refreshCalled = false

    await page.route('/api/v1/calendar/briefing/evt-1/refresh', (route) => {
      refreshCalled = true
      route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({ briefing_markdown: '## Summary\n- Key points here' })
      })
    })

    await page.locator('.meeting-card').first().locator('button', { hasText: 'Generate Briefing' }).click()
    expect(refreshCalled).toBe(true)
  })

  test('Generate Briefing button shows "Generating..." while in progress', async ({ page }) => {
    let resolveRefresh
    await page.route('/api/v1/calendar/briefing/evt-1/refresh', (route) => {
      new Promise((resolve) => { resolveRefresh = resolve }).then(() => {
        route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify({ briefing_markdown: '## Done' })
        })
      })
    })

    const btn = page.locator('.meeting-card').first().locator('button', { hasText: /Generate|Generating/ })
    await btn.click()
    await expect(btn).toContainText('Generating...')
  })

  test('shows "No meetings today." when events array is empty', async ({ page }) => {
    await page.route('/api/v1/backoffice', (route) => {
      route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({ events: [] })
      })
    })
    await page.goto('/backoffice')
    await expect(page.locator('.empty')).toContainText('No meetings today.')
  })

  test('Refresh button is shown on events that already have a briefing', async ({ page }) => {
    const refreshBtn = page.locator('.meeting-card').nth(1).locator('.refresh-btn')
    await expect(refreshBtn).toBeVisible()
    await expect(refreshBtn).toContainText('Refresh')
  })
})
