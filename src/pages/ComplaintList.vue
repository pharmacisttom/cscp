<script setup>
import { ref, onMounted, computed, watch } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../lib/supabase'
import { useAuthStore } from '../stores/auth'
import { storeToRefs } from 'pinia'
import { 
  AlertTriangle, 
  Search, 
  Plus, 
  MessageSquare,
  Clock,
  CheckCircle2,
  XCircle,
  FileSearch,
  Store
} from 'lucide-vue-next'
import Swal from 'sweetalert2'

const router = useRouter()
const authStore = useAuthStore()
const { isAdmin, userDistrict } = storeToRefs(authStore)

const complaints = ref([])
const loading = ref(true)
const searchQuery = ref('')
const statusFilter = ref('all')

const statuses = [
  { value: 'all', label: 'ทั้งหมด' },
  { value: 'open', label: 'เปิดเรื่อง (Open)' },
  { value: 'investigating', label: 'กำลังตรวจสอบ' },
  { value: 'resolved', label: 'แก้ไขแล้ว' },
  { value: 'closed', label: 'ยุติเรื่อง' }
]

const getStatusBadge = (status) => {
  switch (status) {
    case 'open':
      return { class: 'bg-red-100 text-red-800 border-red-200', text: 'เปิดเรื่อง', icon: AlertTriangle }
    case 'investigating':
      return { class: 'bg-amber-100 text-amber-800 border-amber-200', text: 'กำลังตรวจสอบ', icon: Clock }
    case 'resolved':
      return { class: 'bg-green-100 text-green-800 border-green-200', text: 'แก้ไขแล้ว', icon: CheckCircle2 }
    case 'closed':
      return { class: 'bg-slate-100 text-slate-800 border-slate-200', text: 'ยุติเรื่อง', icon: XCircle }
    default:
      return { class: 'bg-slate-100 text-slate-800 border-slate-200', text: status || 'ไม่ระบุ', icon: MessageSquare }
  }
}

const fetchComplaints = async () => {
  loading.value = true
  try {
    let query = supabase
      .from('complaints')
      .select(`
        *,
        businesses (
          business_name,
          district
        )
      `)
      .order('created_at', { ascending: false })

    if (!isAdmin.value && userDistrict.value) {
      // Filter by district using foreign table syntax
      query = query.eq('businesses.district', userDistrict.value)
    }

    if (statusFilter.value !== 'all') {
      query = query.eq('status', statusFilter.value)
    }

    const { data, error } = await query
    
    if (error) throw error

    // Remove rows where businesses is null (can happen if RLS blocks foreign table row)
    if (!isAdmin.value) {
      complaints.value = data.filter(c => c.businesses !== null)
    } else {
      complaints.value = data
    }

  } catch (error) {
    console.error('Error fetching complaints:', error)
    Swal.fire('ข้อผิดพลาด', 'ไม่สามารถโหลดข้อมูลเรื่องร้องเรียนได้', 'error')
  } finally {
    loading.value = false
  }
}

const filteredComplaints = computed(() => {
  if (!searchQuery.value) return complaints.value
  
  const q = searchQuery.value.toLowerCase()
  return complaints.value.filter(c => 
    (c.complaint_topic && c.complaint_topic.toLowerCase().includes(q)) ||
    (c.businesses?.business_name && c.businesses.business_name.toLowerCase().includes(q)) ||
    (c.complainant_name && c.complainant_name.toLowerCase().includes(q))
  )
})

const formatDate = (dateString) => {
  if (!dateString) return '-'
  return new Date(dateString).toLocaleDateString('th-TH', {
    year: 'numeric',
    month: 'short',
    day: 'numeric'
  })
}

const navigateToComplaint = (id, businessId) => {
  // If we want to edit, we can navigate to the complaint form. 
  // Let's pass the complaint ID via query so the form can load it if we decide to implement editing.
  // For now, let's navigate to the business detail page.
  router.push(`/businesses/${businessId}`)
}

watch(statusFilter, () => {
  fetchComplaints()
})

onMounted(() => {
  fetchComplaints()
})
</script>

<template>
  <div class="space-y-6">
    <div class="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
      <div>
        <h1 class="text-2xl font-bold text-slate-900 flex items-center">
          <MessageSquare class="w-6 h-6 mr-2 text-primary-500" />
          ศูนย์รับเรื่องร้องเรียน
        </h1>
        <p class="text-sm text-slate-500 mt-1">จัดการและติดตามสถานะข้อร้องเรียนทั้งหมด</p>
      </div>
      <button @click="router.push('/complaints/new')" class="btn-primary flex items-center shadow-md hover:shadow-lg">
        <Plus class="w-4 h-4 mr-2" />
        บันทึกเรื่องร้องเรียนใหม่
      </button>
    </div>

    <!-- Filters & Search -->
    <div class="card p-4 flex flex-col md:flex-row gap-4">
      <div class="flex-1 relative">
        <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
          <Search class="h-5 w-5 text-slate-400" />
        </div>
        <input 
          v-model="searchQuery" 
          type="text" 
          placeholder="ค้นหาจากหัวข้อ, ชื่อร้าน, ผู้ร้องเรียน..." 
          class="form-input pl-10 w-full"
        />
      </div>
      <div class="w-full md:w-64">
        <select v-model="statusFilter" class="form-input w-full">
          <option v-for="s in statuses" :key="s.value" :value="s.value">{{ s.label }}</option>
        </select>
      </div>
    </div>

    <!-- Table -->
    <div class="card overflow-hidden">
      <div v-if="loading" class="p-12 text-center">
        <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600 mx-auto"></div>
        <p class="text-slate-500 mt-4">กำลังโหลดข้อมูล...</p>
      </div>
      
      <div v-else-if="filteredComplaints.length === 0" class="p-16 text-center">
        <FileSearch class="w-12 h-12 text-slate-300 mx-auto mb-4" />
        <h3 class="text-lg font-medium text-slate-900">ไม่พบเรื่องร้องเรียน</h3>
        <p class="text-slate-500 mt-1">ไม่มีเรื่องร้องเรียนที่ตรงกับเงื่อนไขการค้นหาของคุณ</p>
      </div>

      <div v-else class="overflow-x-auto">
        <table class="min-w-full divide-y divide-slate-200">
          <thead class="bg-slate-50">
            <tr>
              <th scope="col" class="px-6 py-3 text-left text-xs font-bold text-slate-500 uppercase tracking-wider">วันที่รับเรื่อง</th>
              <th scope="col" class="px-6 py-3 text-left text-xs font-bold text-slate-500 uppercase tracking-wider">หัวข้อ / สถานประกอบการ</th>
              <th scope="col" class="px-6 py-3 text-left text-xs font-bold text-slate-500 uppercase tracking-wider">สถานะ</th>
              <th scope="col" class="px-6 py-3 text-left text-xs font-bold text-slate-500 uppercase tracking-wider">ผู้รับผิดชอบ (อำเภอ)</th>
              <th scope="col" class="px-6 py-3 text-center text-xs font-bold text-slate-500 uppercase tracking-wider">จัดการ</th>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-slate-100">
            <tr v-for="c in filteredComplaints" :key="c.id" class="hover:bg-slate-50 transition-colors">
              <td class="px-6 py-4 whitespace-nowrap text-sm text-slate-500">
                {{ formatDate(c.complaint_date) }}
              </td>
              <td class="px-6 py-4">
                <div class="text-sm font-bold text-slate-900">{{ c.complaint_topic }}</div>
                <div class="text-xs text-slate-500 mt-1 flex items-center">
                  <Store class="w-3 h-3 mr-1" />
                  {{ c.businesses?.business_name || 'ไม่พบข้อมูลร้าน' }}
                </div>
              </td>
              <td class="px-6 py-4 whitespace-nowrap">
                <span :class="[getStatusBadge(c.status).class, 'inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium border']">
                  <component :is="getStatusBadge(c.status).icon" class="w-3.5 h-3.5 mr-1" />
                  {{ getStatusBadge(c.status).text }}
                </span>
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-sm text-slate-500">
                {{ c.businesses?.district || '-' }}
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-center text-sm font-medium">
                <button @click="navigateToComplaint(c.id, c.business_id)" class="text-primary-600 hover:text-primary-900 bg-primary-50 px-3 py-1.5 rounded-lg hover:bg-primary-100 transition-colors">
                  ดูรายละเอียด
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>
