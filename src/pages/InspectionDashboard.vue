<script setup>
import { ref, onMounted, computed, watch } from 'vue'
import { supabase } from '../lib/supabase'
import { ClipboardList, Search, Calendar as CalendarIcon, Store, Filter, CheckCircle2, XCircle, AlertTriangle } from 'lucide-vue-next'
import { useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth'
import { storeToRefs } from 'pinia'

const router = useRouter()
const authStore = useAuthStore()
const { isAdmin, userDistrict } = storeToRefs(authStore)

const inspections = ref([])
const loading = ref(true)

// Filters
const searchQuery = ref('')
const resultFilter = ref('all')
const districtFilter = ref(userDistrict.value || 'all')
const typeFilter = ref('all')

const fetchInspections = async () => {
  loading.value = true
  try {
    let query = supabase
      .from('inspections')
      .select(`
        *,
        businesses!inner (
          business_name,
          business_type,
          district,
          subdistrict,
          license_no
        )
      `)
      .order('inspection_date', { ascending: false })
      .limit(300)

    // District restriction for non-admins
    if (!isAdmin.value && userDistrict.value) {
      query = query.eq('businesses.district', userDistrict.value)
    }

    const { data, error } = await query
    if (error) throw error
    
    inspections.value = data || []
  } catch (error) {
    console.error('Error fetching inspections:', error)
  } finally {
    loading.value = false
  }
}

const filteredInspections = computed(() => {
  let result = inspections.value

  // District filter
  if (districtFilter.value !== 'all') {
    result = result.filter(i => i.businesses.district === districtFilter.value)
  }

  // Type filter
  if (typeFilter.value !== 'all') {
    result = result.filter(i => i.businesses.business_type === typeFilter.value)
  }

  // Result filter
  if (resultFilter.value !== 'all') {
    if (resultFilter.value === 'pass') {
      result = result.filter(i => i.inspection_result === 'ผ่าน')
    } else if (resultFilter.value === 'fail') {
      result = result.filter(i => i.inspection_result === 'ไม่ผ่าน' || i.inspection_result === 'ปรับปรุง')
    }
  }

  // Search query
  if (searchQuery.value) {
    const q = searchQuery.value.toLowerCase()
    result = result.filter(i => 
      (i.businesses.business_name && i.businesses.business_name.toLowerCase().includes(q)) ||
      (i.inspector_name && i.inspector_name.toLowerCase().includes(q)) ||
      (i.businesses.license_no && i.businesses.license_no.toLowerCase().includes(q)) ||
      (i.problem_found && i.problem_found.toLowerCase().includes(q))
    )
  }

  return result
})

// Extract unique districts and types for dropdowns
const availableDistricts = computed(() => {
  if (!isAdmin.value) return [userDistrict.value]
  const districts = new Set(inspections.value.map(i => i.businesses.district).filter(Boolean))
  return Array.from(districts).sort()
})

const availableTypes = computed(() => {
  const types = new Set(inspections.value.map(i => i.businesses.business_type).filter(Boolean))
  return Array.from(types).sort()
})

const formatDate = (dateString) => {
  if (!dateString) return '-'
  return new Date(dateString).toLocaleDateString('th-TH', {
    year: 'numeric', month: 'short', day: 'numeric'
  })
}

const getResultBadge = (result) => {
  if (result === 'ผ่าน') return { class: 'bg-green-100 text-green-800 border-green-200', icon: CheckCircle2 }
  if (result === 'ไม่ผ่าน') return { class: 'bg-red-100 text-red-800 border-red-200', icon: XCircle }
  if (result === 'ปรับปรุง') return { class: 'bg-amber-100 text-amber-800 border-amber-200', icon: AlertTriangle }
  return { class: 'bg-slate-100 text-slate-800 border-slate-200', icon: ClipboardList }
}

const navigateToBusiness = (id) => {
  router.push(`/businesses/${id}`)
}

onMounted(() => {
  fetchInspections()
})
</script>

<template>
  <div class="space-y-6">
    <div class="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
      <div>
        <h1 class="text-2xl font-bold text-slate-900 flex items-center">
          <ClipboardList class="w-6 h-6 mr-2 text-primary-500" />
          ศูนย์รวมประวัติการออกตรวจ
        </h1>
        <p class="text-sm text-slate-500 mt-1">ประวัติและผลการออกตรวจสถานประกอบการทั้งหมด</p>
      </div>
    </div>

    <!-- Filters Section -->
    <div class="card p-4 bg-white border border-slate-200 shadow-sm">
      <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
        <div class="col-span-1 md:col-span-4 lg:col-span-1 relative">
          <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
            <Search class="h-5 w-5 text-slate-400" />
          </div>
          <input 
            v-model="searchQuery" 
            type="text" 
            placeholder="ค้นหาชื่อร้าน, ผู้ตรวจ, ทะเบียน..." 
            class="form-input pl-10 w-full"
          />
        </div>
        
        <div>
          <select v-model="resultFilter" class="form-input w-full">
            <option value="all">ผลการตรวจทั้งหมด</option>
            <option value="pass">ผ่านเกณฑ์</option>
            <option value="fail">ไม่ผ่าน / ต้องปรับปรุง</option>
          </select>
        </div>
        
        <div>
          <select v-model="typeFilter" class="form-input w-full">
            <option value="all">ประเภทกิจการทั้งหมด</option>
            <option v-for="t in availableTypes" :key="t" :value="t">{{ t }}</option>
          </select>
        </div>
        
        <div>
          <select v-model="districtFilter" class="form-input w-full" :disabled="!isAdmin">
            <option value="all" v-if="isAdmin">ทุกอำเภอ</option>
            <option v-for="d in availableDistricts" :key="d" :value="d">{{ d }}</option>
          </select>
        </div>
      </div>
    </div>

    <!-- Inspections Table -->
    <div class="card overflow-hidden">
      <div v-if="loading" class="p-12 text-center">
        <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600 mx-auto"></div>
        <p class="text-slate-500 mt-4">กำลังโหลดข้อมูลการออกตรวจ...</p>
      </div>

      <div v-else-if="filteredInspections.length === 0" class="p-16 text-center">
        <Filter class="w-12 h-12 text-slate-300 mx-auto mb-4" />
        <h3 class="text-lg font-medium text-slate-900">ไม่พบประวัติการออกตรวจ</h3>
        <p class="text-slate-500 mt-1">ไม่มีข้อมูลการออกตรวจที่ตรงกับเงื่อนไขการค้นหาของคุณ</p>
      </div>

      <div v-else class="overflow-x-auto">
        <table class="min-w-full divide-y divide-slate-200">
          <thead class="bg-slate-50">
            <tr>
              <th scope="col" class="px-4 py-3 text-left text-xs font-bold text-slate-500 uppercase tracking-wider">วันที่ตรวจ</th>
              <th scope="col" class="px-4 py-3 text-left text-xs font-bold text-slate-500 uppercase tracking-wider">สถานประกอบการ</th>
              <th scope="col" class="px-4 py-3 text-left text-xs font-bold text-slate-500 uppercase tracking-wider">ผลการตรวจ / ผู้ตรวจ</th>
              <th scope="col" class="px-4 py-3 text-left text-xs font-bold text-slate-500 uppercase tracking-wider">ปัญหาที่พบ (ถ้ามี)</th>
              <th scope="col" class="px-4 py-3 text-center text-xs font-bold text-slate-500 uppercase tracking-wider">จัดการ</th>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-slate-100">
            <tr v-for="i in filteredInspections" :key="i.id" class="hover:bg-slate-50 transition-colors">
              <td class="px-4 py-3 whitespace-nowrap">
                <div class="flex items-center text-sm font-bold text-slate-700">
                  <CalendarIcon class="w-4 h-4 mr-1.5 text-primary-400" />
                  {{ formatDate(i.inspection_date) }}
                </div>
              </td>
              <td class="px-4 py-3">
                <div class="text-sm font-bold text-primary-700 hover:underline cursor-pointer" @click="navigateToBusiness(i.business_id)">
                  {{ i.businesses.business_name }}
                </div>
                <div class="text-xs text-slate-500 flex items-center mt-0.5">
                  <Store class="w-3 h-3 mr-1" />
                  {{ i.businesses.business_type }} • อ.{{ i.businesses.district }}
                </div>
              </td>
              <td class="px-4 py-3 whitespace-nowrap">
                <div class="flex items-center space-x-2">
                  <span v-if="i.inspection_result" :class="[getResultBadge(i.inspection_result).class, 'inline-flex items-center px-2 py-0.5 rounded text-xs font-bold border']">
                    <component :is="getResultBadge(i.inspection_result).icon" class="w-3 h-3 mr-1" />
                    {{ i.inspection_result }}
                  </span>
                  <span v-else class="text-xs text-slate-400 italic">ไม่ได้ระบุผล</span>
                  
                  <span class="text-xs font-medium bg-slate-100 text-slate-600 px-2 py-0.5 rounded border border-slate-200" v-if="i.score">
                    {{ i.score }} คะแนน
                  </span>
                </div>
                <div class="text-xs text-slate-500 mt-1">
                  ผู้ตรวจ: {{ i.inspector_name || '-' }}
                </div>
              </td>
              <td class="px-4 py-3 text-sm text-slate-600">
                <div v-if="i.problem_found" class="max-w-xs truncate text-red-600" :title="i.problem_found">
                  {{ i.problem_found }}
                </div>
                <div v-else class="text-slate-400 text-xs italic">-</div>
              </td>
              <td class="px-4 py-3 whitespace-nowrap text-center">
                <button @click="navigateToBusiness(i.business_id)" class="text-primary-600 hover:text-primary-900 text-sm font-medium bg-primary-50 px-3 py-1.5 rounded hover:bg-primary-100 transition-colors">
                  ดูประวัติร้าน
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>
