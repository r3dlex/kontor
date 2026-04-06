import axios from 'axios'
import router from '@/router'

const api = axios.create({
  baseURL: '/api/v1',
  headers: { 'Content-Type': 'application/json' }
})

api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      localStorage.removeItem('kontor_token')
      router.push('/login')
    }
    return Promise.reject(error)
  }
)

export default api

// Convenience wrappers
export const tasksApi = {
  list: (params) => api.get('/tasks', { params }),
  update: (id, data) => api.patch(`/tasks/${id}`, { task: data })
}

export const emailsApi = {
  get: (id) => api.get(`/emails/${id}`),
  thread: (id) => api.get(`/threads/${id}`)
}

export const calendarApi = {
  today: () => api.get('/calendar/today'),
  briefing: (id) => api.get(`/calendar/briefing/${id}`),
  refreshBriefing: (id) => api.post(`/calendar/briefing/${id}/refresh`)
}

export const contactsApi = {
  list: (params) => api.get('/contacts', { params }),
  get: (id) => api.get(`/contacts/${id}`),
  graph: () => api.get('/contacts/graph'),
  refresh: (id) => api.post(`/contacts/${id}/refresh`)
}

export const skillsApi = {
  list: () => api.get('/skills'),
  get: (id) => api.get(`/skills/${id}`),
  update: (id, data) => api.put(`/skills/${id}`, { skill: data }),
  getVersions: (id) => api.get(`/skills/${id}/versions`),
  revertVersion: (skillId, versionId) => api.post(`/skills/${skillId}/revert`, { version_id: versionId })
}

export const draftsApi = {
  create: (data) => api.post('/drafts', { draft: data }),
  send: (id, scheduledAt) => api.post(`/drafts/${id}/send`, { scheduled_at: scheduledAt })
}

export const backOfficeApi = {
  get: () => api.get('/backoffice')
}

export const authApi = {
  google: (code) => api.post('/auth/google', { code }),
  microsoft: (code) => api.post('/auth/microsoft', { code })
}
