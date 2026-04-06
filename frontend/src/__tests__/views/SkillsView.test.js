import { describe, it, expect, beforeEach, vi } from 'vitest'
import { mount } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'

const { mockSkillsList, mockSkillsUpdate, mockSkillsGet, mockSkillsGetVersions, mockSkillsRevertVersion, mockSetViewContext } = vi.hoisted(() => ({
  mockSkillsList: vi.fn(),
  mockSkillsUpdate: vi.fn(),
  mockSkillsGet: vi.fn(),
  mockSkillsGetVersions: vi.fn(),
  mockSkillsRevertVersion: vi.fn(),
  mockSetViewContext: vi.fn()
}))

vi.mock('@/api', () => ({
  skillsApi: {
    list: mockSkillsList,
    update: mockSkillsUpdate,
    get: mockSkillsGet,
    getVersions: mockSkillsGetVersions,
    revertVersion: mockSkillsRevertVersion
  }
}))

vi.mock('@/stores/chat', () => ({
  useChatStore: () => ({
    setViewContext: mockSetViewContext
  })
}))

import SkillsView from '@/views/SkillsView.vue'

function mountView() {
  return mount(SkillsView, {
    global: {
      plugins: [createPinia()]
    }
  })
}

// Returns a fresh array each call to avoid cross-test mutation
function makeSkills() {
  return [
    {
      id: 1,
      name: 'Email Responder',
      namespace: 'email',
      version: '1.0',
      author: 'alice',
      active: true,
      locked: false
    },
    {
      id: 2,
      name: 'Task Creator',
      namespace: 'tasks',
      version: '2.1',
      author: 'bob',
      active: false,
      locked: true
    }
  ]
}

describe('SkillsView', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    vi.clearAllMocks()
  })

  describe('loading state', () => {
    it('shows loading message while fetching', () => {
      mockSkillsList.mockReturnValueOnce(new Promise(() => {}))
      const wrapper = mountView()
      expect(wrapper.find('.loading').exists()).toBe(true)
      expect(wrapper.find('.loading').text()).toBe('Loading...')
    })

    it('does not show skills grid while loading', () => {
      mockSkillsList.mockReturnValueOnce(new Promise(() => {}))
      const wrapper = mountView()
      expect(wrapper.find('.skills-layout').exists()).toBe(false)
    })
  })

  describe('skills grid', () => {
    it('renders a card for each skill', async () => {
      mockSkillsList.mockResolvedValueOnce({ data: { skills: makeSkills() } })
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      expect(wrapper.findAll('.skill-card')).toHaveLength(2)
    })

    it('renders the skill name in each card', async () => {
      mockSkillsList.mockResolvedValueOnce({ data: { skills: makeSkills() } })
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      const cards = wrapper.findAll('.skill-card')
      expect(cards[0].find('.skill-name').text()).toBe('Email Responder')
      expect(cards[1].find('.skill-name').text()).toBe('Task Creator')
    })

    it('renders the namespace badge', async () => {
      mockSkillsList.mockResolvedValueOnce({ data: { skills: makeSkills() } })
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      const cards = wrapper.findAll('.skill-card')
      expect(cards[0].find('.badge.namespace').text()).toBe('email')
    })

    it('renders version and author in meta', async () => {
      mockSkillsList.mockResolvedValueOnce({ data: { skills: makeSkills() } })
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      const meta = wrapper.findAll('.skill-card')[0].find('.skill-meta').text()
      expect(meta).toContain('1.0')
      expect(meta).toContain('alice')
    })

    it('shows Locked badge for locked skills', async () => {
      mockSkillsList.mockResolvedValueOnce({ data: { skills: makeSkills() } })
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      const cards = wrapper.findAll('.skill-card')
      expect(cards[0].find('.badge.locked').exists()).toBe(false)
      expect(cards[1].find('.badge.locked').exists()).toBe(true)
    })

    it('shows Inactive badge for inactive skills', async () => {
      mockSkillsList.mockResolvedValueOnce({ data: { skills: makeSkills() } })
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      const cards = wrapper.findAll('.skill-card')
      expect(cards[0].find('.badge.inactive').exists()).toBe(false)
      expect(cards[1].find('.badge.inactive').exists()).toBe(true)
    })

    it('renders "Deactivate" button for active skills', async () => {
      mockSkillsList.mockResolvedValueOnce({ data: { skills: makeSkills() } })
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      expect(wrapper.findAll('.skill-card')[0].find('.btn-deactivate').exists()).toBe(true)
      expect(wrapper.findAll('.skill-card')[0].find('.btn-deactivate').text()).toBe('Deactivate')
    })

    it('renders "Activate" button for inactive skills', async () => {
      mockSkillsList.mockResolvedValueOnce({ data: { skills: makeSkills() } })
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      expect(wrapper.findAll('.skill-card')[1].find('.btn-activate').exists()).toBe(true)
      expect(wrapper.findAll('.skill-card')[1].find('.btn-activate').text()).toBe('Activate')
    })

    it('renders empty list when no skills', async () => {
      mockSkillsList.mockResolvedValueOnce({ data: { skills: [] } })
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      expect(wrapper.find('.skills-list').exists()).toBe(true)
      expect(wrapper.findAll('.skill-card')).toHaveLength(0)
    })
  })

  describe('toggleActive', () => {
    it('calls skillsApi.update with flipped active when Deactivate is clicked', async () => {
      const skills = makeSkills()
      mockSkillsList.mockResolvedValueOnce({ data: { skills } })
      mockSkillsUpdate.mockResolvedValueOnce({
        data: { skill: { ...skills[0], active: false } }
      })
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      await wrapper.findAll('.skill-card')[0].find('.btn-deactivate').trigger('click')
      expect(mockSkillsUpdate).toHaveBeenCalledWith(1, { active: false })
    })

    it('calls skillsApi.update with flipped active when Activate is clicked', async () => {
      const skills = makeSkills()
      mockSkillsList.mockResolvedValueOnce({ data: { skills } })
      mockSkillsUpdate.mockResolvedValueOnce({
        data: { skill: { ...skills[1], active: true } }
      })
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      await wrapper.findAll('.skill-card')[1].find('.btn-activate').trigger('click')
      expect(mockSkillsUpdate).toHaveBeenCalledWith(2, { active: true })
    })

    it('updates skill in the list after successful toggle', async () => {
      const skills = makeSkills()
      mockSkillsList.mockResolvedValueOnce({ data: { skills } })
      mockSkillsUpdate.mockResolvedValueOnce({
        data: { skill: { ...skills[0], active: false } }
      })
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      await wrapper.findAll('.skill-card')[0].find('.btn-deactivate').trigger('click')
      await new Promise(r => setTimeout(r, 0))
      expect(wrapper.findAll('.skill-card')[0].find('.btn-activate').exists()).toBe(true)
    })
  })

  describe('skill editor', () => {
    it('shows editor-empty message when no skill selected', async () => {
      mockSkillsList.mockResolvedValueOnce({ data: { skills: makeSkills() } })
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      expect(wrapper.find('.editor-empty').exists()).toBe(true)
    })

    it('shows skill editor panel after clicking a skill', async () => {
      const skills = makeSkills()
      mockSkillsList.mockResolvedValueOnce({ data: { skills } })
      mockSkillsGet.mockResolvedValueOnce({ data: { skill: { ...skills[0], content: '---\nname: test\n---\nbody' } } })
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      await wrapper.findAll('.skill-card')[0].trigger('click')
      await new Promise(r => setTimeout(r, 0))
      expect(wrapper.find('.skill-editor').exists()).toBe(true)
    })

    it('loads skill content on selection', async () => {
      const skills = makeSkills()
      mockSkillsList.mockResolvedValueOnce({ data: { skills } })
      mockSkillsGet.mockResolvedValueOnce({ data: { skill: { ...skills[0], content: '---\nname: test\n---\nbody text' } } })
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      await wrapper.findAll('.skill-card')[0].trigger('click')
      await new Promise(r => setTimeout(r, 0))
      expect(wrapper.find('.content-textarea').element.value).toContain('body text')
    })

    it('calls skillsApi.get with skill id when skill is selected', async () => {
      const skills = makeSkills()
      mockSkillsList.mockResolvedValueOnce({ data: { skills } })
      mockSkillsGet.mockResolvedValueOnce({ data: { skill: { ...skills[0], content: '' } } })
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      await wrapper.findAll('.skill-card')[0].trigger('click')
      expect(mockSkillsGet).toHaveBeenCalledWith(1)
    })

    it('saves content when Save button clicked', async () => {
      const skills = makeSkills()
      mockSkillsList.mockResolvedValueOnce({ data: { skills } })
      mockSkillsGet.mockResolvedValueOnce({ data: { skill: { ...skills[0], content: 'original' } } })
      mockSkillsUpdate.mockResolvedValueOnce({ data: { skill: { ...skills[0], content: 'updated' } } })
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      await wrapper.findAll('.skill-card')[0].trigger('click')
      await new Promise(r => setTimeout(r, 0))
      await wrapper.find('.btn-save').trigger('click')
      expect(mockSkillsUpdate).toHaveBeenCalledWith(1, { content: 'original' })
    })

    it('shows "Saved." after successful save', async () => {
      const skills = makeSkills()
      mockSkillsList.mockResolvedValueOnce({ data: { skills } })
      mockSkillsGet.mockResolvedValueOnce({ data: { skill: { ...skills[0], content: 'c' } } })
      mockSkillsUpdate.mockResolvedValueOnce({ data: { skill: { ...skills[0], content: 'c' } } })
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      await wrapper.findAll('.skill-card')[0].trigger('click')
      await new Promise(r => setTimeout(r, 0))
      await wrapper.find('.btn-save').trigger('click')
      await new Promise(r => setTimeout(r, 0))
      expect(wrapper.find('.save-success').exists()).toBe(true)
    })

    it('switches to versions tab when Versions tab clicked', async () => {
      const skills = makeSkills()
      mockSkillsList.mockResolvedValueOnce({ data: { skills } })
      mockSkillsGet.mockResolvedValueOnce({ data: { skill: { ...skills[0], content: 'c' } } })
      mockSkillsGetVersions.mockResolvedValueOnce({ data: { versions: [] } })
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      await wrapper.findAll('.skill-card')[0].trigger('click')
      await new Promise(r => setTimeout(r, 0))
      const tabs = wrapper.findAll('.tab-btn')
      await tabs[1].trigger('click')
      expect(mockSkillsGetVersions).toHaveBeenCalledWith(1)
    })

    it('shows version list items after loading versions', async () => {
      const skills = makeSkills()
      mockSkillsList.mockResolvedValueOnce({ data: { skills } })
      mockSkillsGet.mockResolvedValueOnce({ data: { skill: { ...skills[0], content: 'c' } } })
      const versions = [
        { id: 'v1', version: 1, author: 'system', content: 'old', inserted_at: '2024-01-01T00:00:00Z' },
        { id: 'v2', version: 2, author: 'llm', content: 'newer', inserted_at: '2024-02-01T00:00:00Z' }
      ]
      mockSkillsGetVersions.mockResolvedValueOnce({ data: { versions } })
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      await wrapper.findAll('.skill-card')[0].trigger('click')
      await new Promise(r => setTimeout(r, 0))
      await wrapper.findAll('.tab-btn')[1].trigger('click')
      await new Promise(r => setTimeout(r, 0))
      expect(wrapper.findAll('.version-item')).toHaveLength(2)
    })

    it('selects version and shows content preview when version item clicked', async () => {
      const skills = makeSkills()
      mockSkillsList.mockResolvedValueOnce({ data: { skills } })
      mockSkillsGet.mockResolvedValueOnce({ data: { skill: { ...skills[0], content: 'c' } } })
      const versions = [
        { id: 'v1', version: 1, author: 'system', content: 'version one content', inserted_at: '2024-01-01T00:00:00Z' }
      ]
      mockSkillsGetVersions.mockResolvedValueOnce({ data: { versions } })
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      await wrapper.findAll('.skill-card')[0].trigger('click')
      await new Promise(r => setTimeout(r, 0))
      await wrapper.findAll('.tab-btn')[1].trigger('click')
      await new Promise(r => setTimeout(r, 0))
      await wrapper.find('.version-item').trigger('click')
      await new Promise(r => setTimeout(r, 0))
      expect(wrapper.find('.content-textarea.readonly').element.value).toBe('version one content')
    })

    it('calls revertVersion when Revert button is clicked', async () => {
      const skills = makeSkills()
      mockSkillsList.mockResolvedValueOnce({ data: { skills } })
      mockSkillsGet.mockResolvedValueOnce({ data: { skill: { ...skills[0], content: 'c' } } })
      const versions = [
        { id: 'v1', version: 1, author: 'system', content: 'old', inserted_at: '2024-01-01T00:00:00Z' }
      ]
      mockSkillsGetVersions.mockResolvedValueOnce({ data: { versions } })
      mockSkillsRevertVersion.mockResolvedValueOnce({ data: { skill: { ...skills[0], content: 'old' } } })
      const wrapper = mountView()
      await new Promise(r => setTimeout(r, 0))
      await wrapper.findAll('.skill-card')[0].trigger('click')
      await new Promise(r => setTimeout(r, 0))
      await wrapper.findAll('.tab-btn')[1].trigger('click')
      await new Promise(r => setTimeout(r, 0))
      await wrapper.find('.version-item').trigger('click')
      await new Promise(r => setTimeout(r, 0))
      await wrapper.find('.version-preview .btn-save').trigger('click')
      expect(mockSkillsRevertVersion).toHaveBeenCalledWith(1, 'v1')
    })
  })

  describe('onMounted', () => {
    it('calls skillsApi.list on mount', () => {
      mockSkillsList.mockReturnValueOnce(new Promise(() => {}))
      mountView()
      expect(mockSkillsList).toHaveBeenCalledTimes(1)
    })

    it('sets view context on mount', () => {
      mockSkillsList.mockReturnValueOnce(new Promise(() => {}))
      mountView()
      expect(mockSetViewContext).toHaveBeenCalledWith({
        view: 'skill_editor',
        available_actions: ['list_skills', 'trigger_skill']
      })
    })
  })
})
