<script setup>
import { ref, onMounted, computed, watch } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../lib/supabase'
import { Store, Activity, AlertTriangle, Clock, ArrowRight, XCircle } from 'lucide-vue-next'
import { Chart as ChartJS, ArcElement, Tooltip, Legend, CategoryScale, LinearScale, BarElement } from 'chart.js'
import { Pie } from 'vue-chartjs'

ChartJS.register(ArcElement, Tooltip, Legend, CategoryScale, LinearScale, BarElement)

const router = useRouter()
const isLoading = ref(true)

const activeFilter = ref('ทั้งหมด')

const rawCounts = ref({
  total: 0,
  clinic: 0,
  pharmacy: 0,
  foodWater: 0,
  grocery: 0
})

const stats = computed(() => [
  { id: 'ทั้งหมด', title: 'ทั้งหมด', value: rawCounts.value.total, icon: Store, colorClass: 'text-blue-600 bg-blue-100' },
  { id: 'คลินิก', title: 'คลินิก / พยาบาล', value: rawCounts.value.clinic, icon: Activity, colorClass: 'text-teal-600 bg-teal-100' },
  { id: 'ร้านขายยา', title: 'ร้านขายยา', value: rawCounts.value.pharmacy, icon: Store, colorClass: 'text-green-600 bg-green-100' },
  { id: 'อาหารและน้ำ', title: 'ผลิตอาหาร/น้ำ', value: rawCounts.value.foodWater, icon: Activity, colorClass: 'text-orange-600 bg-orange-100' },
  { id: 'ร้านชำ', title: 'ร้านชำ / ชุมชน', value: rawCounts.value.grocery, icon: Store, colorClass: 'text-purple-600 bg-purple-100' }
])

const recentBusinesses = ref([])
const alerts = ref([])

// Chart Data
const chartData = computed(() => ({
  labels: ['คลินิก/พยาบาล', 'ร้านขายยา', 'ผลิตอาหาร/น้ำ', 'ร้านชำ/ชุมชน', 'อื่นๆ'],
  datasets: [
    {
      backgroundColor: ['#0d9488', '#16a34a', '#ea580c', '#9333ea', '#64748b'],
      data: [
        rawCounts.value.clinic,
        rawCounts.value.pharmacy,
        rawCounts.value.foodWater,
        rawCounts.value.grocery,
        rawCounts.value.total - (rawCounts.value.clinic + rawCounts.value.pharmacy + rawCounts.value.foodWater + rawCounts.value.grocery)
      ]
    }
  ]
}))

const chartOptions = {
  responsive: true,
  maintainAspectRatio: false,
  plugins: {
    legend: { position: 'bottom' }
  }
}

const fetchCounts = async () => {
  // Total
  let { count: t } = await supabase.from('businesses').select('*', { count: 'exact', head: true })
  rawCounts.value.total = t || 0

  // Clinics
  let { count: c } = await supabase.from('businesses').select('*', { count: 'exact', head: true }).eq('business_type', 'คลินิก / สถานพยาบาล')
  rawCounts.value.clinic = c || 0

  // Pharmacy
  let { count: p } = await supabase.from('businesses').select('*', { count: 'exact', head: true }).eq('business_type', 'ร้านขายยา')
  rawCounts.value.pharmacy = p || 0

  // Food/Water
  let { count: f } = await supabase.from('businesses').select('*', { count: 'exact', head: true }).in('business_type', ['สถานที่ผลิตอาหาร', 'สถานที่ผลิตน้ำดื่ม'])
  rawCounts.value.foodWater = f || 0

  // Grocery
  let { count: g } = await supabase.from('businesses').select('*', { count: 'exact', head: true }).eq('business_type', 'ร้านชำ / ร้านค้าชุมชน')
  rawCounts.value.grocery = g || 0
}

const fetchRecent = async () => {
  let query = supabase.from('businesses')
    .select('id, business_name, business_type, created_at')
    .order('created_at', { ascending: false })
    .limit(5)

  if (activeFilter.value === 'คลินิก') {
    query = query.eq('business_type', 'คลินิก / สถานพยาบาล')
  } else if (activeFilter.value === 'ร้านขายยา') {
    query = query.eq('business_type', 'ร้านขายยา')
  } else if (activeFilter.value === 'อาหารและน้ำ') {
    query = query.in('business_type', ['สถานที่ผลิตอาหาร', 'สถานที่ผลิตน้ำดื่ม'])
  } else if (activeFilter.value === 'ร้านชำ') {
    query = query.eq('business_type', 'ร้านชำ / ร้านค้าชุมชน')
  }

  const { data } = await query
  recentBusinesses.value = data || []
}

const fetchAlerts = async () => {
  // Try to find expiring businesses (e.g., year <= 2568)
  const { data } = await supabase.from('businesses')
    .select('id, business_name, expire_year, current_expire_year')
  
  let newAlerts = []
  if(data) {
    data.forEach(biz => {
      const year = parseInt(biz.current_expire_year || biz.expire_year)
      if (year && year <= 2567) {
        newAlerts.push({ type: 'expired', title: 'หมดอายุแล้ว', name: biz.business_name, id: biz.id, icon: XCircle, color: 'text-red-500', bg: 'bg-red-50' })
      } else if (year === 2568) {
        newAlerts.push({ type: 'expiring', title: 'ใกล้หมดอายุ (2568)', name: biz.business_name, id: biz.id, icon: Clock, color: 'text-yellow-600', bg: 'bg-yellow-50' })
      }
    })
  }
  // limit to top 5 alerts for dashboard
  alerts.value = newAlerts.slice(0, 5)
}

watch(activeFilter, () => {
  fetchRecent()
})

onMounted(async () => {
  isLoading.value = true
  await Promise.all([
    fetchCounts(),
    fetchRecent(),
    fetchAlerts()
  ])
  isLoading.value = false
})
</script>

<template>
  <div class="space-y-6">
    <div class="flex justify-between items-end">
      <div>
        <h1 class="text-2xl font-bold text-slate-900">Smart Dashboard</h1>
        <p class="text-sm text-slate-500 mt-1">ภาพรวมและวิเคราะห์ข้อมูลสถานประกอบการในพื้นที่</p>
      </div>
    </div>
    
    <!-- Categorized Interactive Cards -->
    <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-5">
      <div 
        v-for="stat in stats" 
        :key="stat.id"
        @click="activeFilter = stat.id"
        :class="[
          'bg-white overflow-hidden rounded-xl border p-5 cursor-pointer transition-all duration-200 transform hover:-translate-y-1 hover:shadow-md',
          activeFilter === stat.id ? 'border-primary-500 ring-2 ring-primary-500 shadow-md' : 'border-slate-200 shadow-sm'
        ]"
      >
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <div :class="[stat.colorClass, 'rounded-md p-3']">
              <component :is="stat.icon" class="h-6 w-6" aria-hidden="true" />
            </div>
          </div>
          <div class="ml-4 w-0 flex-1">
            <dl>
              <dt class="text-sm font-medium text-slate-500 truncate">{{ stat.title }}</dt>
              <dd class="flex items-baseline">
                <div class="text-2xl font-bold text-slate-900">{{ stat.value }}</div>
              </dd>
            </dl>
          </div>
        </div>
      </div>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
      
      <!-- Recent Data List (Filtered by Card) -->
      <div class="card lg:col-span-2 overflow-hidden flex flex-col">
        <div class="p-5 border-b border-slate-200 flex justify-between items-center bg-slate-50/50">
          <h3 class="text-lg leading-6 font-bold text-slate-900 flex items-center">
            รายการอัปเดตล่าสุด
            <span class="ml-2 px-2.5 py-0.5 rounded-full text-xs font-medium bg-primary-100 text-primary-800">
              ตัวกรอง: {{ activeFilter }}
            </span>
          </h3>
          <button @click="router.push('/businesses')" class="text-sm text-primary-600 hover:text-primary-700 font-medium flex items-center">ดูทั้งหมด <ArrowRight class="w-4 h-4 ml-1" /></button>
        </div>
        
        <div v-if="isLoading" class="p-10 text-center text-slate-400 flex-1 flex items-center justify-center">
          กำลังโหลดข้อมูล...
        </div>
        
        <div v-else-if="recentBusinesses.length === 0" class="p-10 text-center text-slate-500 flex-1 flex flex-col items-center justify-center">
          <Store class="w-10 h-10 text-slate-300 mb-3" />
          <p>ไม่มีข้อมูลกิจการในหมวดหมู่นี้</p>
        </div>
        
        <ul v-else class="divide-y divide-slate-100 flex-1">
          <li v-for="biz in recentBusinesses" :key="biz.id" class="p-4 hover:bg-slate-50 transition-colors cursor-pointer group" @click="router.push(`/businesses/${biz.id}`)">
            <div class="flex items-center space-x-4">
              <div class="flex-shrink-0">
                <div class="h-10 w-10 rounded-full bg-slate-100 flex items-center justify-center text-slate-500 group-hover:bg-primary-100 group-hover:text-primary-600 transition-colors">
                  <Store class="w-5 h-5" />
                </div>
              </div>
              <div class="flex-1 min-w-0">
                <p class="text-sm font-bold text-slate-900 truncate group-hover:text-primary-700">{{ biz.business_name }}</p>
                <p class="text-sm text-slate-500 truncate">{{ biz.business_type }}</p>
              </div>
            </div>
          </li>
        </ul>
      </div>

      <!-- Right Column: Charts & Alerts -->
      <div class="space-y-6 flex flex-col">
        
        <!-- Smart Alerts -->
        <div class="card overflow-hidden">
          <div class="p-4 border-b border-slate-200 bg-red-50/50">
            <h3 class="text-md font-bold text-slate-900 flex items-center">
              <AlertTriangle class="w-5 h-5 text-red-500 mr-2" />
              Smart Alerts
            </h3>
          </div>
          <div class="p-4">
            <div v-if="alerts.length === 0" class="text-sm text-slate-500 text-center py-4">ไม่มีรายการแจ้งเตือน</div>
            <ul v-else class="space-y-3">
              <li v-for="alert in alerts" :key="alert.id" @click="router.push(`/businesses/${alert.id}`)" class="cursor-pointer group">
                <div :class="['p-3 rounded-lg border flex items-start space-x-3 transition-colors', alert.bg, alert.type === 'expired' ? 'border-red-100 hover:border-red-300' : 'border-yellow-100 hover:border-yellow-300']">
                  <component :is="alert.icon" :class="['w-5 h-5 mt-0.5', alert.color]" />
                  <div>
                    <p :class="['text-sm font-bold', alert.color]">{{ alert.title }}</p>
                    <p class="text-xs text-slate-700 mt-0.5 line-clamp-1 group-hover:underline">{{ alert.name }}</p>
                  </div>
                </div>
              </li>
            </ul>
            <div v-if="alerts.length > 0" class="mt-3 text-center">
              <span class="text-xs text-slate-400">แสดงผล 5 รายการล่าสุด</span>
            </div>
          </div>
        </div>

        <!-- Analytics Chart -->
        <div class="card p-5 flex-1 flex flex-col">
          <h3 class="text-md font-bold text-slate-900 mb-4">สัดส่วนประเภทกิจการ</h3>
          <div class="flex-1 min-h-[200px] relative">
            <Pie :data="chartData" :options="chartOptions" />
          </div>
        </div>

      </div>

    </div>
  </div>
</template>
