<script setup>
import { computed } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { supabase } from '../lib/supabase'
import { 
  LayoutDashboard, 
  Store, 
  Settings, 
  LogOut,
  Building2,
  Users
} from 'lucide-vue-next'
import { useAuthStore } from '../stores/auth'
import { storeToRefs } from 'pinia'

const router = useRouter()
const route = useRoute()
const authStore = useAuthStore()
const { isAdmin } = storeToRefs(authStore)

const navigation = [
  { name: 'แดชบอร์ด', href: '/dashboard', icon: LayoutDashboard },
  { name: 'รายชื่อสถานประกอบการ', href: '/businesses', icon: Store },
  { name: 'ตั้งค่าระบบ', href: '/settings', icon: Settings },
]

const isActive = (path) => {
  if (path === '/dashboard' && route.path.startsWith('/dashboard')) return true
  if (path === '/businesses' && route.path.startsWith('/businesses')) return true
  if (path === '/settings' && route.path.startsWith('/settings')) return true
  return false
}

const handleLogout = async () => {
  await supabase.auth.signOut()
  router.push('/login')
}
</script>

<template>
  <div class="flex flex-col w-64 bg-primary-800 text-white border-r border-primary-700 min-h-screen">
    <div class="flex items-center justify-center h-16 border-b border-primary-700 bg-primary-900 px-4">
      <Building2 class="w-8 h-8 text-primary-300 mr-2" />
      <span class="text-xl font-bold tracking-tight">CSCP</span>
    </div>
    
    <div class="flex-1 overflow-y-auto py-4">
      <nav class="space-y-1 px-2">
        <router-link
          v-for="item in navigation"
          :key="item.name"
          :to="item.href"
          :class="[
            isActive(item.href) ? 'bg-primary-900 text-white' : 'text-primary-100 hover:bg-primary-700 hover:text-white',
            'group flex items-center px-2 py-2 text-sm font-medium rounded-md transition-colors'
          ]"
        >
          <component :is="item.icon" class="mr-3 flex-shrink-0 h-5 w-5" aria-hidden="true" />
          {{ item.name }}
        </router-link>

        <router-link
          v-if="isAdmin"
          to="/users"
          :class="[
            isActive('/users') ? 'bg-primary-900 text-white' : 'text-primary-100 hover:bg-primary-700 hover:text-white',
            'group flex items-center px-2 py-2 text-sm font-medium rounded-md transition-colors'
          ]"
        >
          <Users class="mr-3 flex-shrink-0 h-5 w-5" aria-hidden="true" />
          จัดการผู้ใช้งาน
        </router-link>
      </nav>
    </div>

    <div class="p-4 border-t border-primary-700">
      <button 
        @click="handleLogout"
        class="flex items-center w-full px-2 py-2 text-sm font-medium rounded-md text-primary-100 hover:bg-red-700 hover:text-white transition-colors"
      >
        <LogOut class="mr-3 h-5 w-5" />
        ออกจากระบบ
      </button>
    </div>
  </div>
</template>
