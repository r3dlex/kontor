import { defineStore } from 'pinia'
import { ref } from 'vue'
import api from '@/api'

export const useSearchStore = defineStore('search', () => {
  const results = ref([])
  const loading = ref(false)
  const query = ref('')

  async function search(queryText) {
    query.value = queryText
    loading.value = true
    try {
      const { data } = await api.get('/search', { params: { q: queryText } })
      results.value = data.results
    } finally {
      loading.value = false
    }
  }

  return { results, loading, query, search }
})
