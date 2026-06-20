<script setup>
import { ref, onMounted, computed } from 'vue'
import { supabase } from '../lib/supabase'
import BusinessTypeBadge from '../components/BusinessTypeBadge.vue'
import RiskBadge from '../components/RiskBadge.vue'
import LicenseStatusBadge from '../components/LicenseStatusBadge.vue'
import { Plus, Search, Filter, Store, Activity, ChevronRight, ChevronLeft, ChevronRight as ChevronRightIcon, Download, UploadCloud } from 'lucide-vue-next'
import { useRouter } from 'vue-router'
import * as XLSX from 'xlsx'
import Swal from 'sweetalert2'
import { useAuthStore } from '../stores/auth'
import { storeToRefs } from 'pinia'

const router = useRouter()
const authStore = useAuthStore()
const { isAdmin, userDistrict } = storeToRefs(authStore)
const businesses = ref([])
const loading = ref(true)
const searchQuery = ref('')
const activeFilter = ref('ทั้งหมด')

// Pagination
const currentPage = ref(1)
const itemsPerPage = 10

const filterTabs = ref(['ทั้งหมด'])
const fileInput = ref(null)
const isImporting = ref(false)

const triggerFileInput = () => {
  fileInput.value.click()
}

const downloadTemplate = async () => {
  const wb = XLSX.utils.book_new()
  const header = ['ประเภทกิจการ', 'ชื่อสถานประกอบการ', 'เลขใบอนุญาต', 'ชื่อผู้รับอนุญาต', 'ชื่อผู้ดำเนินกิจการ', 'ที่อยู่', 'หมู่', 'ตำบล', 'อำเภอ', 'เบอร์โทรศัพท์', 'สถานะใบอนุญาต (active/expired/revoked)', 'ระดับความเสี่ยง (low/medium/high)']
  const wscols = [
    {wch: 25}, {wch: 30}, {wch: 15}, {wch: 20}, {wch: 20}, {wch: 30}, {wch: 10}, {wch: 15}, {wch: 15}, {wch: 15}, {wch: 25}, {wch: 25}
  ]

  // Get business types from DB or use defaults
  const { data: types } = await supabase.from('business_types').select('type_name')
  const defaultTypes = ['คลินิก', 'ร้านขายยา', 'อาหาร', 'น้ำดื่ม', 'ร้านชำ']
  
  const sheetNames = types ? types.map(t => t.type_name) : defaultTypes

  // Create a sheet for each business type
  sheetNames.forEach((typeName, index) => {
    // Make sure sheet name doesn't exceed 31 chars (Excel limit) and replace invalid chars
    let safeSheetName = typeName.replace(/[\\/*?:\[\]]/g, '').substring(0, 31)
    if (!safeSheetName) safeSheetName = `Sheet${index + 1}`

    const ws_data = [
      header,
      [typeName, 'กรอกชื่อสถานประกอบการ', '12345678', 'ชื่อผู้รับอนุญาต', 'ชื่อผู้ดำเนิน', '123/45', '1', 'ตำบล...', 'อำเภอ...', '0812345678', 'active', 'low']
    ]
    const ws = XLSX.utils.aoa_to_sheet(ws_data)
    ws['!cols'] = wscols
    XLSX.utils.book_append_sheet(wb, ws, safeSheetName)
  })

  XLSX.writeFile(wb, "cscp.xlsx")
}

const handleFileUpload = async (event) => {
  const file = event.target.files[0]
  if (!file) return
  
  isImporting.value = true
  
  try {
    const data = await file.arrayBuffer()
    const workbook = XLSX.read(data)
    
    let allBusinesses = []
    
    // Loop through ALL sheets
    workbook.SheetNames.forEach(sheetName => {
      const worksheet = workbook.Sheets[sheetName]
      const jsonData = XLSX.utils.sheet_to_json(worksheet, { header: 1 })
      
      // First row is header, skip it
      const rows = jsonData.slice(1).filter(row => row.length > 0 && row[0] && row[1]) // Must have at least type and name
      
      const businessesFromSheet = rows.map(row => {
        return {
          business_type: row[0]?.toString() || sheetName, // Use sheet name as fallback if type column is empty
          business_name: row[1]?.toString() || '',
          license_no: row[2]?.toString() || '',
          licensee_name: row[3]?.toString() || '',
          operator_name: row[4]?.toString() || '',
          address: row[5]?.toString() || '',
          moo: row[6]?.toString() || '',
          subdistrict: row[7]?.toString() || '',
          district: (!isAdmin.value && userDistrict.value) ? userDistrict.value : (row[8]?.toString() || ''),
          phone: row[9]?.toString() || '',
          license_status: row[10]?.toString() || 'active',
          risk_level: row[11]?.toString() || 'low',
          province: 'ระยอง'
        }
      })
      
      allBusinesses = [...allBusinesses, ...businessesFromSheet]
    })
    
    if (allBusinesses.length === 0) {
      Swal.fire('ข้อผิดพลาด', 'ไม่พบข้อมูลที่สามารถนำเข้าได้จากทุกชีต (ต้องระบุประเภทกิจการและชื่อสถานประกอบการ)', 'error')
      event.target.value = null
      isImporting.value = false
      return
    }

    // Insert all collected businesses
    const { error } = await supabase.from('businesses').insert(allBusinesses)
    
    if (error) throw error
    
    Swal.fire('สำเร็จ', `ดึงข้อมูลจากทุกชีตและนำเข้าสำเร็จจำนวน ${allBusinesses.length} รายการ`, 'success')
    await fetchBusinesses()
    
  } catch (error) {
    console.error(error)
    Swal.fire('ข้อผิดพลาด', 'เกิดข้อผิดพลาดในการนำเข้าข้อมูล: ' + error.message, 'error')
  } finally {
    event.target.value = null
    isImporting.value = false
  }
}

const fetchBusinessTypes = async () => {
  const { data } = await supabase.from('business_types').select('*').order('type_name')
  if (data) {
    filterTabs.value = ['ทั้งหมด', ...data.map(t => t.type_name)]
  }
}

const fetchBusinesses = async () => {
  loading.value = true
  try {
    let query = supabase.from('businesses').select('*').order('created_at', { ascending: false })
    if (!isAdmin.value && userDistrict.value) {
      query = query.eq('district', userDistrict.value)
    }
    
    const { data, error } = await query
    
    if (error) throw error
    businesses.value = data || []
  } catch (error) {
    console.error('Error fetching businesses:', error.message)
  } finally {
    loading.value = false
  }
}

onMounted(async () => {
  await fetchBusinessTypes()
  await fetchBusinesses()
})

const viewDetail = (id) => {
  router.push(`/businesses/${id}`)
}

// Computed: Filter and Search
const filteredBusinesses = computed(() => {
  let result = businesses.value

  // 1. Tab Filter
  if (activeFilter.value !== 'ทั้งหมด') {
    result = result.filter(b => b.business_type === activeFilter.value)
  }

  // 2. Text Search
  if (searchQuery.value) {
    const q = searchQuery.value.toLowerCase()
    result = result.filter(b => 
      (b.business_name && b.business_name.toLowerCase().includes(q)) ||
      (b.license_no && b.license_no.toLowerCase().includes(q)) ||
      (b.licensee_name && b.licensee_name.toLowerCase().includes(q))
    )
  }

  return result
})

// Computed: Pagination
const totalPages = computed(() => Math.ceil(filteredBusinesses.value.length / itemsPerPage) || 1)

const paginatedBusinesses = computed(() => {
  const start = (currentPage.value - 1) * itemsPerPage
  const end = start + itemsPerPage
  return filteredBusinesses.value.slice(start, end)
})

const changePage = (page) => {
  if (page >= 1 && page <= totalPages.value) {
    currentPage.value = page
  }
}
</script>

<template>
  <div class="space-y-6 pb-10">
    <!-- Header Section -->
    <div class="bg-white p-6 rounded-2xl shadow-sm border border-slate-200 flex flex-col md:flex-row md:items-center justify-between gap-4 relative overflow-hidden">
      <!-- Decorative bg -->
      <div class="absolute -top-10 -right-10 w-40 h-40 bg-primary-50 rounded-full blur-3xl opacity-50 pointer-events-none"></div>
      
      <div>
        <h1 class="text-2xl font-extrabold text-slate-900 tracking-tight">รายชื่อสถานประกอบการ</h1>
        <p class="text-sm text-slate-500 mt-1">จัดการและตรวจสอบสถานประกอบการทั้งหมดในระบบ (ทั้งหมด {{ businesses.length }} รายการ)</p>
      </div>
      <div class="flex flex-col sm:flex-row gap-2">
        <!-- Hidden file input -->
        <input type="file" ref="fileInput" accept=".xlsx, .xls" class="hidden" @change="handleFileUpload" />
        
        <button @click="downloadTemplate" class="flex items-center justify-center px-4 py-2 bg-white border border-slate-300 text-slate-700 rounded-xl hover:bg-slate-50 transition-colors shadow-sm text-sm font-medium">
          <Download class="w-4 h-4 mr-2 text-slate-500" />
          โหลดฟอร์ม Excel
        </button>
        
        <button @click="triggerFileInput" :disabled="isImporting" class="flex items-center justify-center px-4 py-2 bg-emerald-50 border border-emerald-200 text-emerald-700 rounded-xl hover:bg-emerald-100 transition-colors shadow-sm text-sm font-medium disabled:opacity-50">
          <div v-if="isImporting" class="animate-spin w-4 h-4 border-2 border-emerald-500 border-t-transparent rounded-full mr-2"></div>
          <UploadCloud v-else class="w-4 h-4 mr-2" />
          {{ isImporting ? 'กำลังนำเข้า...' : 'อัปโหลด Excel' }}
        </button>

        <router-link to="/businesses/new" class="btn-primary px-4 py-2 rounded-xl text-sm font-medium shadow-md hover:shadow-lg transition-all transform hover:-translate-y-0.5 flex items-center justify-center">
          <Plus class="w-4 h-4 mr-2" />
          เพิ่มรายการใหม่
        </router-link>
      </div>
    </div>

    <!-- Filters & Search Bar -->
    <div class="flex flex-col xl:flex-row gap-4 items-center justify-between">
      
      <!-- Tab Filters -->
      <div class="flex overflow-x-auto hide-scrollbar w-full xl:w-auto bg-white p-1.5 rounded-xl shadow-sm border border-slate-200">
        <button 
          v-for="tab in filterTabs" 
          :key="tab"
          @click="activeFilter = tab; currentPage = 1"
          :class="[
            'whitespace-nowrap px-4 py-2 text-sm font-medium rounded-lg transition-colors',
            activeFilter === tab 
              ? 'bg-primary-500 text-white shadow-sm' 
              : 'text-slate-600 hover:bg-slate-100 hover:text-slate-900'
          ]"
        >
          {{ tab }}
        </button>
      </div>

      <!-- Search Input -->
      <div class="w-full xl:w-96 relative">
        <div class="absolute inset-y-0 left-0 pl-3.5 flex items-center pointer-events-none">
          <Search class="h-5 w-5 text-slate-400" />
        </div>
        <input 
          type="text" 
          v-model="searchQuery" 
          @input="currentPage = 1"
          class="block w-full pl-10 pr-3 py-2.5 border border-slate-300 rounded-xl leading-5 bg-white placeholder-slate-400 focus:outline-none focus:bg-white focus:ring-2 focus:ring-primary-500 focus:border-primary-500 sm:text-sm transition-shadow shadow-sm" 
          placeholder="ค้นหาชื่อ, เลขใบอนุญาต, ผู้รับอนุญาต..." 
        />
      </div>
    </div>

    <!-- Data Table Card -->
    <div class="bg-white rounded-2xl shadow-sm border border-slate-200 overflow-hidden">
      <div class="overflow-x-auto">
        <table class="min-w-full divide-y divide-slate-200">
          <thead class="bg-slate-50/80">
            <tr>
              <th scope="col" class="px-6 py-4 text-left text-xs font-semibold text-slate-500 uppercase tracking-wider w-2/5">กิจการ</th>
              <th scope="col" class="px-6 py-4 text-left text-xs font-semibold text-slate-500 uppercase tracking-wider">ใบอนุญาต</th>
              <th scope="col" class="px-6 py-4 text-left text-xs font-semibold text-slate-500 uppercase tracking-wider">สถานะ</th>
              <th scope="col" class="px-6 py-4 text-left text-xs font-semibold text-slate-500 uppercase tracking-wider">ความเสี่ยง</th>
              <th scope="col" class="relative px-6 py-4"><span class="sr-only">ดูรายละเอียด</span></th>
            </tr>
          </thead>
          
          <tbody class="divide-y divide-slate-100 bg-white">
            <tr v-if="loading">
               <td colspan="5" class="px-6 py-12 text-center">
                 <div class="flex flex-col items-center justify-center space-y-3">
                   <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600"></div>
                   <p class="text-slate-500 text-sm font-medium">กำลังโหลดข้อมูล...</p>
                 </div>
               </td>
            </tr>
            <tr v-else-if="filteredBusinesses.length === 0">
               <td colspan="5" class="px-6 py-16 text-center">
                 <div class="flex flex-col items-center justify-center space-y-3 text-slate-400">
                   <Search class="h-10 w-10 text-slate-300" />
                   <p class="text-lg font-medium text-slate-600">ไม่พบข้อมูลที่ค้นหา</p>
                   <p class="text-sm">ลองเปลี่ยนคำค้นหาหรือตัวกรองหมวดหมู่ด้านบน</p>
                 </div>
               </td>
            </tr>
            <tr 
              v-for="business in paginatedBusinesses" 
              :key="business.id" 
              class="hover:bg-slate-50 transition-colors cursor-pointer group" 
              @click="viewDetail(business.id)"
            >
              <!-- Name & Type -->
              <td class="px-6 py-4">
                <div class="flex items-center">
                  <div class="flex-shrink-0 h-10 w-10 rounded-full bg-slate-100 flex items-center justify-center text-slate-500 group-hover:bg-primary-100 group-hover:text-primary-600 transition-colors mr-4">
                    <Store v-if="business.business_type.includes('ร้าน')" class="h-5 w-5" />
                    <Activity v-else class="h-5 w-5" />
                  </div>
                  <div>
                    <div class="text-sm font-bold text-slate-900 group-hover:text-primary-700 transition-colors">
                      {{ business.business_name }}
                    </div>
                    <div class="text-xs text-slate-500 mt-0.5 flex items-center gap-2">
                      <BusinessTypeBadge :type="business.business_type" class="!px-1.5 !py-0 !text-[10px]" />
                      <span v-if="business.subdistrict || business.district" class="text-slate-400">• {{ business.subdistrict }} {{ business.district }}</span>
                    </div>
                  </div>
                </div>
              </td>
              
              <!-- License -->
              <td class="px-6 py-4 whitespace-nowrap">
                <div class="text-sm font-medium text-slate-900">{{ business.license_no || '-' }}</div>
                <div class="text-xs text-slate-500 mt-0.5">{{ business.licensee_name || 'ไม่ระบุชื่อผู้รับอนุญาต' }}</div>
              </td>
              
              <!-- Status -->
              <td class="px-6 py-4 whitespace-nowrap">
                <LicenseStatusBadge :status="business.license_status" />
                <div v-if="business.current_expire_year" class="text-[10px] text-slate-400 mt-1">หมดอายุปี: {{ business.current_expire_year }}</div>
              </td>
              
              <!-- Risk -->
              <td class="px-6 py-4 whitespace-nowrap">
                <RiskBadge :level="business.risk_level" />
              </td>
              
              <!-- Action -->
              <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                <div class="w-8 h-8 rounded-full bg-white border border-slate-200 flex items-center justify-center ml-auto text-slate-400 group-hover:bg-primary-50 group-hover:border-primary-200 group-hover:text-primary-600 transition-all">
                  <ChevronRightIcon class="w-4 h-4" />
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
      
      <!-- Pagination Footer -->
      <div class="bg-slate-50 px-6 py-4 border-t border-slate-200 flex items-center justify-between" v-if="filteredBusinesses.length > 0">
        <div class="text-sm text-slate-500">
          แสดง <span class="font-medium text-slate-900">{{ ((currentPage - 1) * itemsPerPage) + 1 }}</span> ถึง 
          <span class="font-medium text-slate-900">{{ Math.min(currentPage * itemsPerPage, filteredBusinesses.length) }}</span> 
          จากทั้งหมด <span class="font-medium text-slate-900">{{ filteredBusinesses.length }}</span> รายการ
        </div>
        <div class="flex space-x-2">
          <button 
            @click="changePage(currentPage - 1)" 
            :disabled="currentPage === 1"
            class="p-2 rounded-lg border border-slate-300 bg-white text-slate-500 hover:bg-slate-50 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
          >
            <ChevronLeft class="w-4 h-4" />
          </button>
          <div class="flex items-center space-x-1">
            <button 
              v-for="p in totalPages" 
              :key="p"
              v-show="p === 1 || p === totalPages || Math.abs(p - currentPage) <= 1"
              @click="changePage(p)"
              :class="[
                'w-8 h-8 flex items-center justify-center rounded-lg text-sm font-medium transition-colors',
                currentPage === p ? 'bg-primary-600 text-white' : 'bg-white border border-slate-300 text-slate-700 hover:bg-slate-50'
              ]"
            >
              {{ p }}
            </button>
          </div>
          <button 
            @click="changePage(currentPage + 1)" 
            :disabled="currentPage === totalPages"
            class="p-2 rounded-lg border border-slate-300 bg-white text-slate-500 hover:bg-slate-50 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
          >
            <ChevronRightIcon class="w-4 h-4" />
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
/* Hide scrollbar for horizontal scrolling tabs */
.hide-scrollbar::-webkit-scrollbar {
  display: none;
}
.hide-scrollbar {
  -ms-overflow-style: none;
  scrollbar-width: none;
}
</style>
