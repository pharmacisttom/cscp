<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../lib/supabase'
import { useAuthStore } from '../stores/auth'
import { storeToRefs } from 'pinia'
import dayjs from 'dayjs'
import 'dayjs/locale/th'
import localeData from 'dayjs/plugin/localeData'
import isSameOrBefore from 'dayjs/plugin/isSameOrBefore'
import Swal from 'sweetalert2'
import { Calendar, ChevronLeft, ChevronRight, Plus, MapPin, CheckCircle, Clock, Search, X, Users, UserPlus, ClipboardList, Trash2, CheckSquare, FileText } from 'lucide-vue-next'

dayjs.extend(localeData)
dayjs.extend(isSameOrBefore)
dayjs.locale('th')

const authStore = useAuthStore()
const { isAdmin, userDistrict, user } = storeToRefs(authStore)

const currentDate = ref(dayjs())
const selectedDate = ref(dayjs().format('YYYY-MM-DD'))

const plans = ref([])
const businesses = ref([])
const officers = ref([])
const loading = ref(true)

// Add Plan Modal state
const showModal = ref(false)
const searchQuery = ref('')
const newPlan = ref({
  business_id: '',
  inspectors: []
})

// Attendance Modal state
const showAttendanceModal = ref(false)
const selectedPlanForAttendance = ref(null)

const fetchPlans = async () => {
  try {
    let query = supabase
      .from('inspection_plans')
      .select(`
        *,
        businesses (
          business_name,
          business_type,
          district,
          latitude,
          longitude
        )
      `)

    const { data, error } = await query
    if (error) throw error

    if (!isAdmin.value && userDistrict.value) {
      plans.value = data.filter(p => p.businesses?.district === userDistrict.value)
    } else {
      plans.value = data
    }
  } catch (err) {
    console.error(err)
    Swal.fire('ข้อผิดพลาด', 'ไม่สามารถดึงข้อมูลแผนการตรวจได้', 'error')
  }
}

const fetchBusinesses = async () => {
  try {
    let query = supabase.from('businesses').select('id, business_name, district')
    if (!isAdmin.value && userDistrict.value) {
      query = query.eq('district', userDistrict.value)
    }
    const { data, error } = await query
    if (error) throw error
    businesses.value = data
  } catch (err) {
    console.error(err)
  }
}

const fetchOfficers = async () => {
  try {
    let query = supabase.from('officers').select('full_name, position, district')
    if (!isAdmin.value && userDistrict.value) {
      query = query.eq('district', userDistrict.value)
    }
    const { data, error } = await query
    if (error) throw error
    officers.value = data
  } catch (err) {
    console.error(err)
  }
}

const loadData = async () => {
  loading.value = true
  await Promise.all([fetchPlans(), fetchBusinesses(), fetchOfficers()])
  loading.value = false
}

onMounted(() => {
  loadData()
})

const daysInMonth = computed(() => {
  const start = currentDate.value.startOf('month')
  const end = currentDate.value.endOf('month')
  const startDay = start.day() 
  const days = []
  
  for (let i = 0; i < startDay; i++) {
    days.push({ date: start.subtract(startDay - i, 'day'), isCurrentMonth: false })
  }
  
  for (let i = 1; i <= end.date(); i++) {
    days.push({ date: start.date(i), isCurrentMonth: true })
  }
  
  const remainingCells = 42 - days.length
  for (let i = 1; i <= remainingCells; i++) {
    days.push({ date: end.add(i, 'day'), isCurrentMonth: false })
  }
  return days
})

const nextMonth = () => { currentDate.value = currentDate.value.add(1, 'month') }
const prevMonth = () => { currentDate.value = currentDate.value.subtract(1, 'month') }
const goToToday = () => { 
  currentDate.value = dayjs()
  selectedDate.value = dayjs().format('YYYY-MM-DD')
}

const selectDate = (date) => {
  selectedDate.value = date.format('YYYY-MM-DD')
}

const getPlansForDate = (dateStr) => {
  return plans.value.filter(p => p.planned_date === dateStr)
}

const selectedDatePlans = computed(() => {
  return getPlansForDate(selectedDate.value).sort((a, b) => a.created_at.localeCompare(b.created_at))
})

const filteredBusinesses = computed(() => {
  if (!searchQuery.value) return businesses.value.slice(0, 50) 
  const q = searchQuery.value.toLowerCase()
  return businesses.value.filter(b => b.business_name.toLowerCase().includes(q)).slice(0, 50)
})

// === Add Plan Logic ===
const openAddPlanModal = () => {
  newPlan.value = { 
    business_id: '', 
    inspectors: [
      { name: '', role: 'leader', attendance: 'pending', substitute_name: '', reason: '' }
    ]
  }
  searchQuery.value = ''
  showModal.value = true
}

const addInspector = () => {
  newPlan.value.inspectors.push({ name: '', role: 'member', attendance: 'pending', substitute_name: '', reason: '' })
}

const removeInspector = (index) => {
  if (index !== 0) {
    newPlan.value.inspectors.splice(index, 1)
  }
}

const savePlan = async () => {
  if (!newPlan.value.business_id) {
    return Swal.fire('แจ้งเตือน', 'กรุณาเลือกสถานประกอบการ', 'warning')
  }
  
  for (let i = 0; i < newPlan.value.inspectors.length; i++) {
    if (!newPlan.value.inspectors[i].name.trim()) {
      return Swal.fire('แจ้งเตือน', 'กรุณาระบุชื่อเจ้าหน้าที่ให้ครบถ้วน', 'warning')
    }
  }

  try {
    const payload = {
      business_id: newPlan.value.business_id,
      planned_date: selectedDate.value,
      inspectors_data: newPlan.value.inspectors,
      status: 'planned',
      created_by: user.value?.id
    }

    const { error } = await supabase.from('inspection_plans').insert([payload])
    if (error) throw error

    Swal.fire({ icon: 'success', title: 'เพิ่มแผนออกตรวจเรียบร้อย', showConfirmButton: false, timer: 1500 })
    showModal.value = false
    await fetchPlans()
  } catch (err) {
    console.error(err)
    Swal.fire('ข้อผิดพลาด', err.message, 'error')
  }
}

// === Attendance Logic ===
const openAttendanceModal = (plan) => {
  let inspectors = plan.inspectors_data || []
  if (!Array.isArray(inspectors) || inspectors.length === 0) {
    // Fallback for old data or empty arrays
    inspectors = [{ name: plan.inspector_name || 'ไม่ระบุ', role: 'leader', attendance: 'pending', substitute_name: '', reason: '' }]
  }

  selectedPlanForAttendance.value = {
    ...plan,
    inspectors_data: JSON.parse(JSON.stringify(inspectors))
  }
  showAttendanceModal.value = true
}

const saveAttendance = async () => {
  try {
    const { error } = await supabase
      .from('inspection_plans')
      .update({ inspectors_data: selectedPlanForAttendance.value.inspectors_data })
      .eq('id', selectedPlanForAttendance.value.id)
      
    if (error) throw error

    Swal.fire({ icon: 'success', title: 'บันทึกการเช็คชื่อแล้ว', showConfirmButton: false, timer: 1500 })
    showAttendanceModal.value = false
    await fetchPlans()
  } catch (err) {
    console.error(err)
    Swal.fire('ข้อผิดพลาด', 'บันทึกการเช็คชื่อไม่สำเร็จ', 'error')
  }
}

const updatePlanStatus = async (planId, status) => {
  try {
    const { error } = await supabase.from('inspection_plans').update({ status }).eq('id', planId)
    if (error) throw error
    await fetchPlans()
  } catch (err) {
    console.error(err)
    Swal.fire('ข้อผิดพลาด', 'ไม่สามารถอัปเดตสถานะได้', 'error')
  }
}

const openMap = (lat, lon) => {
  if (lat && lon) {
    window.open(`https://www.google.com/maps/dir/?api=1&destination=${lat},${lon}`, '_blank')
  } else {
    Swal.fire('ไม่พบข้อมูล', 'สถานประกอบการนี้ยังไม่ได้ระบุพิกัดในระบบ', 'warning')
  }
}

const deletePlan = async (planId) => {
  const result = await Swal.fire({
    title: 'ยืนยันการลบ',
    text: "คุณต้องการลบแผนออกตรวจนี้ใช่หรือไม่?",
    icon: 'warning',
    showCancelButton: true,
    confirmButtonColor: '#d33',
    cancelButtonColor: '#3085d6',
    confirmButtonText: 'ใช่, ลบเลย',
    cancelButtonText: 'ยกเลิก'
  })

  if (result.isConfirmed) {
    try {
      const { error } = await supabase.from('inspection_plans').delete().eq('id', planId)
      if (error) throw error
      await fetchPlans()
      Swal.fire('ลบแล้ว!', 'ลบแผนออกตรวจเรียบร้อยแล้ว.', 'success')
    } catch (err) {
      console.error(err)
      Swal.fire('ข้อผิดพลาด', err.message, 'error')
    }
  }
}

const getTeamDisplay = (inspectorsData, legacyName) => {
  if (Array.isArray(inspectorsData) && inspectorsData.length > 0) {
    const leader = inspectorsData[0].name
    const membersCount = inspectorsData.length - 1
    if (membersCount > 0) return `${leader} (หัวหน้า) + อีก ${membersCount} คน`
    return `${leader} (หัวหน้าทีม)`
  }
  return legacyName || 'ไม่ระบุชื่อ'
}
</script>

<template>
  <div class="max-w-7xl mx-auto space-y-6 pb-12">
    <!-- Header -->
    <div class="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
      <div>
        <h1 class="text-3xl font-extrabold text-slate-900 tracking-tight flex items-center">
          <Calendar class="w-8 h-8 mr-3 text-primary-600" /> ปฏิทินแผนออกตรวจ
        </h1>
        <p class="text-sm text-slate-500 mt-2">วางแผน จัดทีม และเช็คชื่อการลงพื้นที่ตรวจสถานประกอบการ</p>
      </div>
    </div>

    <div v-if="loading" class="text-center py-20">
      <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-600 mx-auto"></div>
      <p class="mt-4 text-slate-500 font-medium">กำลังโหลดข้อมูลปฏิทิน...</p>
    </div>

    <div v-else class="grid grid-cols-1 lg:grid-cols-3 gap-6">
      
      <!-- Left: Calendar Widget -->
      <div class="lg:col-span-2 card p-6 bg-white shadow-sm border border-slate-200">
        <div class="flex justify-between items-center mb-6">
          <h2 class="text-xl font-bold text-slate-900">{{ currentDate.format('MMMM YYYY') }}</h2>
          <div class="flex space-x-2">
            <button @click="goToToday" class="px-3 py-1.5 text-sm font-medium text-primary-600 bg-primary-50 rounded-lg hover:bg-primary-100">
              วันนี้
            </button>
            <button @click="prevMonth" class="p-1.5 text-slate-500 hover:text-slate-700 hover:bg-slate-100 rounded-lg">
              <ChevronLeft class="w-5 h-5" />
            </button>
            <button @click="nextMonth" class="p-1.5 text-slate-500 hover:text-slate-700 hover:bg-slate-100 rounded-lg">
              <ChevronRight class="w-5 h-5" />
            </button>
          </div>
        </div>

        <div class="grid grid-cols-7 gap-1 text-center mb-2">
          <div v-for="day in ['อา', 'จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส']" :key="day" class="text-xs font-bold text-slate-400 uppercase tracking-wider py-2">
            {{ day }}
          </div>
        </div>

        <div class="grid grid-cols-7 gap-1 lg:gap-2">
          <div 
            v-for="(day, idx) in daysInMonth" :key="idx"
            @click="selectDate(day.date)"
            :class="[
              'min-h-[80px] lg:min-h-[100px] border rounded-lg p-2 flex flex-col transition-all cursor-pointer relative',
              day.isCurrentMonth ? 'bg-white border-slate-200 hover:border-primary-400' : 'bg-slate-50 border-slate-100 text-slate-400',
              day.date.format('YYYY-MM-DD') === dayjs().format('YYYY-MM-DD') ? 'ring-2 ring-primary-500 ring-inset' : '',
              day.date.format('YYYY-MM-DD') === selectedDate ? 'bg-primary-50 border-primary-500 shadow-sm' : ''
            ]"
          >
            <div :class="['text-sm font-semibold mb-1', day.date.format('YYYY-MM-DD') === dayjs().format('YYYY-MM-DD') ? 'text-primary-600' : '']">
              {{ day.date.format('D') }}
            </div>
            
            <div class="flex-1 overflow-y-auto hide-scrollbar space-y-1">
              <div 
                v-for="plan in getPlansForDate(day.date.format('YYYY-MM-DD'))" :key="plan.id"
                :class="[
                  'text-[10px] sm:text-xs truncate px-1.5 py-0.5 rounded font-medium text-left',
                  plan.status === 'completed' ? 'bg-green-100 text-green-700' : 
                  plan.status === 'cancelled' ? 'bg-slate-200 text-slate-600 line-through' :
                  'bg-indigo-100 text-indigo-700'
                ]"
                :title="plan.businesses?.business_name"
              >
                {{ plan.businesses?.business_name }}
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Right: Daily Plans List -->
      <div class="lg:col-span-1 card flex flex-col h-full bg-slate-50/50 border border-slate-200 shadow-sm overflow-hidden">
        <div class="p-5 border-b border-slate-200 bg-white">
          <h3 class="text-lg font-bold text-slate-900">แผนงานวันที่ {{ dayjs(selectedDate).format('D MMM YYYY') }}</h3>
          <p class="text-sm text-slate-500 mt-1">จำนวน {{ selectedDatePlans.length }} รายการ</p>
          
          <button @click="openAddPlanModal" class="btn-primary w-full mt-4 flex justify-center items-center py-2">
            <Plus class="w-4 h-4 mr-2" /> เพิ่มแผนจัดทีมตรวจ
          </button>
        </div>

        <div class="flex-1 overflow-y-auto p-4 space-y-4 max-h-[600px]">
          <div v-if="selectedDatePlans.length === 0" class="text-center py-10">
            <Calendar class="w-12 h-12 text-slate-300 mx-auto mb-3" />
            <p class="text-sm font-medium text-slate-500">ไม่มีแผนงานในวันนี้</p>
          </div>

          <div v-else v-for="plan in selectedDatePlans" :key="plan.id" class="bg-white p-4 rounded-xl shadow-sm border border-slate-200 hover:shadow-md transition-shadow relative group">
            
            <button @click="deletePlan(plan.id)" class="absolute top-3 right-3 text-slate-300 hover:text-red-500 opacity-0 group-hover:opacity-100 transition-opacity">
              <X class="w-4 h-4" />
            </button>

            <div class="flex items-center space-x-2 mb-2 pr-6">
              <div :class="['w-2 h-2 rounded-full', plan.status === 'completed' ? 'bg-green-500' : plan.status === 'cancelled' ? 'bg-slate-400' : 'bg-indigo-500']"></div>
              <span class="text-xs font-bold text-slate-500">
                {{ plan.status === 'completed' ? 'ตรวจแล้ว' : plan.status === 'cancelled' ? 'ยกเลิก' : 'รอดำเนินการ' }}
              </span>
            </div>

            <h4 class="font-bold text-slate-900 leading-tight mb-1" :class="{'line-through text-slate-500': plan.status === 'cancelled'}">
              {{ plan.businesses?.business_name || 'ไม่พบชื่อกิจการ' }}
            </h4>
            <div class="text-xs text-slate-500 mb-3 line-clamp-1">อ.{{ plan.businesses?.district || '-' }} • {{ plan.businesses?.business_type || '-' }}</div>
            
            <!-- Team Info -->
            <div class="flex items-center text-xs text-slate-600 mb-3 bg-slate-50 p-2 rounded border border-slate-100">
              <Users class="w-3.5 h-3.5 mr-1.5 text-primary-500" />
              ทีมตรวจ: <span class="font-bold text-primary-700 ml-1">{{ getTeamDisplay(plan.inspectors_data, plan.inspector_name) }}</span>
            </div>

            <div class="grid grid-cols-2 gap-2 mt-4 pt-4 border-t border-slate-100">
              <button 
                @click="openMap(plan.businesses?.latitude, plan.businesses?.longitude)" 
                class="flex items-center justify-center py-1.5 px-2 text-xs font-bold rounded-lg border text-slate-700 bg-white border-slate-300 hover:bg-slate-50 transition-colors"
                :disabled="plan.status === 'cancelled'"
              >
                <MapPin class="w-3.5 h-3.5 mr-1.5" /> นำทาง
              </button>
              
              <button 
                @click="openAttendanceModal(plan)" 
                class="flex items-center justify-center py-1.5 px-2 text-xs font-bold rounded-lg border text-indigo-700 bg-indigo-50 border-indigo-200 hover:bg-indigo-100 transition-colors"
                :disabled="plan.status === 'cancelled'"
              >
                <ClipboardList class="w-3.5 h-3.5 mr-1.5" /> เช็คชื่อทีมตรวจ
              </button>
            </div>
            
            <div class="mt-2 space-y-2">
              <router-link 
                v-if="plan.status === 'planned' || plan.status === 'completed'"
                :to="`/inspection-record/${plan.id}`"
                class="w-full flex items-center justify-center py-1.5 px-2 text-xs font-bold rounded-lg border transition-colors"
                :class="plan.status === 'planned' ? 'text-green-700 bg-green-50 border-green-200 hover:bg-green-100' : 'text-indigo-700 bg-indigo-50 border-indigo-200 hover:bg-indigo-100'"
              >
                <CheckCircle v-if="plan.status === 'planned'" class="w-3.5 h-3.5 mr-1.5" /> 
                <FileText v-else class="w-3.5 h-3.5 mr-1.5" />
                {{ plan.status === 'planned' ? 'บันทึกผลการตรวจ (แบบละเอียด)' : 'ดู/แก้ไขรายงานผลการตรวจ' }}
              </router-link>
              <button 
                v-if="plan.status === 'completed'"
                @click="updatePlanStatus(plan.id, 'planned')" 
                class="w-full flex items-center justify-center py-1.5 px-2 text-xs font-bold rounded-lg border text-slate-600 bg-slate-50 border-slate-200 hover:bg-slate-100 transition-colors"
              >
                ยกเลิกสถานะตรวจแล้ว
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Modal 1: เพิ่มแผนจัดทีมตรวจ -->
    <div v-if="showModal" class="fixed inset-0 bg-slate-900/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
      <div class="bg-white rounded-2xl shadow-xl max-w-lg w-full overflow-hidden animate-fadeIn flex flex-col max-h-[90vh]">
        <div class="p-5 border-b border-slate-100 flex justify-between items-center bg-slate-50">
          <h3 class="text-lg font-bold text-slate-900 flex items-center">
            <UserPlus class="w-5 h-5 mr-2 text-primary-600" /> สร้างแผนและจัดทีมตรวจ
          </h3>
          <button @click="showModal = false" class="text-slate-400 hover:text-slate-600">
            <X class="w-5 h-5" />
          </button>
        </div>
        
        <div class="p-6 space-y-5 overflow-y-auto flex-1">
          <div>
            <label class="block text-sm font-medium text-slate-700 mb-1">วันที่ออกตรวจ</label>
            <div class="font-bold text-slate-900 bg-slate-100 px-3 py-2 rounded-lg border border-slate-200">
              {{ dayjs(selectedDate).format('D MMMM YYYY') }}
            </div>
          </div>
          
          <div>
            <label class="block text-sm font-medium text-slate-700 mb-1">1. ค้นหาสถานประกอบการเป้าหมาย <span class="text-red-500">*</span></label>
            <div class="relative mb-2">
              <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                <Search class="h-4 w-4 text-slate-400" />
              </div>
              <input 
                type="text" 
                v-model="searchQuery"
                class="form-input pl-10" 
                placeholder="พิมพ์ชื่อสถานประกอบการ..."
              />
            </div>
            
            <div class="max-h-40 overflow-y-auto border border-slate-200 rounded-lg">
              <div 
                v-for="b in filteredBusinesses" :key="b.id"
                @click="newPlan.business_id = b.id"
                :class="[
                  'px-3 py-2 text-sm cursor-pointer border-b border-slate-100 last:border-0 hover:bg-slate-50',
                  newPlan.business_id === b.id ? 'bg-primary-50 font-bold text-primary-700 border-l-4 border-l-primary-500' : 'text-slate-700 border-l-4 border-l-transparent'
                ]"
              >
                {{ b.business_name }} <span class="text-xs text-slate-400 ml-1">(อ.{{ b.district }})</span>
              </div>
              <div v-if="filteredBusinesses.length === 0" class="px-3 py-4 text-center text-sm text-slate-500">
                ไม่พบผลการค้นหา
              </div>
            </div>
          </div>

          <!-- Team Management -->
          <div class="pt-4 border-t border-slate-200">
            <div class="flex justify-between items-center mb-3">
              <label class="block text-sm font-medium text-slate-700">2. รายชื่อทีมตรวจ <span class="text-red-500">*</span></label>
              <button type="button" @click="addInspector" class="text-xs font-bold text-primary-600 bg-primary-50 hover:bg-primary-100 px-2 py-1 rounded-md flex items-center">
                <Plus class="w-3 h-3 mr-1" /> เพิ่มลูกทีม
              </button>
            </div>
            
            <div class="space-y-3">
              <div v-for="(inspector, index) in newPlan.inspectors" :key="index" class="flex items-center gap-2">
                <div class="w-24 text-xs font-bold flex-shrink-0" :class="index === 0 ? 'text-indigo-600' : 'text-slate-500'">
                  {{ index === 0 ? '👑 หัวหน้าทีม' : `👤 ลูกทีม ${index}` }}
                </div>
                <select 
                  v-model="inspector.name" 
                  class="form-input text-sm flex-1"
                >
                  <option value="" disabled selected>-- เลือกพนักงานเจ้าหน้าที่ --</option>
                  <option v-for="off in officers" :key="off.full_name" :value="off.full_name">
                    {{ off.full_name }} <span v-if="off.position">({{ off.position }})</span>
                  </option>
                </select>
                <button v-if="index !== 0" @click="removeInspector(index)" class="p-2 text-red-400 hover:text-red-600 bg-red-50 hover:bg-red-100 rounded-lg transition-colors">
                  <Trash2 class="w-4 h-4" />
                </button>
              </div>
            </div>
          </div>
        </div>

        <div class="p-4 border-t border-slate-100 bg-slate-50 flex justify-end space-x-3">
          <button @click="showModal = false" class="btn-secondary">ยกเลิก</button>
          <button @click="savePlan" class="btn-primary">บันทึกแผนงาน</button>
        </div>
      </div>
    </div>

    <!-- Modal 2: เช็คชื่อทีมตรวจ (Attendance) -->
    <div v-if="showAttendanceModal" class="fixed inset-0 bg-slate-900/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
      <div class="bg-white rounded-2xl shadow-xl max-w-2xl w-full overflow-hidden animate-fadeIn flex flex-col max-h-[90vh]">
        <div class="p-5 border-b border-slate-100 flex justify-between items-center bg-indigo-50">
          <h3 class="text-lg font-bold text-indigo-900 flex items-center">
            <CheckSquare class="w-5 h-5 mr-2 text-indigo-600" /> เช็คชื่อการเข้าปฏิบัติงาน
          </h3>
          <button @click="showAttendanceModal = false" class="text-slate-400 hover:text-slate-600">
            <X class="w-5 h-5" />
          </button>
        </div>
        
        <div class="p-6 overflow-y-auto flex-1 bg-slate-50/30">
          <div class="mb-6 pb-4 border-b border-slate-200">
            <h4 class="font-bold text-slate-800 text-lg">{{ selectedPlanForAttendance.businesses?.business_name }}</h4>
            <p class="text-sm text-slate-500">วันที่ตรวจ: {{ dayjs(selectedPlanForAttendance.planned_date).format('D MMMM YYYY') }}</p>
          </div>

          <div class="space-y-6">
            <div v-for="(inspector, index) in selectedPlanForAttendance.inspectors_data" :key="index" class="bg-white p-4 rounded-xl border border-slate-200 shadow-sm relative overflow-hidden">
              <!-- Role badge -->
              <div class="absolute top-0 right-0 px-3 py-1 text-[10px] font-bold tracking-wider uppercase rounded-bl-lg" :class="index === 0 ? 'bg-indigo-100 text-indigo-700' : 'bg-slate-100 text-slate-500'">
                {{ index === 0 ? 'Leader' : 'Member' }}
              </div>

              <div class="font-bold text-slate-800 text-base mb-3">{{ inspector.name || 'ไม่ระบุชื่อ' }}</div>
              
              <div class="flex flex-wrap gap-2 mb-4">
                <label class="cursor-pointer">
                  <input type="radio" v-model="inspector.attendance" value="pending" class="peer sr-only" :name="'att_'+index">
                  <div class="px-3 py-1.5 text-sm rounded-lg border border-slate-200 text-slate-500 peer-checked:bg-slate-100 peer-checked:border-slate-400 peer-checked:text-slate-800 peer-checked:font-bold transition-all">
                    ⚪ รอลงชื่อ
                  </div>
                </label>
                <label class="cursor-pointer">
                  <input type="radio" v-model="inspector.attendance" value="attended" class="peer sr-only" :name="'att_'+index">
                  <div class="px-3 py-1.5 text-sm rounded-lg border border-slate-200 text-slate-500 peer-checked:bg-green-50 peer-checked:border-green-500 peer-checked:text-green-700 peer-checked:font-bold transition-all">
                    🟢 มาตรวจปกติ
                  </div>
                </label>
                <label class="cursor-pointer">
                  <input type="radio" v-model="inspector.attendance" value="absent" class="peer sr-only" :name="'att_'+index">
                  <div class="px-3 py-1.5 text-sm rounded-lg border border-slate-200 text-slate-500 peer-checked:bg-red-50 peer-checked:border-red-500 peer-checked:text-red-700 peer-checked:font-bold transition-all">
                    🔴 ขาด/ลางาน
                  </div>
                </label>
                <label class="cursor-pointer">
                  <input type="radio" v-model="inspector.attendance" value="substituted" class="peer sr-only" :name="'att_'+index">
                  <div class="px-3 py-1.5 text-sm rounded-lg border border-slate-200 text-slate-500 peer-checked:bg-orange-50 peer-checked:border-orange-500 peer-checked:text-orange-700 peer-checked:font-bold transition-all">
                    🟡 มีผู้ตรวจแทน
                  </div>
                </label>
              </div>

              <!-- Conditional Fields -->
              <div v-if="inspector.attendance === 'absent'" class="mt-3 p-3 bg-red-50 rounded-lg border border-red-100 animate-fadeIn">
                <label class="block text-xs font-bold text-red-700 mb-1">สาเหตุที่ไม่ได้มาตรวจ <span class="text-red-500">*</span></label>
                <input type="text" v-model="inspector.reason" class="w-full text-sm p-2 border-red-200 rounded focus:ring-red-500 focus:border-red-500" placeholder="เช่น ติดประชุม, ลาป่วย..." />
              </div>

              <div v-if="inspector.attendance === 'substituted'" class="mt-3 p-3 bg-orange-50 rounded-lg border border-orange-100 animate-fadeIn space-y-3">
                <div>
                  <label class="block text-xs font-bold text-orange-700 mb-1">ชื่อผู้ที่มาตรวจแทน <span class="text-orange-500">*</span></label>
                  <input type="text" v-model="inspector.substitute_name" class="w-full text-sm p-2 border-orange-200 rounded focus:ring-orange-500 focus:border-orange-500" placeholder="ระบุชื่อเจ้าหน้าที่ผู้ตรวจแทน..." />
                </div>
                <div>
                  <label class="block text-xs font-bold text-orange-700 mb-1">สาเหตุที่มีการเปลี่ยนตัว</label>
                  <input type="text" v-model="inspector.reason" class="w-full text-sm p-2 border-orange-200 rounded focus:ring-orange-500 focus:border-orange-500" placeholder="ระบุสาเหตุ (ถ้ามี)..." />
                </div>
              </div>

            </div>
          </div>
        </div>

        <div class="p-4 border-t border-slate-100 bg-white flex justify-end space-x-3">
          <button @click="showAttendanceModal = false" class="btn-secondary">ปิด</button>
          <button @click="saveAttendance" class="btn-primary px-6">บันทึกข้อมูลเช็คชื่อ</button>
        </div>
      </div>
    </div>

  </div>
</template>

<style scoped>
.hide-scrollbar::-webkit-scrollbar {
  display: none;
}
.hide-scrollbar {
  -ms-overflow-style: none;
  scrollbar-width: none;
}
.animate-fadeIn {
  animation: fadeIn 0.2s ease-out forwards;
}
@keyframes fadeIn {
  from { opacity: 0; transform: translateY(-10px); }
  to { opacity: 1; transform: translateY(0); }
}
</style>
