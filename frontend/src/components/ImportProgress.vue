<template>
  <div class="import-progress">
    <div class="progress-bar">
      <div class="progress-fill" :style="{ width: percent + '%' }" />
    </div>
    <span class="progress-text">Processing {{ progress.current }} of {{ progress.total }}</span>
  </div>
</template>

<script setup>
import { computed } from 'vue'

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
  background: #2a2a2a;
  border-radius: 2px;
  overflow: hidden;
  margin-bottom: 6px;
}

.progress-fill {
  height: 100%;
  background: #3b82f6;
  transition: width 0.3s ease;
}

.progress-text {
  font-size: 11px;
  color: #555;
}
</style>
