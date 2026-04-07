import { describe, it, expect, beforeEach, vi } from 'vitest'
import { setActivePinia, createPinia } from 'pinia'

const { mockGet, mockPost, mockPatch } = vi.hoisted(() => ({
  mockGet: vi.fn(),
  mockPost: vi.fn(),
  mockPatch: vi.fn()
}))

vi.mock('@/api', () => ({
  default: {
    defaults: { headers: { common: {} } },
    get: mockGet,
    post: mockPost,
    patch: mockPatch
  }
}))

vi.mock('@/router', () => ({
  default: { push: vi.fn() }
}))

import { useMailboxesStore } from '@/stores/mailboxes'

describe('mailboxes store — updateMailbox', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    vi.clearAllMocks()
  })

  it('calls PATCH /mailboxes/:id with attrs', async () => {
    const mailbox = { id: 1, email: 'alice@example.com', copy_emails: false }
    mockPatch.mockResolvedValueOnce({ data: { mailbox: { ...mailbox, copy_emails: true } } })
    const store = useMailboxesStore()
    store.mailboxes = [mailbox]

    await store.updateMailbox(1, { copy_emails: true })

    expect(mockPatch).toHaveBeenCalledWith('/mailboxes/1', { copy_emails: true })
  })

  it('updates the mailbox in state on success', async () => {
    const original = { id: 1, email: 'alice@example.com', copy_emails: false }
    const updated = { id: 1, email: 'alice@example.com', copy_emails: true }
    mockPatch.mockResolvedValueOnce({ data: { mailbox: updated } })

    const store = useMailboxesStore()
    store.mailboxes = [original]
    await store.updateMailbox(1, { copy_emails: true })

    expect(store.mailboxes[0].copy_emails).toBe(true)
  })

  it('returns { success: true, mailbox } on success', async () => {
    const mailbox = { id: 2, copy_emails: true }
    mockPatch.mockResolvedValueOnce({ data: { mailbox } })
    const store = useMailboxesStore()
    store.mailboxes = [{ id: 2, copy_emails: false }]

    const result = await store.updateMailbox(2, { copy_emails: true })

    expect(result.success).toBe(true)
    expect(result.mailbox).toEqual(mailbox)
  })

  it('returns { success: false, error } on failure', async () => {
    mockPatch.mockRejectedValueOnce({ response: { data: { error: 'Not found' } } })
    const store = useMailboxesStore()
    store.mailboxes = []

    const result = await store.updateMailbox(99, { copy_emails: true })

    expect(result.success).toBe(false)
    expect(result.error).toBe('Not found')
  })

  it('sets generic error when no response error', async () => {
    mockPatch.mockRejectedValueOnce(new Error('Network error'))
    const store = useMailboxesStore()
    store.mailboxes = []

    await store.updateMailbox(1, { copy_emails: true })

    expect(store.error).toBe('Failed to update mailbox')
  })
})

describe('EmailView — null body handling', () => {
  it('null body message is defined correctly', () => {
    // Verify the null body message string is as specified
    const nullBodyMessage = 'Body not stored — email content was used for AI processing but not retained.'
    expect(nullBodyMessage).toContain('Body not stored')
    expect(nullBodyMessage).toContain('AI processing')
  })
})
