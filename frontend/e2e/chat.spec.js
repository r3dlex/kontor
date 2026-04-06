import { test, expect } from '@playwright/test'

async function setupAuth(page) {
  await page.addInitScript(() => {
    localStorage.setItem('kontor_token', 'test-token')
    localStorage.setItem('kontor_user', JSON.stringify({ id: 1, name: 'Test User' }))
  })
}

async function stubWebSocket(page) {
  // Prevent real WebSocket connections to Phoenix
  await page.route('/socket/**', (route) => route.abort())
  await page.addInitScript(() => {
    // Stub the Phoenix Socket so connect() doesn't throw
    window.__PhoenixSocketStub = true
  })
}

async function stubTasksApi(page) {
  await page.route('/api/v1/tasks**', (route) => {
    route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({ tasks: [] })
    })
  })
}

test.describe('Chat panel', () => {
  test.beforeEach(async ({ page }) => {
    await setupAuth(page)
    await stubWebSocket(page)
    await stubTasksApi(page)
    await page.goto('/tasks')
  })

  test('chat panel is rendered in the app layout', async ({ page }) => {
    await expect(page.locator('.chat-panel').first()).toBeVisible()
  })

  test('renders "Assistant" header label', async ({ page }) => {
    await expect(page.locator('.chat-header')).toContainText('Assistant')
  })

  test('renders the message input textarea', async ({ page }) => {
    const textarea = page.locator('.chat-input textarea')
    await expect(textarea).toBeVisible()
  })

  test('textarea has "Ask anything..." placeholder', async ({ page }) => {
    const textarea = page.locator('.chat-input textarea')
    await expect(textarea).toHaveAttribute('placeholder', 'Ask anything...')
  })

  test('Send button is rendered', async ({ page }) => {
    await expect(page.locator('.chat-input button')).toBeVisible()
  })

  test('Send button is disabled when input is empty', async ({ page }) => {
    await expect(page.locator('.chat-input button')).toBeDisabled()
  })

  test('Send button becomes enabled when text is typed', async ({ page }) => {
    await page.locator('.chat-input textarea').fill('Hello')
    await expect(page.locator('.chat-input button')).toBeEnabled()
  })

  test('input field accepts typed text', async ({ page }) => {
    const textarea = page.locator('.chat-input textarea')
    await textarea.fill('Test message input')
    await expect(textarea).toHaveValue('Test message input')
  })

  test('typing and clicking Send adds a user message bubble', async ({ page }) => {
    // The channel push won't succeed without a real socket, but the user message
    // is added optimistically before the channel push
    await page.locator('.chat-input textarea').fill('Hello assistant')
    await page.locator('.chat-input button').click()

    const userMessage = page.locator('.message.user').first()
    await expect(userMessage).toBeVisible()
    await expect(userMessage).toContainText('Hello assistant')
  })

  test('input is cleared after sending a message', async ({ page }) => {
    await page.locator('.chat-input textarea').fill('Cleared after send')
    await page.locator('.chat-input button').click()
    await expect(page.locator('.chat-input textarea')).toHaveValue('')
  })

  test('pressing Enter in the textarea sends the message', async ({ page }) => {
    await page.locator('.chat-input textarea').fill('Enter key message')
    await page.locator('.chat-input textarea').press('Enter')
    const userMessage = page.locator('.message.user').first()
    await expect(userMessage).toBeVisible()
    await expect(userMessage).toContainText('Enter key message')
  })

  test('messages area is visible', async ({ page }) => {
    await expect(page.locator('.messages')).toBeVisible()
  })
})
