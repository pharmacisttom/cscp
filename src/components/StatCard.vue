<script setup>
defineProps({
  title: {
    type: String,
    required: true
  },
  value: {
    type: [String, Number],
    required: true
  },
  icon: {
    type: Object,
    required: false
  },
  trend: {
    type: String,
    default: ''
  },
  colorClass: {
    type: String,
    default: 'text-primary-600 bg-primary-100'
  }
})
</script>

<template>
  <div class="bg-white overflow-hidden shadow rounded-lg border border-slate-100 hover:shadow-md transition-shadow duration-200">
    <div class="p-5">
      <div class="flex items-center">
        <div class="flex-shrink-0">
          <div :class="['rounded-md p-3', colorClass]">
            <component :is="icon" v-if="icon" class="h-6 w-6" aria-hidden="true" />
          </div>
        </div>
        <div class="ml-5 w-0 flex-1">
          <dl>
            <dt class="text-sm font-medium text-slate-500 truncate">{{ title }}</dt>
            <dd>
              <div class="text-2xl font-semibold text-slate-900">{{ value }}</div>
            </dd>
          </dl>
        </div>
      </div>
    </div>
    <div v-if="trend" class="bg-slate-50 px-5 py-3">
      <div class="text-sm text-slate-500">
        {{ trend }}
      </div>
    </div>
  </div>
</template>
