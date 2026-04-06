import { describe, it, expect } from 'vitest'
import { mount } from '@vue/test-utils'
import { createPinia } from 'pinia'
import LoginView from '@/views/LoginView.vue'

function mountView() {
  return mount(LoginView, {
    global: {
      plugins: [createPinia()]
    }
  })
}

describe('LoginView', () => {
  describe('layout', () => {
    it('renders the app logo', () => {
      const wrapper = mountView()
      expect(wrapper.find('.logo-wrap svg').exists()).toBe(true)
    })

    it('renders the subtitle', () => {
      const wrapper = mountView()
      expect(wrapper.find('.subtitle').text()).toBe('AI-driven email, unified.')
    })

    it('renders the Google auth link', () => {
      const wrapper = mountView()
      const link = wrapper.find('.btn-google')
      expect(link.exists()).toBe(true)
      expect(link.text()).toBe('Continue with Google')
    })

    it('renders the Microsoft auth link', () => {
      const wrapper = mountView()
      const link = wrapper.find('.btn-microsoft')
      expect(link.exists()).toBe(true)
      expect(link.text()).toBe('Continue with Microsoft')
    })

    it('Google link points to the correct auth URL', () => {
      const wrapper = mountView()
      expect(wrapper.find('.btn-google').attributes('href')).toBe('/api/v1/auth/google/redirect')
    })

    it('Microsoft link points to the correct auth URL', () => {
      const wrapper = mountView()
      expect(wrapper.find('.btn-microsoft').attributes('href')).toBe('/api/v1/auth/microsoft/redirect')
    })

    it('renders both action links inside .actions container', () => {
      const wrapper = mountView()
      const links = wrapper.findAll('.actions a')
      expect(links).toHaveLength(2)
    })
  })
})
