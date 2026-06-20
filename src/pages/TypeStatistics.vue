<script setup>
import { ref, watch, onMounted, computed } from 'vue'
import { useRoute } from 'vue-router'
import { supabase } from '../lib/supabase'
import { useAuthStore } from '../stores/auth'
import { storeToRefs } from 'pinia'
import { Building2, CheckCircle, Clock, AlertTriangle, MapPin, CalendarDays, Store } from 'lucide-vue-next'
import dayjs from 'dayjs'
import 'dayjs/locale/th'
import buddhistEra from 'dayjs/plugin/buddhistEra'

dayjs.extend(buddhistEra)
dayjs.locale('th')

const route = useRoute()
const authStore = useAuthStore()
const { isAdmin, userDistrict } = storeToRefs(authStore)

const businessType = ref('')
const loading = ref(true)

// Data
const businesses = ref([])
const inspections = ref([])
const searchQuery = ref('')

// Fiscal Year Calculation
const getFiscalYear = () => {
  const now = dayjs()
  let year = now.year()
  if (now.month() >= 9) { // October (9) or later is new fiscal year
    year += 1
  }
  return year
}

const currentFiscalYear = ref(getFiscalYear())
const fyStart = dayjs(`${currentFiscalYear.value - 1}-10-01`).format('YYYY-MM-DD')
const fyEnd = dayjs(`${currentFiscalYear.value}-09-30`).format('YYYY-MM-DD')

const loadData = async () => {
  loading.value = true
  businessType.value = route.params.type || ''
  searchQuery.value = ''
  
  try {
    // 1. Fetch businesses
    let bQuery = supabase.from('businesses').select('id, business_name, district, license_no').eq('business_type', businessType.value)
    if (!isAdmin.value && userDistrict.value) {
      bQuery = bQuery.eq('district', userDistrict.value)
    }
    const { data: bData, error: bError } = await bQuery
    if (bError) throw bError
    businesses.value = bData || []

    const businessIds = businesses.value.map(b => b.id)

    // 2. Fetch inspections for these businesses in the fiscal year
    if (businessIds.length > 0) {
      const { data: iData, error: iError } = await supabase
        .from('inspection_plans')
        .select('*')
        .in('business_id', businessIds)
        .gte('planned_date', fyStart)
        .lte('planned_date', fyEnd)
      
      if (iError) throw iError
      inspections.value = iData || []
    } else {
      inspections.value = []
    }
  } catch (err) {
    console.error(err)
  } finally {
    loading.value = false
  }
}

watch(() => route.params.type, () => {
  if (route.name === 'TypeStatistics') {
    loadData()
  }
})

onMounted(() => {
  if (route.name === 'TypeStatistics') {
    loadData()
  }
})

// Computeds
const totalCount = computed(() => businesses.value.length)

// Determine if a business has a completed inspection in this FY
const getBusinessStatus = (businessId) => {
  const plans = inspections.value.filter(i => i.business_id === businessId)
  if (plans.some(i => i.status === 'completed')) return 'completed'
  if (plans.length > 0) return 'planned'
  return 'none'
}

const completedCount = computed(() => businesses.value.filter(b => getBusinessStatus(b.id) === 'completed').length)
const pendingCount = computed(() => businesses.value.filter(b => getBusinessStatus(b.id) !== 'completed').length)

// District Breakdown
const districtsBreakdown = computed(() => {
  const districtsMap = {}
  
  businesses.value.forEach(b => {
    const d = b.district || 'ไม่ระบุอำเภอ'
    if (!districtsMap[d]) {
      districtsMap[d] = { name: d, total: 0, completed: 0 }
    }
    districtsMap[d].total += 1
    if (getBusinessStatus(b.id) === 'completed') {
      districtsMap[d].completed += 1
    }
  })

  return Object.values(districtsMap).map(d => ({
    ...d,
    percent: d.total > 0 ? Math.round((d.completed / d.total) * 100) : 0
  })).sort((a, b) => b.total - a.total)
})

// Filtered pending businesses for the table
const filteredPendingBusinesses = computed(() => {
  const pending = businesses.value.filter(b => getBusinessStatus(b.id) !== 'completed')
  if (!searchQuery.value) return pending
  const q = searchQuery.value.toLowerCase()
  return pending.filter(b => 
    (b.business_name && b.business_name.toLowerCase().includes(q)) ||
    (b.district && b.district.toLowerCase().includes(q))
  )
})
</script>

<template>
  <div class="max-w-7xl mx-auto space-y-6 pb-12">
    <!-- Header -->
    <div class="bg-gradient-to-r from-indigo-900 to-indigo-700 rounded-2xl p-6 sm:p-10 shadow-xl text-white relative overflow-hidden">
      <!-- Decorative background -->
      <div class="absolute right-0 top-0 -mt-10 -mr-10 opacity-10 pointer-events-none">
        <Store class="w-64 h-64" />
      </div>
      
      <div class="relative z-10 flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <div class="inline-flex items-center px-3 py-1 rounded-full bg-white/20 text-white text-xs font-bold uppercase tracking-wider mb-3 backdrop-blur-sm">
            ปีงบประมาณ {{ currentFiscalYear + 543 }}
          </div>
          <h1 class="text-3xl font-extrabold tracking-tight flex items-center">
            สถิติ: {{ businessType }}
          </h1>
          <p class="text-indigo-200 mt-2 text-sm max-w-xl">
            ข้อมูลจำนวนสถานประกอบการและผลการออกตรวจในรอบปีงบประมาณ ตั้งแต่ 1 ต.ค. {{ currentFiscalYear + 543 - 1 }} ถึง 30 ก.ย. {{ currentFiscalYear + 543 }}
          </p>
        </div>
      </div>
    </div>

    <div v-if="loading" class="text-center py-20">
      <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-indigo-600 mx-auto"></div>
      <p class="mt-4 text-slate-500 font-medium">กำลังคำนวณสถิติ...</p>
    </div>

    <div v-else class="space-y-6">
      <!-- Stats Cards -->
      <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
        <!-- Total -->
        <div class="bg-white rounded-2xl p-6 shadow-sm border border-slate-200 flex items-center relative overflow-hidden">
          <div class="absolute right-0 top-0 mt-4 mr-4 bg-blue-50 text-blue-500 p-3 rounded-2xl">
            <Building2 class="w-8 h-8" />
          </div>
          <div>
            <p class="text-sm font-semibold text-slate-500 mb-1">เป้าหมายทั้งหมด</p>
            <h3 class="text-4xl font-extrabold text-slate-900">{{ totalCount }} <span class="text-lg font-medium text-slate-500 ml-1">แห่ง</span></h3>
          </div>
        </div>

        <!-- Completed -->
        <div class="bg-white rounded-2xl p-6 shadow-sm border border-slate-200 flex items-center relative overflow-hidden">
          <div class="absolute right-0 top-0 mt-4 mr-4 bg-green-50 text-green-500 p-3 rounded-2xl">
            <CheckCircle class="w-8 h-8" />
          </div>
          <div>
            <p class="text-sm font-semibold text-slate-500 mb-1">ออกตรวจแล้ว</p>
            <h3 class="text-4xl font-extrabold text-green-600">{{ completedCount }} <span class="text-lg font-medium text-slate-500 ml-1">แห่ง</span></h3>
            <div class="mt-2 w-full bg-slate-100 rounded-full h-1.5 max-w-[150px]">
              <div class="bg-green-500 h-1.5 rounded-full" :style="{ width: totalCount > 0 ? (completedCount/totalCount)*100 + '%' : '0%' }"></div>
            </div>
          </div>
        </div>

        <!-- Pending -->
        <div class="bg-white rounded-2xl p-6 shadow-sm border border-slate-200 flex items-center relative overflow-hidden">
          <div class="absolute right-0 top-0 mt-4 mr-4 bg-amber-50 text-amber-500 p-3 rounded-2xl">
            <Clock class="w-8 h-8" />
          </div>
          <div>
            <p class="text-sm font-semibold text-slate-500 mb-1">ยังไม่ได้ตรวจ / รอคิว</p>
            <h3 class="text-4xl font-extrabold text-amber-500">{{ pendingCount }} <span class="text-lg font-medium text-slate-500 ml-1">แห่ง</span></h3>
          </div>
        </div>
      </div>

      <!-- Main Content Grid -->
      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        
        <!-- Left: District Breakdown (1/3 width) -->
        <div class="col-span-1 lg:col-span-1">
          <div class="bg-white rounded-2xl shadow-sm border border-slate-200 overflow-hidden h-full flex flex-col">
            <div class="p-5 border-b border-slate-100 bg-slate-50 flex items-center">
              <MapPin class="w-5 h-5 text-indigo-600 mr-2" />
              <h3 class="font-bold text-slate-800">ผลงานแยกตามอำเภอ</h3>
            </div>
            <div class="p-0 overflow-y-auto flex-1">
              <ul class="divide-y divide-slate-100">
                <li v-for="d in districtsBreakdown" :key="d.name" class="p-4 hover:bg-slate-50 transition-colors">
                  <div class="flex justify-between items-center mb-2">
                    <span class="font-bold text-slate-700">{{ d.name }}</span>
                    <span class="text-sm font-semibold text-slate-500">{{ d.completed }} / {{ d.total }}</span>
                  </div>
                  <div class="flex items-center gap-3">
                    <div class="flex-1 bg-slate-100 rounded-full h-2">
                      <div class="bg-indigo-500 h-2 rounded-full" :style="{ width: d.percent + '%' }"></div>
                    </div>
                    <span class="text-xs font-bold text-indigo-600 w-8 text-right">{{ d.percent }}%</span>
                  </div>
                </li>
              </ul>
              
              <div v-if="districtsBreakdown.length === 0" class="p-8 text-center text-slate-500">
                ไม่มีข้อมูลอำเภอ
              </div>
            </div>
          </div>
        </div>

        <!-- Right: Pending Planning Table (2/3 width) -->
        <div class="col-span-1 lg:col-span-2">
          <div class="bg-white rounded-2xl shadow-sm border border-slate-200 overflow-hidden flex flex-col h-full">
            <div class="p-5 border-b border-slate-100 bg-slate-50 flex flex-col sm:flex-row justify-between items-start sm:items-center gap-3">
              <div class="flex items-center">
                <CalendarDays class="w-5 h-5 text-amber-500 mr-2" />
                <h3 class="font-bold text-slate-800">รายชื่อที่ต้องวางแผนออกตรวจ</h3>
              </div>
              <div class="relative w-full sm:w-64">
                <Search class="w-4 h-4 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2" />
                <input 
                  type="text" 
                  v-model="searchQuery" 
                  placeholder="ค้นหาชื่อร้าน..." 
                  class="form-input pl-9 text-sm w-full py-1.5 bg-white border-slate-200"
                />
              </div>
            </div>
            
            <div class="overflow-x-auto">
              <table class="w-full text-left text-sm text-slate-600">
                <thead class="bg-white text-slate-500 text-xs uppercase tracking-wider border-b border-slate-200">
                  <tr>
                    <th class="px-6 py-4 font-bold">ชื่อสถานประกอบการ</th>
                    <th class="px-6 py-4 font-bold">เลขที่ใบอนุญาต</th>
                    <th class="px-6 py-4 font-bold">อำเภอ</th>
                    <th class="px-6 py-4 font-bold text-center">สถานะปัจจุบัน</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-slate-100">
                  <tr v-for="business in filteredPendingBusinesses" :key="business.id" class="hover:bg-slate-50 transition-colors">
                    <td class="px-6 py-4 font-bold text-slate-800">{{ business.business_name }}</td>
                    <td class="px-6 py-4 text-slate-500">{{ business.license_no || '-' }}</td>
                    <td class="px-6 py-4">
                      <span class="px-2.5 py-1 bg-slate-100 text-slate-700 rounded-lg text-xs font-medium border border-slate-200">
                        {{ business.district || 'ไม่ระบุ' }}
                      </span>
                    </td>
                    <td class="px-6 py-4 text-center">
                      <span v-if="getBusinessStatus(business.id) === 'planned'" class="inline-flex items-center px-2.5 py-1 rounded-full text-xs font-bold bg-blue-50 text-blue-600 border border-blue-100">
                        🗓️ มีแผนแล้ว (รอตรวจ)
                      </span>
                      <span v-else class="inline-flex items-center px-2.5 py-1 rounded-full text-xs font-bold bg-amber-50 text-amber-600 border border-amber-100">
                        ⚠️ ยังไม่มีแผนปีนี้
                      </span>
                    </td>
                  </tr>
                  
                  <tr v-if="filteredPendingBusinesses.length === 0">
                    <td colspan="4" class="px-6 py-12 text-center">
                      <div class="flex flex-col items-center justify-center">
                        <CheckCircle class="w-12 h-12 text-green-300 mb-3" />
                        <p class="text-lg font-bold text-slate-700">ยอดเยี่ยมมาก!</p>
                        <p class="text-slate-500">สถานประกอบการทุกแห่งได้รับการออกตรวจหรือมีแผนรองรับหมดแล้ว</p>
                      </div>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>

      </div>
    </div>
  </div>
</template>
