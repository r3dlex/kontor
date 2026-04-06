<template>
  <div class="search-view">
    <div class="search-header">
      <h2>Search</h2>
    </div>

    <div class="search-bar">
      <input
        v-model="searchStore.query"
        type="text"
        placeholder="Search threads..."
        class="search-input"
        @keydown.enter="handleSearch"
      />
      <button class="search-btn" @click="handleSearch" :disabled="searchStore.loading">
        {{ searchStore.loading ? 'Searching...' : 'Search' }}
      </button>
    </div>

    <div v-if="searchStore.loading" class="loading">Searching...</div>

    <div v-else-if="searched && searchStore.results.length === 0" class="empty">
      No results found.
    </div>

    <div v-else class="results">
      <div
        v-for="result in searchStore.results"
        :key="result.id"
        class="result-card"
      >
        <div class="result-subject">{{ result.subject || result.id }}</div>
        <div class="result-meta">
          <span class="result-type">{{ result.type }}</span>
          <span class="result-score">{{ Math.round(result.similarity_score * 100) }}% match</span>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { useSearchStore } from '@/stores/search'

const searchStore = useSearchStore()
const searched = ref(false)

async function handleSearch() {
  if (!searchStore.query.trim()) return
  searched.value = true
  await searchStore.search(searchStore.query)
}
</script>

<style scoped>
.search-view { padding: 24px; }

.search-header { margin-bottom: 20px; }

h2 { font-size: 20px; font-weight: 600; color: #fff; }

.search-bar {
  display: flex;
  gap: 8px;
  margin-bottom: 24px;
}

.search-input {
  flex: 1;
  padding: 10px 14px;
  background: #141414;
  border: 1px solid #2a2a2a;
  border-radius: 8px;
  color: #e8e8e8;
  font-size: 14px;
  outline: none;
  transition: border-color 0.15s;
}

.search-input:focus { border-color: #444; }
.search-input::placeholder { color: #555; }

.search-btn {
  padding: 10px 20px;
  background: #1a3a5c;
  color: #7dd3fc;
  border: 1px solid #2d5a8c;
  border-radius: 8px;
  font-size: 14px;
  cursor: pointer;
  transition: opacity 0.15s;
}

.search-btn:disabled { opacity: 0.5; cursor: not-allowed; }
.search-btn:hover:not(:disabled) { opacity: 0.85; }

.results { display: flex; flex-direction: column; gap: 8px; }

.result-card {
  background: #141414;
  border: 1px solid #2a2a2a;
  border-radius: 10px;
  padding: 14px 16px;
  transition: border-color 0.15s;
}

.result-card:hover { border-color: #3a3a3a; }

.result-subject {
  font-size: 14px;
  font-weight: 500;
  color: #e8e8e8;
  margin-bottom: 6px;
}

.result-meta { display: flex; gap: 12px; align-items: center; }

.result-type {
  font-size: 11px;
  color: #666;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

.result-score { font-size: 12px; color: #3b82f6; }

.loading, .empty { color: #555; font-size: 14px; padding: 40px; text-align: center; }
</style>
