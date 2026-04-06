import { test, expect } from '@playwright/test'

const MOCK_TASKS = [
  {
    id: 1,
    title: 'Review quarterly report',
    task_type: 'document_review',
    status: 'created',
    importance: 0.9,
    confidence: 0.85,
    description: 'Review and approve the Q4 report',
    scheduled_action_at: null
  },
  {
    id: 2,
    title: 'Reply to Alice',
    task_type: 'email_reply',
    status: 'confirmed',
    importance: 0.6,
    confidence: 0.7,
    description: null,
    scheduled_action_at: null
  },
  {
    id: 3,
    title: 'Book flight',
    task_type: 'booking',
    status: 'done',
    importance: 0.4,
    confidence: 0.95,
    description: null,
    scheduled_action_at: null
  }
]

async function setupAuth(page) {
  await page.addInitScript(() => {
    localStorage.setItem('kontor_token', 'test-token')
    localStorage.setItem('kontor_user', JSON.stringify({ id: 1, name: 'Test User' }))
  })
}

test.describe('Task list', () => {
  test.beforeEach(async ({ page }) => {
    await setupAuth(page)

    // Mock GET /tasks (any params)
    await page.route('/api/v1/tasks**', (route) => {
      const url = new URL(route.request().url())
      const status = url.searchParams.get('status')
      const filtered = status
        ? MOCK_TASKS.filter(t => t.status === status)
        : MOCK_TASKS
      route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({ tasks: filtered })
      })
    })

    // Mock Phoenix WebSocket to avoid connection errors
    await page.route('/socket/**', (route) => route.abort())

    await page.goto('/tasks')
  })

  test('task list loads and displays task titles', async ({ page }) => {
    await expect(page.locator('.task-card')).toHaveCount(3)
    await expect(page.locator('h3').first()).toContainText('Review quarterly report')
  })

  test('displays the task type badge for each task', async ({ page }) => {
    const badges = page.locator('.task-type-badge')
    await expect(badges.first()).toContainText('document_review')
  })

  test('displays confidence percentage for each task', async ({ page }) => {
    await expect(page.locator('.confidence').first()).toContainText('85% confidence')
  })

  test('shows Confirm button for "created" status tasks', async ({ page }) => {
    await expect(page.locator('.btn-confirm').first()).toBeVisible()
  })

  test('shows Done button for "confirmed" status tasks', async ({ page }) => {
    await expect(page.locator('.btn-done').first()).toBeVisible()
  })

  test('Confirm action sends PATCH request with status confirmed', async ({ page }) => {
    let patchCalled = false
    let patchBody = null

    await page.route('/api/v1/tasks/1', (route) => {
      if (route.request().method() === 'PATCH') {
        patchCalled = true
        patchBody = route.request().postDataJSON()
        route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify({ task: { ...MOCK_TASKS[0], status: 'confirmed' } })
        })
      } else {
        route.continue()
      }
    })

    await page.locator('.btn-confirm').first().click()
    expect(patchCalled).toBe(true)
    expect(patchBody?.task?.status).toBe('confirmed')
  })

  test('Dismiss action sends PATCH request with status dismissed', async ({ page }) => {
    let patchBody = null

    await page.route('/api/v1/tasks/1', (route) => {
      if (route.request().method() === 'PATCH') {
        patchBody = route.request().postDataJSON()
        route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify({ task: { ...MOCK_TASKS[0], status: 'dismissed' } })
        })
      } else {
        route.continue()
      }
    })

    await page.locator('.btn-dismiss').first().click()
    expect(patchBody?.task?.status).toBe('dismissed')
  })

  test('filter buttons are rendered', async ({ page }) => {
    const buttons = page.locator('.filter-btn')
    await expect(buttons).toHaveCount(4)
  })

  test('clicking Confirmed filter fetches only confirmed tasks', async ({ page }) => {
    await page.locator('.filter-btn', { hasText: 'Confirmed' }).click()
    // After filter, only confirmed tasks should be shown
    await expect(page.locator('.task-card')).toHaveCount(1)
    await expect(page.locator('h3').first()).toContainText('Reply to Alice')
  })

  test('clicking Done filter fetches only done tasks', async ({ page }) => {
    await page.locator('.filter-btn', { hasText: 'Done' }).click()
    await expect(page.locator('.task-card')).toHaveCount(1)
    await expect(page.locator('h3').first()).toContainText('Book flight')
  })

  test('clicking All filter after another filter restores all tasks', async ({ page }) => {
    await page.locator('.filter-btn', { hasText: 'Confirmed' }).click()
    await expect(page.locator('.task-card')).toHaveCount(1)
    await page.locator('.filter-btn', { hasText: 'All' }).click()
    await expect(page.locator('.task-card')).toHaveCount(3)
  })

  test('shows "No tasks found." when filter returns empty list', async ({ page }) => {
    await page.route('/api/v1/tasks**', (route) => {
      route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({ tasks: [] })
      })
    })
    await page.locator('.filter-btn', { hasText: 'Review' }).click()
    await expect(page.locator('.empty')).toContainText('No tasks found.')
  })
})
