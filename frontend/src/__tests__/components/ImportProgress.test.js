import { describe, it, expect } from 'vitest'
import { mount } from '@vue/test-utils'
import ImportProgress from '@/components/ImportProgress.vue'

function mountComponent(progress) {
  return mount(ImportProgress, {
    props: { progress, unstyled: false }
  })
}

describe('ImportProgress', () => {
  describe('progress text', () => {
    it('renders "Processing X of Y" text', () => {
      const wrapper = mountComponent({ current: 3, total: 10 })
      expect(wrapper.find('.progress-text').text()).toBe('Processing 3 of 10')
    })

    it('renders correct values when current equals total', () => {
      const wrapper = mountComponent({ current: 10, total: 10 })
      expect(wrapper.find('.progress-text').text()).toBe('Processing 10 of 10')
    })

    it('renders correctly at zero progress', () => {
      const wrapper = mountComponent({ current: 0, total: 100 })
      expect(wrapper.find('.progress-text').text()).toBe('Processing 0 of 100')
    })
  })

  describe('progress bar fill', () => {
    it('sets width to 30% when 3 of 10 processed', () => {
      const wrapper = mountComponent({ current: 3, total: 10 })
      // PrimeVue ProgressBar applies width via inline style on the value div
      const fill = wrapper.find('[data-pc-section="value"]')
      expect(fill.exists()).toBe(true)
      expect(fill.attributes('style')).toContain('width: 30%')
    })

    it('sets width to 100% when current equals total', () => {
      const wrapper = mountComponent({ current: 5, total: 5 })
      expect(wrapper.find('[data-pc-section="value"]').attributes('style')).toContain('width: 100%')
    })

    it('sets width to 0% when total is 0', () => {
      const wrapper = mountComponent({ current: 0, total: 0 })
      expect(wrapper.find('[data-pc-section="value"]').attributes('style')).toContain('width: 0%')
    })

    it('sets width to 50% when halfway through', () => {
      const wrapper = mountComponent({ current: 50, total: 100 })
      expect(wrapper.find('[data-pc-section="value"]').attributes('style')).toContain('width: 50%')
    })

    it('rounds percent to nearest integer', () => {
      const wrapper = mountComponent({ current: 1, total: 3 })
      expect(wrapper.find('[data-pc-section="value"]').attributes('style')).toContain('width: 33%')
    })
  })

  describe('structure', () => {
    it('renders .progress-bar wrapper', () => {
      const wrapper = mountComponent({ current: 0, total: 10 })
      expect(wrapper.find('.progress-bar').exists()).toBe(true)
    })

    it('renders PrimeVue progress bar element inside .progress-bar', () => {
      const wrapper = mountComponent({ current: 0, total: 10 })
      // PrimeVue ProgressBar value div uses data-pc-section="value"
      expect(wrapper.find('.progress-bar [data-pc-section="value"]').exists()).toBe(true)
    })
  })
})
