<script setup>
import { computed } from 'vue'

const props = defineProps({
  level: {
    type: String,
    default: 'low' // low, medium, high
  }
})

const badgeConfig = computed(() => {
  const configs = {
    'low': { color: 'bg-green-100 text-green-800', label: 'ความเสี่ยงต่ำ' },
    'medium': { color: 'bg-yellow-100 text-yellow-800', label: 'ความเสี่ยงปานกลาง' },
    'high': { color: 'bg-red-100 text-red-800', label: 'ความเสี่ยงสูง' }
  }
  return configs[props.level] || configs['low']
})
</script>

<template>
  <span :class="['inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium', badgeConfig.color]">
    {{ badgeConfig.label }}
  </span>
</template>
