import { describe, it, expect } from 'vitest'
import { mount } from '@vue/test-utils'
import ToastContainer from '@/components/ui/ToastContainer.vue'

describe('ToastContainer', () => {
  it('renders a Toast component', () => {
    const wrapper = mount(ToastContainer)
    // Toast is a globally-registered PrimeVue component; verify it's mounted
    const toastComponents = wrapper.findAllComponents({ name: 'Toast' })
    expect(toastComponents.length).toBe(1)
  })
})