<script setup>
import { computed } from 'vue'

const props = defineProps({
  status: {
    type: String,
    default: 'active' // active, expired, revoked
  }
})

const badgeConfig = computed(() => {
  const configs = {
    'active': { color: 'bg-green-100 text-green-800', label: 'ปกติ' },
    'expired': { color: 'bg-red-100 text-red-800', label: 'หมดอายุ' },
    'revoked': { color: 'bg-gray-100 text-gray-800', label: 'เพิกถอน' }
  }
  return configs[props.status] || { color: 'bg-gray-100 text-gray-800', label: props.status }
})
</script>

<template>
  <span :class="['inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium', badgeConfig.color]">
    {{ badgeConfig.label }}
  </span>
</template>
