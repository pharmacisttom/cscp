<script setup>
import { ref, onMounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { 
  LayoutDashboard, 
  Store, 
  Settings, 
  LogOut,
  Building2,
  Users,
  Calendar,
  Database,
  X,
  FileClock,
  MessageSquare,
  ShieldAlert,
  ClipboardList
} from 'lucide-vue-next'
import { useAuthStore } from '../stores/auth'
import { storeToRefs } from 'pinia'
import { supabase } from '../lib/supabase'
import changelogData from '../changelog.json'

const router = useRouter()
const route = useRoute()
const authStore = useAuthStore()
const { isAdmin, profile, user } = storeToRefs(authStore)

const businessTypes = ref([])

const fetchBusinessTypes = async () => {
  try {
    const { data, error } = await supabase.from('business_types').select('*').order('type_name')
    if (error) throw error
    businessTypes.value = data
  } catch (e) {
    console.error('Error fetching business types:', e)
  }
}

const navigation = [
  { name: 'แดชบอร์ด', href: '/dashboard', icon: LayoutDashboard },
  { name: 'รายชื่อสถานประกอบการ', href: '/businesses', icon: Store },
  { name: 'ปฏิทินออกตรวจ', href: '/calendar', icon: Calendar },
  { name: 'ผลการออกตรวจทั้งหมด', href: '/inspection-dashboard', icon: ClipboardList },
  { name: 'พนักงานเจ้าหน้าที่', href: '/officers', icon: Users },
  { name: 'เรื่องร้องเรียน', href: '/complaints', icon: MessageSquare },
  { name: 'ตรวจสอบความปลอดภัย (Audit)', href: '/audit-logs', icon: ShieldAlert, adminOnly: true },
  { name: 'ตั้งค่าระบบ', href: '/settings', icon: Settings },
]

const isActive = (path) => {
  if (path === '/dashboard' && route.path.startsWith('/dashboard')) return true
  if (path === '/businesses' && route.path.startsWith('/businesses')) return true
  if (path === '/calendar' && route.path.startsWith('/calendar')) return true
  if (path === '/officers' && route.path.startsWith('/officers')) return true
  if (path === '/complaints' && route.path.startsWith('/complaints')) return true
  if (path === '/settings' && route.path.startsWith('/settings')) return true
  return false
}

const handleLogout = async () => {
  await authStore.signOut()
  router.push('/login')
}

// === System Status & Versioning ===
const showChangelog = ref(false)
const dbStatus = ref('checking')
const changelog = ref(changelogData)
const currentVersion = ref(changelogData.length > 0 ? changelogData[0].version : '0.0.0')

onMounted(async () => {
  fetchBusinessTypes()
  
  try {
    // Simple health check query
    const { error } = await supabase.from('businesses').select('id').limit(1)
    if (error) throw error
    dbStatus.value = 'online'
  } catch (e) {
    console.error('DB Connection error:', e)
    dbStatus.value = 'offline'
  }
})

</script>

<template>
  <div class="h-screen w-64 flex-shrink-0 bg-primary-900 text-white flex flex-col overflow-y-auto">
    <!-- Header -->
    <div class="p-6 border-b border-primary-800">
      <div class="flex items-center gap-3">
        <Building2 class="w-8 h-8 text-primary-400" />
        <h1 class="text-2xl font-bold tracking-wider">CSCP</h1>
      </div>
      <p class="text-primary-300 text-xs mt-2">ระบบงาน Postmarket Health Customer Product</p>
    </div>
    
    <!-- User Info -->
    <div class="p-4 border-b border-primary-800 bg-primary-800/30">
      <div class="flex items-center gap-3">
        <div class="w-10 h-10 rounded-full bg-primary-700 flex items-center justify-center flex-shrink-0">
          <span class="font-bold text-lg text-primary-100">{{ profile?.email?.charAt(0).toUpperCase() || 'U' }}</span>
        </div>
        <div class="overflow-hidden">
          <p class="text-sm font-medium truncate text-primary-100" :title="profile?.email">
            {{ profile?.email }}
          </p>
          <div class="flex flex-col gap-0.5 mt-1">
            <span class="text-[10px] px-2 py-0.5 rounded-full bg-primary-800 text-primary-300 inline-block w-fit">
              ID: {{ profile?.id?.substring(0, 8) }}...
            </span>
            <span class="text-xs text-primary-400">
              Role: {{ profile?.role }}
            </span>
            <span class="text-xs text-primary-400">
              IsAdmin: {{ isAdmin ? 'Yes' : 'No' }}
            </span>
          </div>
        </div>
      </div>
    </div>

    <!-- Navigation -->
    <nav class="flex-1 py-4 overflow-y-auto">
      <ul class="space-y-1 px-3">
        <li v-for="item in navigation" :key="item.name" v-show="!item.adminOnly || isAdmin">
          <router-link
            :to="item.href"
            :class="[
              isActive(item.href)
                ? 'bg-primary-800 text-white border-l-4 border-primary-400'
                : 'text-primary-200 hover:bg-primary-800/50 hover:text-white border-l-4 border-transparent',
              'group flex items-center px-3 py-2.5 text-sm font-medium rounded-r-lg transition-all duration-200'
            ]"
          >
            <component 
              :is="item.icon" 
              :class="[
                isActive(item.href) ? 'text-primary-400' : 'text-primary-400/70 group-hover:text-primary-400',
                'flex-shrink-0 w-5 h-5 mr-3 transition-colors duration-200'
              ]" 
            />
            {{ item.name }}
          </router-link>
        </li>
      </ul>

      <!-- Statistics Section -->
      <div class="mt-8 px-3" v-if="businessTypes.length > 0">
        <h3 class="px-3 text-xs font-bold text-primary-300 uppercase tracking-wider mb-2 flex items-center">
          📊 สถิติแยกตามประเภท
        </h3>
        <ul class="space-y-1">
          <li v-for="type in businessTypes" :key="type.id">
            <router-link
              :to="`/statistics/${encodeURIComponent(type.type_name)}`"
              :class="[
                route.path === `/statistics/${encodeURIComponent(type.type_name)}`
                  ? 'bg-primary-800 text-white border-l-4 border-indigo-400'
                  : 'text-primary-200 hover:bg-primary-800/50 hover:text-white border-l-4 border-transparent',
                'group flex items-center px-3 py-2 text-sm font-medium rounded-r-lg transition-all duration-200'
              ]"
            >
              <div :class="['w-1.5 h-1.5 rounded-full mr-3 transition-transform', route.path === `/statistics/${encodeURIComponent(type.type_name)}` ? 'bg-indigo-400 scale-125' : 'bg-primary-600 group-hover:bg-indigo-300 group-hover:scale-125']"></div>
              <span class="truncate">{{ type.type_name }}</span>
            </router-link>
          </li>
        </ul>
      </div>
    </nav>

    <!-- System Status & Version -->
    <div 
      @click="showChangelog = true"
      class="px-4 py-3 border-t border-primary-800 bg-primary-950/50 text-xs flex justify-between items-center cursor-pointer hover:bg-primary-800/50 transition-colors group"
      title="คลิกเพื่อดูประวัติการอัปเดต"
    >
      <div class="flex items-center space-x-2">
        <div class="relative flex h-2.5 w-2.5">
          <span v-if="dbStatus === 'online'" class="animate-ping absolute inline-flex h-full w-full rounded-full bg-green-400 opacity-75"></span>
          <span :class="['relative inline-flex rounded-full h-2.5 w-2.5', dbStatus === 'online' ? 'bg-green-500' : dbStatus === 'offline' ? 'bg-red-500' : 'bg-yellow-500']"></span>
        </div>
        <span class="text-primary-200 font-medium group-hover:text-white transition-colors">
          {{ dbStatus === 'online' ? 'DB Connected' : dbStatus === 'offline' ? 'DB Offline' : 'Checking...' }}
        </span>
      </div>
      <div class="flex items-center text-primary-400 font-mono group-hover:text-primary-200 transition-colors">
        <FileClock class="w-3 h-3 mr-1" />
        v.{{ currentVersion }}
      </div>
    </div>

    <!-- Logout -->
    <div class="p-4 border-t border-primary-800">
      <button 
        @click="handleLogout"
        class="flex items-center w-full px-3 py-2 text-sm font-medium text-red-300 rounded-lg hover:bg-red-900/30 hover:text-red-200 transition-colors duration-200"
      >
        <LogOut class="w-5 h-5 mr-3" />
        ออกจากระบบ
      </button>
    </div>
  </div>

  <!-- Changelog Modal (Teleported to body to escape fixed sidebar clipping) -->
  <Teleport to="body">
    <div v-if="showChangelog" class="fixed inset-0 bg-slate-900/60 backdrop-blur-sm z-[100] flex items-center justify-center p-4">
      <div class="bg-white rounded-2xl shadow-2xl max-w-2xl w-full overflow-hidden animate-fadeIn flex flex-col max-h-[85vh]">
        <!-- Header -->
        <div class="p-5 border-b border-slate-100 flex justify-between items-center bg-slate-50">
          <div>
            <h3 class="text-xl font-extrabold text-slate-900 flex items-center">
              <FileClock class="w-6 h-6 mr-2 text-primary-600" /> System Changelog
            </h3>
            <p class="text-sm text-slate-500 mt-1">ประวัติการอัปเดตและพัฒนาแอปพลิเคชัน</p>
          </div>
          <button @click="showChangelog = false" class="text-slate-400 hover:text-slate-600 bg-slate-200 hover:bg-slate-300 rounded-full p-1.5 transition-colors">
            <X class="w-5 h-5" />
          </button>
        </div>
        
        <!-- Content -->
        <div class="p-6 overflow-y-auto flex-1 bg-white">
          <div class="relative border-l-2 border-slate-200 ml-3 space-y-8">
            
            <div v-for="(log, idx) in changelog" :key="log.version" class="relative pl-6">
              <!-- Timeline dot -->
              <div :class="['absolute -left-[9px] top-1 h-4 w-4 rounded-full border-2 border-white shadow-sm', idx === 0 ? 'bg-primary-500' : 'bg-slate-300']"></div>
              
              <div class="mb-1 flex items-center flex-wrap gap-2">
                <span class="text-lg font-bold text-slate-900">v.{{ log.version }}</span>
                <span v-if="idx === 0" class="px-2 py-0.5 bg-green-100 text-green-700 text-[10px] font-bold rounded-full uppercase tracking-wider">Latest</span>
                <span class="text-sm text-slate-500 ml-auto">{{ log.date }}</span>
              </div>
              
              <ul class="mt-3 space-y-2">
                <li v-for="(change, cIdx) in log.changes" :key="cIdx" class="flex items-start text-sm text-slate-700 bg-slate-50 p-2.5 rounded-lg border border-slate-100">
                  <span class="mr-2 mt-0.5 text-primary-500">•</span>
                  {{ change }}
                </li>
              </ul>
            </div>
            
          </div>
        </div>
      </div>
    </div>
  </Teleport>
</template>

<style scoped>
.animate-fadeIn {
  animation: fadeIn 0.2s ease-out forwards;
}
@keyframes fadeIn {
  from { opacity: 0; transform: translateY(10px); }
  to { opacity: 1; transform: translateY(0); }
}
</style>
