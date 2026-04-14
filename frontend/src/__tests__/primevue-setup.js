import { config } from '@vue/test-utils'
import PrimeVue from 'primevue/config'
import ToastService from 'primevue/toastservice'
import ConfirmationService from 'primevue/confirmationservice'
import Aura from '@primeuix/themes/aura'

// Initialize PrimeVue globally for all tests with unstyled mode
// to prevent PrimeVue CSS conflicts in test environment
config.global.plugins = config.global.plugins || []
config.global.config = config.global.config || {}

export function setupPrimeVue(app) {
  app.use(PrimeVue, {
    unstyled: true,
    theme: {
      preset: Aura,
      options: {
        darkModeSelector: '.dark'
      }
    }
  })
  app.use(ToastService)
  app.use(ConfirmationService)
}
