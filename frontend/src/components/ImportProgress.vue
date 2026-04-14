<template>
  <div class="import-progress">
    <ProgressBar :value="percent" :showValue="false" class="progress-bar" />
    <span class="progress-text">Processing {{ progress.current }} of {{ progress.total }}</span>
  </div>
</template>

<script setup>
import { computed } from 'vue'
import ProgressBar from 'primevue/progressbar'

const props = defineProps({
  progress: { type: Object, required: true }
})

const percent = computed(() =>
  props.progress.total > 0
    ? Math.round((props.progress.current / props.progress.total) * 100)
    : 0
)
</script>

<style scoped>
.import-progress {
  margin-top: auto;
  padding: 12px 0;
}

.progress-bar {
  height: 3px;
  border-radius: 2px;
  margin-bottom: 6px;
  background: #2a2a2a;
}

.progress-bar :deep(.p-progressbar-value) {
  background: #3b82f6;
}

.progress-text {
  font-size: 11px;
  color: #555;
}
</style>
