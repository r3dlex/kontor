import { describe, it, expect, beforeEach, vi } from 'vitest'
import { mount } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'
import { reactive } from 'vue'

const searchStore = reactive({
  results: [],
  loading: false,
  query: '',
  search: vi.fn()
})

vi.mock('@/stores/search', () => ({
  useSearchStore: () => searchStore
}))

import SearchView from '@/views/SearchView.vue'

function mountView() {
  return mount(SearchView, {
    global: { plugins: [createPinia()] }
  })
}

describe('SearchView', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    searchStore.results = []
    searchStore.loading = false
    searchStore.query = ''
    searchStore.search.mockClear()
  })

  describe('layout', () => {
    it('renders Search heading', () => {
      const wrapper = mountView()
      expect(wrapper.find('h2').text()).toBe('Search')
    })

    it('renders search input', () => {
      const wrapper = mountView()
      expect(wrapper.find('.search-input').exists()).toBe(true)
    })

    it('renders search button', () => {
      const wrapper = mountView()
      expect(wrapper.find('.search-btn').text()).toBe('Search')
    })

    it('input has correct placeholder', () => {
      const wrapper = mountView()
      expect(wrapper.find('.search-input').attributes('placeholder')).toBe('Search threads...')
    })
  })

  describe('loading state', () => {
    it('shows "Searching..." button label when loading', () => {
      searchStore.loading = true
      const wrapper = mountView()
      expect(wrapper.find('.search-btn').text()).toBe('Searching...')
    })

    it('disables button while loading', () => {
      searchStore.loading = true
      const wrapper = mountView()
      expect(wrapper.find('.search-btn').attributes('disabled')).toBeDefined()
    })

    it('shows loading message while searching', () => {
      searchStore.loading = true
      const wrapper = mountView()
      expect(wrapper.find('.loading').exists()).toBe(true)
    })
  })

  describe('empty state', () => {
    it('does not show "No results found." before first search', () => {
      const wrapper = mountView()
      expect(wrapper.find('.empty').exists()).toBe(false)
    })

    it('shows "No results found." after search with no results', async () => {
      searchStore.search.mockResolvedValueOnce(undefined)
      const wrapper = mountView()
      await wrapper.find('.search-input').setValue('nothing')
      await wrapper.find('.search-btn').trigger('click')
      await new Promise(r => setTimeout(r, 0))
      expect(wrapper.find('.empty').text()).toBe('No results found.')
    })
  })

  describe('results', () => {
    it('renders a result card for each result', async () => {
      searchStore.results = [
        { id: 1, subject: 'Thread A', type: 'thread', similarity_score: 0.92 },
        { id: 2, subject: 'Thread B', type: 'thread', similarity_score: 0.75 }
      ]
      searchStore.search.mockResolvedValueOnce(undefined)
      const wrapper = mountView()
      await wrapper.find('.search-input').setValue('test')
      await wrapper.find('.search-btn').trigger('click')
      await new Promise(r => setTimeout(r, 0))
      expect(wrapper.findAll('.result-card')).toHaveLength(2)
    })

    it('renders result subject', async () => {
      searchStore.results = [
        { id: 1, subject: 'Thread Alpha', type: 'thread', similarity_score: 0.9 }
      ]
      searchStore.search.mockResolvedValueOnce(undefined)
      const wrapper = mountView()
      await wrapper.find('.search-input').setValue('alpha')
      await wrapper.find('.search-btn').trigger('click')
      await new Promise(r => setTimeout(r, 0))
      expect(wrapper.find('.result-subject').text()).toBe('Thread Alpha')
    })

    it('renders similarity score as percentage', async () => {
      searchStore.results = [
        { id: 1, subject: 'Thread A', type: 'thread', similarity_score: 0.87 }
      ]
      searchStore.search.mockResolvedValueOnce(undefined)
      const wrapper = mountView()
      await wrapper.find('.search-input').setValue('test')
      await wrapper.find('.search-btn').trigger('click')
      await new Promise(r => setTimeout(r, 0))
      expect(wrapper.find('.result-score').text()).toBe('87% match')
    })

    it('renders result type', async () => {
      searchStore.results = [
        { id: 1, subject: 'Thread A', type: 'thread', similarity_score: 0.9 }
      ]
      searchStore.search.mockResolvedValueOnce(undefined)
      const wrapper = mountView()
      await wrapper.find('.search-input').setValue('test')
      await wrapper.find('.search-btn').trigger('click')
      await new Promise(r => setTimeout(r, 0))
      expect(wrapper.find('.result-type').text()).toBe('thread')
    })
  })

  describe('handleSearch', () => {
    it('calls store.search with query when button clicked', async () => {
      searchStore.search.mockResolvedValueOnce(undefined)
      const wrapper = mountView()
      await wrapper.find('.search-input').setValue('my query')
      await wrapper.find('.search-btn').trigger('click')
      expect(searchStore.search).toHaveBeenCalledWith('my query')
    })

    it('calls store.search when Enter is pressed in input', async () => {
      searchStore.search.mockResolvedValueOnce(undefined)
      const wrapper = mountView()
      await wrapper.find('.search-input').setValue('enter query')
      await wrapper.find('.search-input').trigger('keydown.enter')
      expect(searchStore.search).toHaveBeenCalledWith('enter query')
    })

    it('does not call store.search when query is empty', async () => {
      const wrapper = mountView()
      await wrapper.find('.search-btn').trigger('click')
      expect(searchStore.search).not.toHaveBeenCalled()
    })

    it('does not call store.search when query is only whitespace', async () => {
      const wrapper = mountView()
      await wrapper.find('.search-input').setValue('   ')
      await wrapper.find('.search-btn').trigger('click')
      expect(searchStore.search).not.toHaveBeenCalled()
    })
  })
})
