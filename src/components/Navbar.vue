<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import { Menu, UserCircle, Smartphone, Tablet, Monitor } from 'lucide-vue-next'
import { useAuthStore } from '../stores/auth'
import { storeToRefs } from 'pinia'

const showMobileMenu = ref(false)
const authStore = useAuthStore()
const { user, profile } = storeToRefs(authStore)

const emit = defineEmits(['toggle-mobile-menu'])

const deviceType = ref('pc') // 'mobile', 'tablet', 'pc'

const checkDeviceType = () => {
  const width = window.innerWidth
  if (width < 768) {
    deviceType.value = 'mobile'
  } else if (width < 1024) {
    deviceType.value = 'tablet'
  } else {
    deviceType.value = 'pc'
  }
}

onMounted(() => {
  checkDeviceType()
  window.addEventListener('resize', checkDeviceType)
})

onUnmounted(() => {
  window.removeEventListener('resize', checkDeviceType)
})
</script>

<template>
  <header class="bg-white border-b border-slate-200 h-16 flex items-center justify-between px-4 md:px-6 shadow-sm z-10">
    <div class="flex items-center md:hidden">
      <button 
        @click="emit('toggle-mobile-menu')"
        class="text-slate-500 hover:text-slate-700 focus:outline-none focus:ring-2 focus:ring-inset focus:ring-primary-500 rounded-md p-2"
      >
        <Menu class="h-6 w-6" />
      </button>
      <span class="ml-2 text-lg font-bold text-primary-800">CSCP</span>
    </div>
    
    <div class="hidden md:flex flex-1 items-center justify-between">
      <h1 class="text-xl font-semibold text-slate-800 tracking-tight">ระบบงาน Postmarket Health Customer Product</h1>
      
      <div class="flex items-center space-x-6">
        <!-- Device Indicator -->
        <div class="flex items-center text-slate-400 bg-slate-50 px-3 py-1.5 rounded-full border border-slate-100" title="อุปกรณ์ที่กำลังใช้งาน">
          <Smartphone v-if="deviceType === 'mobile'" class="h-4 w-4 text-indigo-500" />
          <Tablet v-else-if="deviceType === 'tablet'" class="h-4 w-4 text-indigo-500" />
          <Monitor v-else class="h-4 w-4 text-indigo-500" />
          <span class="ml-2 text-xs font-bold text-slate-600 uppercase">{{ deviceType }}</span>
        </div>

        <!-- User Profile -->
        <div class="flex items-center space-x-2">
          <div class="text-right">
            <div class="text-sm font-bold text-slate-700">{{ profile?.officers?.full_name || user?.email || 'Guest' }}</div>
            <div class="text-xs text-slate-400">{{ profile?.officers?.full_name ? user?.email : 'เข้าสู่ระบบแล้ว' }}</div>
          </div>
          <button class="text-primary-600 hover:text-primary-800 transition-colors bg-primary-50 p-2 rounded-full">
            <span class="sr-only">Profile</span>
            <UserCircle class="h-6 w-6" />
          </button>
        </div>
      </div>
    </div>

    <!-- Mobile view header items -->
    <div class="md:hidden flex items-center space-x-3">
      <!-- Device Indicator (Mobile minimal) -->
      <div class="text-slate-400 bg-slate-50 p-1.5 rounded-full border border-slate-100">
        <Smartphone v-if="deviceType === 'mobile'" class="h-4 w-4 text-indigo-500" />
        <Tablet v-else-if="deviceType === 'tablet'" class="h-4 w-4 text-indigo-500" />
        <Monitor v-else class="h-4 w-4 text-indigo-500" />
      </div>
      <UserCircle class="h-7 w-7 text-primary-600" />
    </div>
  </header>
</template>
