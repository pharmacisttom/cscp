<script setup>
import { ref, onMounted, computed } from 'vue'
import { supabase } from '../lib/supabase'
import { ShieldAlert, Search, Database, Clock, ArrowRight, User } from 'lucide-vue-next'
import { useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth'
import { storeToRefs } from 'pinia'

const router = useRouter()
const authStore = useAuthStore()
const { isAdmin } = storeToRefs(authStore)

const logs = ref([])
const loading = ref(true)
const profilesMap = ref({})
const searchQuery = ref('')
const tableFilter = ref('all')
const actionFilter = ref('all')

const fetchLogs = async () => {
  if (!isAdmin.value) {
    router.push('/dashboard')
    return
  }

  loading.value = true
  try {
    // Fetch logs
    let query = supabase
      .from('audit_logs')
      .select('*')
      .order('changed_at', { ascending: false })
      .limit(200)

    if (tableFilter.value !== 'all') {
      query = query.eq('table_name', tableFilter.value)
    }
    
    if (actionFilter.value !== 'all') {
      query = query.eq('action', actionFilter.value)
    }

    const { data: logData, error: logError } = await query
    if (logError) throw logError

    // Fetch profiles to map emails
    const userIds = [...new Set(logData.filter(log => log.changed_by).map(log => log.changed_by))]
    if (userIds.length > 0) {
      const { data: profileData, error: profileError } = await supabase
        .from('profiles')
        .select('id, email')
        .in('id', userIds)
      
      if (!profileError && profileData) {
        const map = {}
        profileData.forEach(p => {
          map[p.id] = p.email
        })
        profilesMap.value = map
      }
    }

    logs.value = logData || []
  } catch (error) {
    console.error('Error fetching audit logs:', error)
  } finally {
    loading.value = false
  }
}

const filteredLogs = computed(() => {
  if (!searchQuery.value) return logs.value
  const q = searchQuery.value.toLowerCase()
  return logs.value.filter(log => 
    log.table_name.toLowerCase().includes(q) ||
    log.action.toLowerCase().includes(q) ||
    (log.record_id && log.record_id.toLowerCase().includes(q)) ||
    (log.changed_by && profilesMap.value[log.changed_by] && profilesMap.value[log.changed_by].toLowerCase().includes(q))
  )
})

const formatDate = (dateString) => {
  if (!dateString) return '-'
  return new Date(dateString).toLocaleString('th-TH', {
    year: 'numeric', month: 'short', day: 'numeric',
    hour: '2-digit', minute: '2-digit', second: '2-digit'
  })
}

const getActionStyle = (action) => {
  switch (action) {
    case 'INSERT': return 'bg-green-100 text-green-800 border-green-200'
    case 'UPDATE': return 'bg-blue-100 text-blue-800 border-blue-200'
    case 'DELETE': return 'bg-red-100 text-red-800 border-red-200'
    default: return 'bg-slate-100 text-slate-800 border-slate-200'
  }
}

const formatJson = (data) => {
  if (!data) return '-'
  return JSON.stringify(data, null, 2)
}

onMounted(() => {
  fetchLogs()
})
</script>

<template>
  <div class="space-y-6 max-w-7xl mx-auto">
    <div class="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
      <div>
        <h1 class="text-2xl font-bold text-slate-900 flex items-center">
          <ShieldAlert class="w-6 h-6 mr-2 text-rose-500" />
          ระบบตรวจสอบความปลอดภัย (Audit Logs)
        </h1>
        <p class="text-sm text-slate-500 mt-1">กล้องวงจรปิดของระบบ บันทึกทุกการเปลี่ยนแปลงข้อมูล (เฉพาะผู้ดูแลระบบ)</p>
      </div>
      <button @click="fetchLogs" class="btn-primary flex items-center bg-slate-800 hover:bg-slate-900 shadow-md">
        <Database class="w-4 h-4 mr-2" />
        โหลดข้อมูลล่าสุด
      </button>
    </div>

    <!-- Filters -->
    <div class="card p-4 flex flex-col md:flex-row gap-4 bg-slate-50 border border-slate-200">
      <div class="flex-1 relative">
        <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
          <Search class="h-5 w-5 text-slate-400" />
        </div>
        <input 
          v-model="searchQuery" 
          type="text" 
          placeholder="ค้นหาตาราง, รหัสข้อมูล, หรืออีเมลผู้แก้ไข..." 
          class="form-input pl-10 w-full"
        />
      </div>
      <div class="w-full md:w-48">
        <select v-model="tableFilter" @change="fetchLogs" class="form-input w-full">
          <option value="all">ทุกตาราง</option>
          <option value="businesses">businesses (ร้านค้า)</option>
          <option value="inspections">inspections (ออกตรวจ)</option>
          <option value="complaints">complaints (ร้องเรียน)</option>
          <option value="profiles">profiles (ผู้ใช้)</option>
        </select>
      </div>
      <div class="w-full md:w-48">
        <select v-model="actionFilter" @change="fetchLogs" class="form-input w-full">
          <option value="all">ทุกการกระทำ</option>
          <option value="INSERT">เพิ่ม (INSERT)</option>
          <option value="UPDATE">แก้ไข (UPDATE)</option>
          <option value="DELETE">ลบ (DELETE)</option>
        </select>
      </div>
    </div>

    <!-- Logs Table -->
    <div class="card overflow-hidden border-rose-100 shadow-sm">
      <div v-if="loading" class="p-12 text-center">
        <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-rose-600 mx-auto"></div>
        <p class="text-slate-500 mt-4">กำลังดึงข้อมูลวงจรปิด...</p>
      </div>

      <div v-else-if="filteredLogs.length === 0" class="p-16 text-center">
        <ShieldAlert class="w-12 h-12 text-slate-300 mx-auto mb-4" />
        <h3 class="text-lg font-medium text-slate-900">ไม่พบประวัติการแก้ไข</h3>
        <p class="text-slate-500 mt-1">ไม่มีข้อมูลการเปลี่ยนแปลงระบบที่ตรงกับเงื่อนไข</p>
      </div>

      <div v-else class="overflow-x-auto">
        <table class="min-w-full divide-y divide-slate-200">
          <thead class="bg-slate-800 text-white">
            <tr>
              <th scope="col" class="px-4 py-3 text-left text-xs font-bold uppercase tracking-wider">วัน-เวลา</th>
              <th scope="col" class="px-4 py-3 text-left text-xs font-bold uppercase tracking-wider">ผู้กระทำ</th>
              <th scope="col" class="px-4 py-3 text-left text-xs font-bold uppercase tracking-wider">การกระทำ</th>
              <th scope="col" class="px-4 py-3 text-left text-xs font-bold uppercase tracking-wider">ตาราง / รหัสข้อมูล</th>
              <th scope="col" class="px-4 py-3 text-left text-xs font-bold uppercase tracking-wider">รายละเอียดการเปลี่ยนแปลง</th>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-slate-100">
            <tr v-for="log in filteredLogs" :key="log.id" class="hover:bg-slate-50 transition-colors">
              <td class="px-4 py-3 whitespace-nowrap text-sm text-slate-500">
                <div class="flex items-center">
                  <Clock class="w-3 h-3 mr-1 text-slate-400" />
                  {{ formatDate(log.changed_at) }}
                </div>
              </td>
              <td class="px-4 py-3 whitespace-nowrap">
                <div class="flex items-center text-sm font-medium text-slate-900" v-if="log.changed_by">
                  <User class="w-4 h-4 mr-1 text-primary-500" />
                  {{ profilesMap[log.changed_by] || log.changed_by.substring(0,8) + '...' }}
                </div>
                <div v-else class="text-sm text-slate-400 italic">ระบบ (System)</div>
              </td>
              <td class="px-4 py-3 whitespace-nowrap">
                <span :class="[getActionStyle(log.action), 'inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-bold border']">
                  {{ log.action }}
                </span>
              </td>
              <td class="px-4 py-3 text-sm">
                <div class="font-bold text-slate-700">{{ log.table_name }}</div>
                <div class="text-xs text-slate-400 font-mono mt-0.5 truncate max-w-[150px]" :title="log.record_id">
                  {{ log.record_id }}
                </div>
              </td>
              <td class="px-4 py-3 text-sm">
                <div class="max-w-md">
                  <!-- DELETE Action -->
                  <div v-if="log.action === 'DELETE'" class="text-red-600 bg-red-50 p-2 rounded text-xs overflow-x-auto">
                    <strong>ลบข้อมูล:</strong>
                    <pre class="mt-1 font-mono text-[10px]">{{ formatJson(log.old_data) }}</pre>
                  </div>
                  
                  <!-- INSERT Action -->
                  <div v-else-if="log.action === 'INSERT'" class="text-green-600 bg-green-50 p-2 rounded text-xs overflow-x-auto">
                    <strong>เพิ่มข้อมูลใหม่:</strong>
                    <pre class="mt-1 font-mono text-[10px]">{{ formatJson(log.new_data) }}</pre>
                  </div>
                  
                  <!-- UPDATE Action -->
                  <div v-else-if="log.action === 'UPDATE'" class="flex flex-col gap-2">
                    <div class="text-slate-500 bg-slate-50 p-2 rounded text-xs overflow-x-auto border border-slate-100">
                      <strong>ข้อมูลเดิม:</strong>
                      <pre class="mt-1 font-mono text-[10px] opacity-75">{{ formatJson(log.old_data) }}</pre>
                    </div>
                    <div class="flex justify-center text-slate-300">
                      <ArrowRight class="w-4 h-4" />
                    </div>
                    <div class="text-blue-700 bg-blue-50 p-2 rounded text-xs overflow-x-auto border border-blue-100">
                      <strong>ข้อมูลใหม่:</strong>
                      <pre class="mt-1 font-mono text-[10px]">{{ formatJson(log.new_data) }}</pre>
                    </div>
                  </div>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>
