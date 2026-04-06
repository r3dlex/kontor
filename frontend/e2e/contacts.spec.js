import { test, expect } from '@playwright/test'

const MOCK_CONTACTS = [
  {
    id: 1,
    display_name: 'Alice Smith',
    email_address: 'alice@example.com',
    organization: 'Acme Corp',
    importance_weight: 0.9
  },
  {
    id: 2,
    display_name: 'Bob Jones',
    email_address: 'bob@example.com',
    organization: null,
    importance_weight: 0.5
  }
]

async function setupAuth(page) {
  await page.addInitScript(() => {
    localStorage.setItem('kontor_token', 'test-token')
    localStorage.setItem('kontor_user', JSON.stringify({ id: 1, name: 'Test User' }))
  })
}

test.describe('Contacts page (unauthenticated redirect)', () => {
  test('redirects to login when accessing contacts without auth', async ({ page }) => {
    await page.goto('/contacts')
    await expect(page).toHaveURL(/login/, { timeout: 10000 })
  })
})

test.describe('Contacts page', () => {
  test.beforeEach(async ({ page }) => {
    await setupAuth(page)

    await page.route('/api/v1/contacts', (route) => {
      route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({ contacts: MOCK_CONTACTS })
      })
    })

    await page.route('/socket/**', (route) => route.abort())

    await page.goto('/contacts')
  })

  test('renders contact cards for each contact', async ({ page }) => {
    await expect(page.locator('.contact-card')).toHaveCount(2)
  })

  test('displays contact names', async ({ page }) => {
    await expect(page.locator('.contact-name').first()).toContainText('Alice Smith')
  })

  test('displays contact email addresses', async ({ page }) => {
    await expect(page.locator('.contact-email').first()).toContainText('alice@example.com')
  })

  test('displays organization when present', async ({ page }) => {
    await expect(page.locator('.contact-org').first()).toContainText('Acme Corp')
  })

  test('renders list and graph toggle buttons', async ({ page }) => {
    const buttons = page.locator('.view-toggle button')
    await expect(buttons).toHaveCount(2)
  })

  test('shows "No contacts found." when contacts list is empty', async ({ page }) => {
    await page.route('/api/v1/contacts', (route) => {
      route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({ contacts: [] })
      })
    })
    await page.goto('/contacts')
    await expect(page.locator('.contact-card')).toHaveCount(0)
  })
})
