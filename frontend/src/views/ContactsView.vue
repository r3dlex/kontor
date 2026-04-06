<template>
  <div class="contacts-view">
    <div class="header">
      <h2>Contacts</h2>
      <div class="view-toggle">
        <button :class="{ active: view === 'list' }" @click="view = 'list'">List</button>
        <button :class="{ active: view === 'graph' }" @click="switchToGraph">Graph</button>
      </div>
    </div>

    <div v-if="view === 'list'" class="contact-list">
      <div
        v-for="contact in contacts"
        :key="contact.id"
        class="contact-card"
        @click="$router.push(`/contacts/${contact.id}`)"
      >
        <div class="contact-avatar">{{ initials(contact) }}</div>
        <div class="contact-info">
          <div class="contact-name">{{ contact.display_name || contact.email_address }}</div>
          <div class="contact-email">{{ contact.email_address }}</div>
          <div class="contact-org" v-if="contact.organization">{{ contact.organization }}</div>
        </div>
        <div class="contact-importance">
          <div class="importance-ring" :style="ringStyle(contact.importance_weight)" />
        </div>
      </div>
    </div>

    <div v-if="view === 'graph'" class="graph-container">
      <div ref="graphEl" class="graph-canvas" />
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, watch } from 'vue'
import { contactsApi } from '@/api'
import { useChatStore } from '@/stores/chat'

const contacts = ref([])
const view = ref('list')
const graphEl = ref(null)
const chat = useChatStore()
let network = null

onMounted(async () => {
  chat.setViewContext({ view: 'contacts', available_actions: ['view_contact', 'refresh_profile'] })
  const { data } = await contactsApi.list()
  contacts.value = data.contacts
})

async function switchToGraph() {
  view.value = 'graph'
  await import('vis-network/styles/vis-network.min.css').catch(() => {})
  const { Network, DataSet } = await import('vis-network')

  const { data } = await contactsApi.graph()

  const nodes = new DataSet(data.nodes.map(n => ({
    id: n.id,
    label: n.label,
    title: n.title,
    value: Math.max((n.value || 0) * 30, 5)
  })))

  const edges = new DataSet(data.edges.map(e => ({
    from: e.from,
    to: e.to,
    value: e.value,
    title: e.title
  })))

  if (graphEl.value) {
    network = new Network(graphEl.value, { nodes, edges }, {
      nodes: {
        shape: 'dot',
        color: { background: '#1a3a5c', border: '#3b82f6', highlight: { background: '#2d5a8c', border: '#60a5fa' } },
        font: { color: '#888', size: 11 }
      },
      edges: {
        color: { color: '#333', highlight: '#555' },
        smooth: { type: 'continuous' }
      },
      physics: {
        stabilization: { iterations: 100 },
        barnesHut: { gravitationalConstant: -3000 }
      },
      interaction: { hover: true }
    })
  }
}

function initials(contact) {
  const name = contact.display_name || contact.email_address
  return name.slice(0, 2).toUpperCase()
}

function ringStyle(weight) {
  const size = 8 + (weight || 0) * 16
  return {
    width: size + 'px',
    height: size + 'px',
    borderRadius: '50%',
    background: `rgba(59, 130, 246, ${0.2 + (weight || 0) * 0.8})`
  }
}
</script>

<style scoped>
.contacts-view { padding: 24px; height: 100%; display: flex; flex-direction: column; }

.header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 20px;
}

h2 { font-size: 20px; font-weight: 600; color: #fff; }

.view-toggle { display: flex; gap: 4px; }

.view-toggle button {
  padding: 6px 14px;
  border-radius: 6px;
  border: 1px solid #333;
  background: transparent;
  color: #666;
  font-size: 13px;
  cursor: pointer;
}

.view-toggle button.active { background: #1f1f1f; color: #fff; border-color: #444; }

.contact-list { display: flex; flex-direction: column; gap: 6px; overflow-y: auto; }

.contact-card {
  display: flex;
  align-items: center;
  gap: 12px;
  background: #141414;
  border: 1px solid #2a2a2a;
  border-radius: 8px;
  padding: 12px 16px;
  cursor: pointer;
  transition: border-color 0.15s;
}

.contact-card:hover { border-color: #3a3a3a; }

.contact-avatar {
  width: 36px;
  height: 36px;
  border-radius: 50%;
  background: #1a3a5c;
  color: #7dd3fc;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 12px;
  font-weight: 600;
  flex-shrink: 0;
}

.contact-info { flex: 1; min-width: 0; }

.contact-name { font-size: 14px; color: #e8e8e8; font-weight: 500; }
.contact-email { font-size: 12px; color: #666; }
.contact-org { font-size: 11px; color: #555; margin-top: 2px; }

.contact-importance { display: flex; align-items: center; justify-content: center; width: 32px; }

.graph-container { flex: 1; }
.graph-canvas { width: 100%; height: 100%; min-height: 500px; }
</style>
