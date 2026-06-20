<script setup>
import { ref, onMounted, computed } from 'vue'
import { supabase } from '../lib/supabase'
import { useAuthStore } from '../stores/auth'
import { storeToRefs } from 'pinia'
import Swal from 'sweetalert2'
import dayjs from 'dayjs'
import 'dayjs/locale/th'
import relativeTime from 'dayjs/plugin/relativeTime'
import { Users, Plus, Edit, Trash2, Search, X, Briefcase, MapPin, CalendarDays } from 'lucide-vue-next'

dayjs.extend(relativeTime)
dayjs.locale('th')

const authStore = useAuthStore()
const { isAdmin, userDistrict } = storeToRefs(authStore)

const officers = ref([])
const loading = ref(true)
const searchQuery = ref('')

const showModal = ref(false)
const isEditing = ref(false)
const currentOfficerId = ref(null)
const form = ref({
  full_name: '',
  position: '',
  workplace: '',
  start_date: '',
  district: ''
})

const fetchOfficers = async () => {
  loading.value = true
  try {
    let query = supabase.from('officers').select('*').order('created_at', { ascending: false })
    if (!isAdmin.value && userDistrict.value) {
      query = query.eq('district', userDistrict.value)
    }
    const { data, error } = await query
    if (error) throw error
    officers.value = data
  } catch (err) {
    console.error(err)
    Swal.fire('ข้อผิดพลาด', 'ไม่สามารถดึงข้อมูลเจ้าหน้าที่ได้', 'error')
  } finally {
    loading.value = false
  }
}

onMounted(() => {
  fetchOfficers()
})

const filteredOfficers = computed(() => {
  if (!searchQuery.value) return officers.value
  const q = searchQuery.value.toLowerCase()
  return officers.value.filter(o => 
    (o.full_name && o.full_name.toLowerCase().includes(q)) ||
    (o.position && o.position.toLowerCase().includes(q)) ||
    (o.workplace && o.workplace.toLowerCase().includes(q))
  )
})

const openAddModal = () => {
  isEditing.value = false
  form.value = {
    full_name: '',
    position: '',
    workplace: '',
    start_date: '',
    district: isAdmin.value ? '' : (userDistrict.value || '')
  }
  showModal.value = true
}

const openEditModal = (officer) => {
  isEditing.value = true
  currentOfficerId.value = officer.id
  form.value = {
    full_name: officer.full_name,
    position: officer.position || '',
    workplace: officer.workplace || '',
    start_date: officer.start_date || '',
    district: officer.district || ''
  }
  showModal.value = true
}

const saveOfficer = async () => {
  if (!form.value.full_name) {
    return Swal.fire('แจ้งเตือน', 'กรุณาระบุชื่อ-นามสกุล', 'warning')
  }

  try {
    if (isEditing.value) {
      const { error } = await supabase.from('officers')
        .update(form.value)
        .eq('id', currentOfficerId.value)
      if (error) throw error
      Swal.fire({ icon: 'success', title: 'อัปเดตข้อมูลเรียบร้อย', showConfirmButton: false, timer: 1500 })
    } else {
      const { error } = await supabase.from('officers')
        .insert([form.value])
      if (error) throw error
      Swal.fire({ icon: 'success', title: 'เพิ่มเจ้าหน้าที่เรียบร้อย', showConfirmButton: false, timer: 1500 })
    }
    showModal.value = false
    await fetchOfficers()
  } catch (err) {
    console.error(err)
    Swal.fire('ข้อผิดพลาด', err.message, 'error')
  }
}

const deleteOfficer = async (id) => {
  const result = await Swal.fire({
    title: 'ยืนยันการลบ',
    text: "คุณต้องการลบรายชื่อพนักงานเจ้าหน้าที่ท่านนี้ใช่หรือไม่?",
    icon: 'warning',
    showCancelButton: true,
    confirmButtonColor: '#d33',
    cancelButtonColor: '#3085d6',
    confirmButtonText: 'ใช่, ลบเลย',
    cancelButtonText: 'ยกเลิก'
  })

  if (result.isConfirmed) {
    try {
      const { error } = await supabase.from('officers').delete().eq('id', id)
      if (error) throw error
      await fetchOfficers()
      Swal.fire('ลบแล้ว!', 'ลบข้อมูลเรียบร้อยแล้ว.', 'success')
    } catch (err) {
      console.error(err)
      Swal.fire('ข้อผิดพลาด', err.message, 'error')
    }
  }
}

const calculateWorkDuration = (startDate) => {
  if (!startDate) return '-'
  return dayjs(startDate).toNow(true) // e.g. "2 years" -> in Thai "2 ปี"
}
</script>

<template>
  <div class="max-w-7xl mx-auto space-y-6 pb-12">
    <!-- Header -->
    <div class="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
      <div>
        <h1 class="text-3xl font-extrabold text-slate-900 tracking-tight flex items-center">
          <Users class="w-8 h-8 mr-3 text-indigo-600" /> ทะเบียนพนักงานเจ้าหน้าที่
        </h1>
        <p class="text-sm text-slate-500 mt-2">จัดการข้อมูลรายชื่อ ตำแหน่ง และอายุการทำงานของเจ้าหน้าที่ คบส.</p>
      </div>
      <button @click="openAddModal" class="btn-primary flex items-center shadow-lg hover:shadow-indigo-500/30">
        <Plus class="w-5 h-5 mr-2" /> เพิ่มเจ้าหน้าที่
      </button>
    </div>

    <!-- Search & Filters -->
    <div class="card p-4 sm:p-5 bg-white shadow-sm border border-slate-200">
      <div class="relative max-w-md">
        <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
          <Search class="h-5 w-5 text-slate-400" />
        </div>
        <input 
          type="text" 
          v-model="searchQuery"
          class="form-input pl-10 bg-slate-50 border-slate-200 focus:bg-white" 
          placeholder="ค้นหาชื่อ, ตำแหน่ง หรือสถานปฏิบัติงาน..."
        />
      </div>
    </div>

    <!-- Table -->
    <div class="card overflow-hidden bg-white shadow-sm border border-slate-200">
      <div v-if="loading" class="text-center py-12">
        <div class="animate-spin rounded-full h-10 w-10 border-b-2 border-indigo-600 mx-auto"></div>
        <p class="mt-4 text-slate-500 font-medium">กำลังโหลดข้อมูลเจ้าหน้าที่...</p>
      </div>
      
      <div v-else-if="filteredOfficers.length === 0" class="text-center py-16 bg-slate-50/50">
        <Users class="w-16 h-16 text-slate-300 mx-auto mb-4" />
        <h3 class="text-lg font-bold text-slate-700">ไม่พบข้อมูลเจ้าหน้าที่</h3>
        <p class="text-slate-500 mt-1 mb-6">ยังไม่มีรายชื่อเจ้าหน้าที่ในระบบ หรือไม่พบสิ่งที่ค้นหา</p>
        <button @click="openAddModal" class="btn-primary text-sm px-6">
          <Plus class="w-4 h-4 mr-2" /> เพิ่มเจ้าหน้าที่คนแรก
        </button>
      </div>

      <div v-else class="overflow-x-auto">
        <table class="w-full text-left text-sm text-slate-600">
          <thead class="bg-slate-50 text-slate-700 font-bold border-b border-slate-200 uppercase text-xs tracking-wider">
            <tr>
              <th class="px-6 py-4">ชื่อ-นามสกุล</th>
              <th class="px-6 py-4">ตำแหน่ง</th>
              <th class="px-6 py-4">สถานปฏิบัติงาน</th>
              <th class="px-6 py-4">อำเภอ</th>
              <th class="px-6 py-4">อายุงาน (คบส.)</th>
              <th class="px-6 py-4 text-right">จัดการ</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            <tr v-for="officer in filteredOfficers" :key="officer.id" class="hover:bg-slate-50 transition-colors">
              <td class="px-6 py-4">
                <div class="font-bold text-slate-900">{{ officer.full_name }}</div>
              </td>
              <td class="px-6 py-4">
                <div class="flex items-center text-slate-600">
                  <Briefcase class="w-4 h-4 mr-2 text-slate-400" />
                  {{ officer.position || '-' }}
                </div>
              </td>
              <td class="px-6 py-4">
                <div class="flex items-center text-slate-600">
                  <MapPin class="w-4 h-4 mr-2 text-slate-400" />
                  {{ officer.workplace || '-' }}
                </div>
              </td>
              <td class="px-6 py-4">
                <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-slate-100 text-slate-800">
                  {{ officer.district || 'ไม่ระบุ' }}
                </span>
              </td>
              <td class="px-6 py-4 text-slate-500">
                <div class="flex items-center">
                  <CalendarDays class="w-4 h-4 mr-2 text-slate-400" />
                  {{ calculateWorkDuration(officer.start_date) }}
                </div>
              </td>
              <td class="px-6 py-4 text-right whitespace-nowrap">
                <button @click="openEditModal(officer)" class="text-indigo-600 hover:text-indigo-900 bg-indigo-50 hover:bg-indigo-100 p-2 rounded-lg transition-colors mr-2">
                  <Edit class="w-4 h-4" />
                </button>
                <button @click="deleteOfficer(officer.id)" class="text-red-600 hover:text-red-900 bg-red-50 hover:bg-red-100 p-2 rounded-lg transition-colors">
                  <Trash2 class="w-4 h-4" />
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- Modal เพิ่ม/แก้ไข เจ้าหน้าที่ -->
    <div v-if="showModal" class="fixed inset-0 bg-slate-900/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
      <div class="bg-white rounded-2xl shadow-xl max-w-lg w-full overflow-hidden animate-fadeIn">
        <div class="p-5 border-b border-slate-100 flex justify-between items-center bg-slate-50">
          <h3 class="text-lg font-bold text-slate-900 flex items-center">
            <Users class="w-5 h-5 mr-2 text-indigo-600" /> 
            {{ isEditing ? 'แก้ไขข้อมูลเจ้าหน้าที่' : 'เพิ่มรายชื่อเจ้าหน้าที่' }}
          </h3>
          <button @click="showModal = false" class="text-slate-400 hover:text-slate-600">
            <X class="w-5 h-5" />
          </button>
        </div>
        
        <div class="p-6 space-y-4">
          <div>
            <label class="block text-sm font-medium text-slate-700 mb-1">ชื่อ-นามสกุล <span class="text-red-500">*</span></label>
            <input type="text" v-model="form.full_name" class="form-input" placeholder="ระบุชื่อและนามสกุล..." />
          </div>
          
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label class="block text-sm font-medium text-slate-700 mb-1">ตำแหน่ง</label>
              <input type="text" v-model="form.position" class="form-input" placeholder="เช่น เภสัชกรปฏิบัติการ" />
            </div>
            
            <div v-if="isAdmin">
              <label class="block text-sm font-medium text-slate-700 mb-1">อำเภอที่สังกัด</label>
              <select v-model="form.district" class="form-input">
                <option value="">-- เลือกอำเภอ --</option>
                <option value="เมืองระยอง">เมืองระยอง</option>
                <option value="ปลวกแดง">ปลวกแดง</option>
                <option value="แกลง">แกลง</option>
                <option value="บ้านค่าย">บ้านค่าย</option>
                <option value="บ้านฉาง">บ้านฉาง</option>
                <option value="นิคมพัฒนา">นิคมพัฒนา</option>
                <option value="วังจันทร์">วังจันทร์</option>
                <option value="เขาชะเมา">เขาชะเมา</option>
              </select>
            </div>
            <div v-else>
              <label class="block text-sm font-medium text-slate-700 mb-1">อำเภอที่สังกัด</label>
              <div class="form-input bg-slate-100 text-slate-500 font-bold border-slate-200">
                {{ userDistrict || 'ไม่ระบุอำเภอ' }}
              </div>
            </div>
          </div>

          <div>
            <label class="block text-sm font-medium text-slate-700 mb-1">สถานปฏิบัติงาน</label>
            <input type="text" v-model="form.workplace" class="form-input" placeholder="เช่น รพ.สต.บ้านค่าย" />
          </div>

          <div>
            <label class="block text-sm font-medium text-slate-700 mb-1">วันที่เริ่มปฏิบัติงานด้าน คบส.</label>
            <input type="date" v-model="form.start_date" class="form-input" />
            <p class="text-xs text-slate-500 mt-1">ใช้สำหรับคำนวณอายุการทำงานในระบบ</p>
          </div>
        </div>

        <div class="p-4 border-t border-slate-100 bg-slate-50 flex justify-end space-x-3">
          <button @click="showModal = false" class="btn-secondary">ยกเลิก</button>
          <button @click="saveOfficer" class="btn-primary">
            {{ isEditing ? 'บันทึกการแก้ไข' : 'เพิ่มลงฐานข้อมูล' }}
          </button>
        </div>
      </div>
    </div>

  </div>
</template>

<style scoped>
.animate-fadeIn {
  animation: fadeIn 0.2s ease-out forwards;
}
@keyframes fadeIn {
  from { opacity: 0; transform: scale(0.95); }
  to { opacity: 1; transform: scale(1); }
}
</style>
