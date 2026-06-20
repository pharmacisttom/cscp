<script setup>
import { computed } from 'vue'

const props = defineProps({
  type: {
    type: String,
    required: true
  }
})

const badgeConfig = computed(() => {
  const configs = {
    'คลินิก / สถานพยาบาล': 'bg-blue-100 text-blue-800',
    'ร้านขายยา': 'bg-emerald-100 text-emerald-800',
    'ร้านนวด / สปา': 'bg-purple-100 text-purple-800',
    'ร้านชำ / ร้านค้าชุมชน': 'bg-amber-100 text-amber-800',
    'สถานที่ผลิตอาหาร': 'bg-orange-100 text-orange-800',
    'สถานที่ผลิตน้ำดื่ม': 'bg-cyan-100 text-cyan-800',
    'สถานประกอบการอื่น ๆ': 'bg-slate-100 text-slate-800'
  }
  return configs[props.type] || 'bg-gray-100 text-gray-800'
})
</script>

<template>
  <span :class="['inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium', badgeConfig]">
    {{ type }}
  </span>
</template>
