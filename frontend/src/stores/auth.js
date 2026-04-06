import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import api from '@/api'

export const useAuthStore = defineStore('auth', () => {
  const token = ref(localStorage.getItem('kontor_token'))
  const user = ref(JSON.parse(localStorage.getItem('kontor_user') || 'null'))

  const isAuthenticated = computed(() => !!token.value)

  function setAuth(newToken, newUser) {
    token.value = newToken
    user.value = newUser
    localStorage.setItem('kontor_token', newToken)
    localStorage.setItem('kontor_user', JSON.stringify(newUser))
    api.defaults.headers.common['Authorization'] = `Bearer ${newToken}`
  }

  function clearAuth() {
    token.value = null
    user.value = null
    localStorage.removeItem('kontor_token')
    localStorage.removeItem('kontor_user')
    delete api.defaults.headers.common['Authorization']
  }

  // Initialize axios header if token exists
  if (token.value) {
    api.defaults.headers.common['Authorization'] = `Bearer ${token.value}`
  }

  return { token, user, isAuthenticated, setAuth, clearAuth }
})
