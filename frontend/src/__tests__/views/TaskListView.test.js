import { describe, it, expect, beforeEach, vi } from 'vitest'
import { mount } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'
import { reactive } from 'vue'

// --- Store mocks ---
// Use reactive() so Vue auto-unwraps properties in templates
const taskStore = reactive({
  tasks: [],
  loading: false,
  fetchTasks: vi.fn(),
  confirmTask: vi.fn(),
  dismissTask: vi.fn(),
  markDone: vi.fn()
})

vi.mock('@/stores/tasks', () => ({
  useTaskStore: () => taskStore
}))

const chatStore = reactive({
  setViewContext: vi.fn()
})
vi.mock('@/stores/chat', () => ({
  useChatStore: () => chatStore
}))

import TaskListView from '@/views/TaskListView.vue'

function mountView() {
  return mount(TaskListView, {
    global: {
      plugins: [createPinia()]
    }
  })
}

describe('TaskListView', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    taskStore.tasks = []
    taskStore.loading = false
    taskStore.fetchTasks.mockClear()
    taskStore.confirmTask.mockClear()
    taskStore.dismissTask.mockClear()
    taskStore.markDone.mockClear()
    chatStore.setViewContext.mockClear()
  })

  describe('loading state', () => {
    it('renders loading message when loading is true', () => {
      taskStore.loading = true
      const wrapper = mountView()
      expect(wrapper.find('.loading').text()).toBe('Loading...')
    })

    it('does not render task cards when loading is true', () => {
      taskStore.loading = true
      const wrapper = mountView()
      expect(wrapper.find('.tasks').exists()).toBe(false)
    })
  })

  describe('empty state', () => {
    it('renders "No tasks found." when tasks array is empty and not loading', () => {
      taskStore.tasks = []
      taskStore.loading = false
      const wrapper = mountView()
      expect(wrapper.find('.empty').text()).toBe('No tasks found.')
    })
  })

  describe('task cards', () => {
    const sampleTasks = [
      {
        id: 1,
        title: 'Review PR',
        task_type: 'code_review',
        status: 'created',
        importance: 0.8,
        confidence: 0.9,
        description: 'Review the open pull request',
        scheduled_action_at: null
      },
      {
        id: 2,
        title: 'Send report',
        task_type: 'email',
        status: 'confirmed',
        importance: 0.5,
        confidence: 0.75,
        description: null,
        scheduled_action_at: null
      }
    ]

    beforeEach(() => {
      taskStore.tasks = sampleTasks
    })

    it('renders a task card for each task', () => {
      const wrapper = mountView()
      expect(wrapper.findAll('.task-card')).toHaveLength(2)
    })

    it('renders the task title in each card', () => {
      const wrapper = mountView()
      const cards = wrapper.findAll('.task-card')
      expect(cards[0].find('h3').text()).toBe('Review PR')
      expect(cards[1].find('h3').text()).toBe('Send report')
    })

    it('renders the task_type badge in each card', () => {
      const wrapper = mountView()
      const cards = wrapper.findAll('.task-card')
      expect(cards[0].find('.task-type-badge').text()).toBe('code_review')
      expect(cards[1].find('.task-type-badge').text()).toBe('email')
    })

    it('renders confidence as a percentage', () => {
      const wrapper = mountView()
      const cards = wrapper.findAll('.task-card')
      expect(cards[0].find('.confidence').text()).toBe('90% confidence')
      expect(cards[1].find('.confidence').text()).toBe('75% confidence')
    })

    it('renders task description when present', () => {
      const wrapper = mountView()
      expect(wrapper.findAll('.task-card')[0].find('p').text()).toBe('Review the open pull request')
    })

    it('does not render description paragraph when description is null', () => {
      const wrapper = mountView()
      expect(wrapper.findAll('.task-card')[1].find('p').exists()).toBe(false)
    })
  })

  describe('Confirm button', () => {
    it('is shown only for tasks with status "created"', () => {
      taskStore.tasks = [
        { id: 1, title: 'A', status: 'created', importance: 0.5, confidence: 0.5, task_type: 'x' }
      ]
      const wrapper = mountView()
      expect(wrapper.find('.btn-confirm').exists()).toBe(true)
    })

    it('is not shown for tasks with status "confirmed"', () => {
      taskStore.tasks = [
        { id: 1, title: 'A', status: 'confirmed', importance: 0.5, confidence: 0.5, task_type: 'x' }
      ]
      const wrapper = mountView()
      expect(wrapper.find('.btn-confirm').exists()).toBe(false)
    })

    it('calls taskStore.confirmTask with the task id when clicked', async () => {
      taskStore.tasks = [
        { id: 42, title: 'A', status: 'created', importance: 0.5, confidence: 0.5, task_type: 'x' }
      ]
      const wrapper = mountView()
      await wrapper.find('.btn-confirm').trigger('click')
      expect(taskStore.confirmTask).toHaveBeenCalledWith(42)
    })
  })

  describe('Dismiss button', () => {
    it('is shown for tasks with status "created"', () => {
      taskStore.tasks = [
        { id: 1, title: 'A', status: 'created', importance: 0.5, confidence: 0.5, task_type: 'x' }
      ]
      const wrapper = mountView()
      expect(wrapper.find('.btn-dismiss').exists()).toBe(true)
    })

    it('is not shown for tasks with status "done"', () => {
      taskStore.tasks = [
        { id: 1, title: 'A', status: 'done', importance: 0.5, confidence: 0.5, task_type: 'x' }
      ]
      const wrapper = mountView()
      expect(wrapper.find('.btn-dismiss').exists()).toBe(false)
    })

    it('is not shown for tasks with status "dismissed"', () => {
      taskStore.tasks = [
        { id: 1, title: 'A', status: 'dismissed', importance: 0.5, confidence: 0.5, task_type: 'x' }
      ]
      const wrapper = mountView()
      expect(wrapper.find('.btn-dismiss').exists()).toBe(false)
    })

    it('calls taskStore.dismissTask with the task id when clicked', async () => {
      taskStore.tasks = [
        { id: 7, title: 'A', status: 'created', importance: 0.5, confidence: 0.5, task_type: 'x' }
      ]
      const wrapper = mountView()
      await wrapper.find('.btn-dismiss').trigger('click')
      expect(taskStore.dismissTask).toHaveBeenCalledWith(7)
    })
  })

  describe('Done button', () => {
    it('is shown for tasks with status "confirmed"', () => {
      taskStore.tasks = [
        { id: 1, title: 'A', status: 'confirmed', importance: 0.5, confidence: 0.5, task_type: 'x' }
      ]
      const wrapper = mountView()
      expect(wrapper.find('.btn-done').exists()).toBe(true)
    })

    it('is shown for tasks with status "in_progress"', () => {
      taskStore.tasks = [
        { id: 1, title: 'A', status: 'in_progress', importance: 0.5, confidence: 0.5, task_type: 'x' }
      ]
      const wrapper = mountView()
      expect(wrapper.find('.btn-done').exists()).toBe(true)
    })

    it('is not shown for tasks with status "created"', () => {
      taskStore.tasks = [
        { id: 1, title: 'A', status: 'created', importance: 0.5, confidence: 0.5, task_type: 'x' }
      ]
      const wrapper = mountView()
      expect(wrapper.find('.btn-done').exists()).toBe(false)
    })

    it('calls taskStore.markDone with the task id when clicked', async () => {
      taskStore.tasks = [
        { id: 9, title: 'A', status: 'confirmed', importance: 0.5, confidence: 0.5, task_type: 'x' }
      ]
      const wrapper = mountView()
      await wrapper.find('.btn-done').trigger('click')
      expect(taskStore.markDone).toHaveBeenCalledWith(9)
    })
  })

  describe('filter buttons', () => {
    it('renders all four filter buttons', () => {
      const wrapper = mountView()
      const buttons = wrapper.findAll('.filter-btn')
      expect(buttons).toHaveLength(4)
    })

    it('renders All, Confirmed, Review, Done labels', () => {
      const wrapper = mountView()
      const labels = wrapper.findAll('.filter-btn').map(b => b.text())
      expect(labels).toEqual(['All', 'Confirmed', 'Review', 'Done'])
    })

    it('calls fetchTasks with null when "All" is clicked', async () => {
      const wrapper = mountView()
      vi.clearAllMocks()
      await wrapper.findAll('.filter-btn')[0].trigger('click')
      expect(taskStore.fetchTasks).toHaveBeenCalledWith(null)
    })

    it('calls fetchTasks with "confirmed" when Confirmed filter is clicked', async () => {
      const wrapper = mountView()
      vi.clearAllMocks()
      await wrapper.findAll('.filter-btn')[1].trigger('click')
      expect(taskStore.fetchTasks).toHaveBeenCalledWith('confirmed')
    })

    it('calls fetchTasks with "created" when Review filter is clicked', async () => {
      const wrapper = mountView()
      vi.clearAllMocks()
      await wrapper.findAll('.filter-btn')[2].trigger('click')
      expect(taskStore.fetchTasks).toHaveBeenCalledWith('created')
    })

    it('applies "active" class to the currently selected filter button', async () => {
      const wrapper = mountView()
      const confirmedBtn = wrapper.findAll('.filter-btn')[1]
      await confirmedBtn.trigger('click')
      expect(confirmedBtn.classes()).toContain('active')
    })

    it('removes "active" class from a previously selected filter when a new one is clicked', async () => {
      const wrapper = mountView()
      const allBtn = wrapper.findAll('.filter-btn')[0]
      const confirmedBtn = wrapper.findAll('.filter-btn')[1]
      await allBtn.trigger('click')
      await confirmedBtn.trigger('click')
      expect(allBtn.classes()).not.toContain('active')
      expect(confirmedBtn.classes()).toContain('active')
    })
  })

  describe('onMounted', () => {
    it('calls fetchTasks on mount', () => {
      mountView()
      expect(taskStore.fetchTasks).toHaveBeenCalledTimes(1)
    })

    it('sets view context on mount', () => {
      mountView()
      expect(chatStore.setViewContext).toHaveBeenCalledWith({
        view: 'task_list',
        available_actions: ['create_task', 'dismiss_task', 'confirm_task']
      })
    })
  })
})
