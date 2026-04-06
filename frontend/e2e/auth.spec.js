import { test, expect } from '@playwright/test'

test.describe('Login page', () => {
  test.beforeEach(async ({ page }) => {
    // Mock the auth check so the login page renders without a redirect
    await page.route('/api/v1/**', (route) => route.fulfill({ status: 401, body: '{}' }))
    await page.goto('/login')
  })

  test('renders a Google sign-in button', async ({ page }) => {
    const googleBtn = page.locator('a[href*="/api/v1/auth/google"], button:has-text("Google")')
    await expect(googleBtn.first()).toBeVisible()
  })

  test('renders a Microsoft sign-in button', async ({ page }) => {
    const msBtn = page.locator('a[href*="/api/v1/auth/microsoft"], button:has-text("Microsoft")')
    await expect(msBtn.first()).toBeVisible()
  })

  test('Google button points to the correct auth URL', async ({ page }) => {
    const googleLink = page.locator('a[href*="/api/v1/auth/google"]')
    await expect(googleLink.first()).toHaveAttribute('href', /\/api\/v1\/auth\/google/)
  })

  test('Microsoft button points to the correct auth URL', async ({ page }) => {
    const msLink = page.locator('a[href*="/api/v1/auth/microsoft"]')
    await expect(msLink.first()).toHaveAttribute('href', /\/api\/v1\/auth\/microsoft/)
  })
})
