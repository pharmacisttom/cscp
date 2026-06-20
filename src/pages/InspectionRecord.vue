<script setup>
import { ref, onMounted, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase } from '../lib/supabase'
import { Printer, Save, ArrowLeft, Building2, Calendar, Users, AlertTriangle, FileText, CheckCircle } from 'lucide-vue-next'
import Swal from 'sweetalert2'
import dayjs from 'dayjs'
import 'dayjs/locale/th'
import buddhistEra from 'dayjs/plugin/buddhistEra'

dayjs.extend(buddhistEra)
dayjs.locale('th')

const route = useRoute()
const router = useRouter()
const planId = route.params.id

const loading = ref(true)
const saving = ref(false)
const isPrintMode = ref(false)

const plan = ref(null)
const business = ref(null)

// Form State
const formData = ref({
  inspection_date: dayjs().format('YYYY-MM-DD'),
  inspection_result: 'passed',
  score: 100,
  risk_level: 'low',
  problem_found: '',
  recommendation: '',
  next_followup_date: '',
  is_confidential: false
})

const existingRecord = ref(false)

const loadData = async () => {
  try {
    loading.value = true
    // Fetch plan & business
    const { data: planData, error: planError } = await supabase
      .from('inspection_plans')
      .select('*, businesses(*)')
      .eq('id', planId)
      .single()
    
    if (planError) throw planError
    if (!planData) throw new Error('ไม่พบแผนการตรวจนี้')

    plan.value = planData
    business.value = planData.businesses

    // Check if an inspection record already exists for this plan (we can store plan_id in form_data)
    const { data: insData, error: insError } = await supabase
      .from('inspections')
      .select('*')
      .eq('business_id', business.value.id)
      .contains('form_data', { plan_id: planId })
      .maybeSingle()

    if (insData) {
      existingRecord.value = true
      formData.value = {
        inspection_date: insData.inspection_date,
        inspection_result: insData.inspection_result || 'passed',
        score: insData.score || 100,
        risk_level: insData.risk_level || 'low',
        problem_found: insData.problem_found || '',
        recommendation: insData.recommendation || '',
        next_followup_date: insData.next_followup_date || '',
        is_confidential: insData.is_confidential || false
      }
    } else {
      formData.value.inspection_date = planData.planned_date
    }

  } catch (error) {
    console.error(error)
    Swal.fire('ข้อผิดพลาด', error.message, 'error')
    router.push('/calendar')
  } finally {
    loading.value = false
  }
}

onMounted(() => {
  loadData()
})

const saveRecord = async () => {
  try {
    saving.value = true
    
    // Extract head inspector
    let inspectorName = ''
    if (plan.value.inspectors_data && plan.value.inspectors_data.length > 0) {
      const head = plan.value.inspectors_data.find(i => i.is_head)
      if (head) inspectorName = head.name
      else inspectorName = plan.value.inspectors_data[0].name
    }

    const payload = {
      business_id: business.value.id,
      inspection_date: formData.value.inspection_date,
      inspection_type: 'ตรวจตามแผนประจำปี',
      inspector_name: inspectorName,
      inspection_result: formData.value.inspection_result,
      score: formData.value.score,
      risk_level: formData.value.risk_level,
      problem_found: formData.value.problem_found,
      recommendation: formData.value.recommendation,
      next_followup_date: formData.value.next_followup_date || null,
      is_confidential: formData.value.is_confidential,
      form_data: { plan_id: planId }
    }

    if (existingRecord.value) {
      // Update existing
      const { error } = await supabase
        .from('inspections')
        .update(payload)
        .eq('business_id', business.value.id)
        .contains('form_data', { plan_id: planId })
      if (error) throw error
    } else {
      // Insert new
      const { error } = await supabase.from('inspections').insert([payload])
      if (error) throw error
      
      // Update plan status to completed
      await supabase.from('inspection_plans').update({ status: 'completed' }).eq('id', planId)
      existingRecord.value = true
    }

    Swal.fire({
      icon: 'success',
      title: 'บันทึกข้อมูลสำเร็จ',
      showConfirmButton: false,
      timer: 1500
    })

  } catch (error) {
    console.error(error)
    Swal.fire('ข้อผิดพลาด', error.message, 'error')
  } finally {
    saving.value = false
  }
}

const printReport = () => {
  window.print()
}

const formatDate = (dateStr) => {
  if (!dateStr) return '-'
  return dayjs(dateStr).format('D MMMM BBBB')
}

// Format Inspectors
const formatInspectors = computed(() => {
  if (!plan.value?.inspectors_data) return '-'
  const attending = plan.value.inspectors_data.filter(i => i.attended)
  if (attending.length === 0) return 'ไม่มีผู้มาปฏิบัติงาน'
  return attending.map(i => `${i.name} ${i.is_head ? '(หัวหน้าชุด)' : ''}`).join(', ')
})
</script>

<template>
  <div v-if="loading" class="flex justify-center items-center py-20">
    <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-600"></div>
  </div>

  <div v-else class="print:m-0 print:p-0 max-w-4xl mx-auto space-y-6 pb-12 print:text-black">
    
    <!-- Action Bar (Hidden in Print) -->
    <div class="print:hidden flex flex-col sm:flex-row justify-between items-center bg-white p-4 rounded-xl shadow-sm border border-slate-200">
      <button @click="router.push('/calendar')" class="text-slate-500 hover:text-slate-800 flex items-center font-medium">
        <ArrowLeft class="w-4 h-4 mr-1" />
        กลับปฏิทิน
      </button>
      
      <div class="flex gap-3 mt-4 sm:mt-0">
        <button @click="printReport" class="btn bg-slate-100 hover:bg-slate-200 text-slate-700 flex items-center px-4 py-2 rounded-lg font-bold transition-colors">
          <Printer class="w-4 h-4 mr-2" />
          พิมพ์รายงาน (PDF)
        </button>
        <button @click="saveRecord" :disabled="saving" class="btn-primary flex items-center px-6 py-2">
          <Save class="w-4 h-4 mr-2" />
          {{ saving ? 'กำลังบันทึก...' : 'บันทึกผลการตรวจ' }}
        </button>
      </div>
    </div>

    <!-- Official Report Form / Printable Area -->
    <div class="bg-white rounded-xl shadow-sm border border-slate-200 p-8 sm:p-12 print:shadow-none print:border-none print:p-0">
      
      <!-- Report Header -->
      <div class="text-center mb-10 border-b border-slate-200 pb-8 print:border-b-2 print:border-black">
        <img src="https://upload.wikimedia.org/wikipedia/commons/e/e0/Thai_government_Garuda_emblem_%28Version_2%29.svg" alt="ครุฑ" class="h-24 mx-auto mb-4 grayscale" />
        <h1 class="text-2xl font-extrabold text-slate-900 print:text-black mb-2">แบบบันทึกผลการตรวจสถานประกอบการ</h1>
        <p class="text-slate-600 print:text-black">ระบบงานคุ้มครองผู้บริโภคด้านผลิตภัณฑ์สุขภาพ (CSCP)</p>
      </div>

      <!-- Business Info Section -->
      <div class="mb-8 space-y-4">
        <h2 class="text-lg font-bold flex items-center text-slate-800 print:text-black border-l-4 border-primary-500 pl-3">
          <Building2 class="w-5 h-5 mr-2 text-primary-500 print:hidden" />
          ข้อมูลสถานประกอบการ
        </h2>
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4 bg-slate-50 print:bg-transparent p-5 rounded-lg border border-slate-100 print:border-none print:p-0">
          <div>
            <span class="block text-sm text-slate-500 print:text-gray-600">ชื่อกิจการ</span>
            <span class="font-bold text-slate-800 print:text-black">{{ business?.business_name }}</span>
          </div>
          <div>
            <span class="block text-sm text-slate-500 print:text-gray-600">ประเภท</span>
            <span class="font-bold text-slate-800 print:text-black">{{ business?.business_type }}</span>
          </div>
          <div>
            <span class="block text-sm text-slate-500 print:text-gray-600">เลขที่ใบอนุญาต</span>
            <span class="font-bold text-slate-800 print:text-black">{{ business?.license_no || '-' }}</span>
          </div>
          <div>
            <span class="block text-sm text-slate-500 print:text-gray-600">ผู้ดำเนินกิจการ</span>
            <span class="font-bold text-slate-800 print:text-black">{{ business?.operator_name || business?.licensee_name || '-' }}</span>
          </div>
          <div class="sm:col-span-2">
            <span class="block text-sm text-slate-500 print:text-gray-600">ที่ตั้ง</span>
            <span class="font-bold text-slate-800 print:text-black">{{ business?.address }} {{ business?.subdistrict }} {{ business?.district }} จ.{{ business?.province }}</span>
          </div>
        </div>
      </div>

      <!-- Inspection Details Section -->
      <div class="mb-8 space-y-4">
        <h2 class="text-lg font-bold flex items-center text-slate-800 print:text-black border-l-4 border-indigo-500 pl-3">
          <Calendar class="w-5 h-5 mr-2 text-indigo-500 print:hidden" />
          ข้อมูลการเข้าตรวจ
        </h2>
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div>
            <label class="block text-sm font-bold text-slate-700 print:text-black mb-1">วันที่เข้าตรวจจริง <span class="text-red-500 print:hidden">*</span></label>
            <input type="date" v-model="formData.inspection_date" class="form-input print:hidden" required />
            <span class="hidden print:block font-bold">{{ formatDate(formData.inspection_date) }}</span>
          </div>
          <div>
            <label class="block text-sm font-bold text-slate-700 print:text-black mb-1">คณะผู้ตรวจประเมิน</label>
            <div class="p-2 bg-slate-50 print:bg-transparent rounded-md text-sm border border-slate-200 print:border-none print:p-0 font-medium">
              {{ formatInspectors }}
            </div>
          </div>
        </div>
      </div>

      <!-- Results Section -->
      <div class="mb-8 space-y-6">
        <h2 class="text-lg font-bold flex items-center text-slate-800 print:text-black border-l-4 border-green-500 pl-3">
          <CheckCircle class="w-5 h-5 mr-2 text-green-500 print:hidden" />
          ผลการตรวจประเมิน
        </h2>
        
        <div class="grid grid-cols-1 sm:grid-cols-3 gap-6">
          <div class="sm:col-span-2">
            <label class="block text-sm font-bold text-slate-700 print:text-black mb-2">สรุปผลการตรวจ <span class="text-red-500 print:hidden">*</span></label>
            <div class="flex gap-4 print:hidden">
              <label class="flex items-center">
                <input type="radio" v-model="formData.inspection_result" value="passed" class="text-green-600 focus:ring-green-500 w-4 h-4" />
                <span class="ml-2 font-medium text-slate-700">✅ ผ่านเกณฑ์</span>
              </label>
              <label class="flex items-center">
                <input type="radio" v-model="formData.inspection_result" value="requires_improvement" class="text-amber-600 focus:ring-amber-500 w-4 h-4" />
                <span class="ml-2 font-medium text-slate-700">⚠️ ต้องปรับปรุง</span>
              </label>
              <label class="flex items-center">
                <input type="radio" v-model="formData.inspection_result" value="failed" class="text-red-600 focus:ring-red-500 w-4 h-4" />
                <span class="ml-2 font-medium text-slate-700">❌ ไม่ผ่านเกณฑ์ / ดำเนินคดี</span>
              </label>
            </div>
            <!-- Print version of result -->
            <div class="hidden print:block font-bold text-lg">
              <span v-if="formData.inspection_result === 'passed'">[ ✓ ] ผ่านเกณฑ์มาตรฐาน</span>
              <span v-if="formData.inspection_result === 'requires_improvement'">[ ✓ ] ต้องปรับปรุงแก้ไข</span>
              <span v-if="formData.inspection_result === 'failed'">[ ✓ ] ไม่ผ่านเกณฑ์ / ดำเนินการตามกฎหมาย</span>
            </div>
          </div>

          <div>
            <label class="block text-sm font-bold text-slate-700 print:text-black mb-1">คะแนนประเมิน (เต็ม 100)</label>
            <input type="number" v-model="formData.score" class="form-input print:hidden" />
            <span class="hidden print:block font-bold text-xl">{{ formData.score }} คะแนน</span>
          </div>
        </div>

        <div>
          <label class="block text-sm font-bold text-slate-700 print:text-black mb-1">ข้อบกพร่องที่พบ (ถ้ามี)</label>
          <textarea v-model="formData.problem_found" rows="3" class="form-input print:hidden" placeholder="ระบุรายละเอียดสิ่งที่ตรวจพบว่าไม่ถูกต้อง..."></textarea>
          <div class="hidden print:block min-h-[60px] p-3 border border-gray-300 rounded whitespace-pre-wrap">
            {{ formData.problem_found || '-' }}
          </div>
        </div>

        <div>
          <label class="block text-sm font-bold text-slate-700 print:text-black mb-1">ข้อเสนอแนะ / คำสั่งให้แก้ไข</label>
          <textarea v-model="formData.recommendation" rows="3" class="form-input print:hidden" placeholder="ระบุสิ่งที่ให้ผู้ประกอบการดำเนินการแก้ไข..."></textarea>
          <div class="hidden print:block min-h-[60px] p-3 border border-gray-300 rounded whitespace-pre-wrap">
            {{ formData.recommendation || '-' }}
          </div>
        </div>

        <div class="grid grid-cols-1 sm:grid-cols-2 gap-6">
          <div>
            <label class="block text-sm font-bold text-slate-700 print:text-black mb-1">วันที่นัดตรวจติดตาม (Follow-up)</label>
            <input type="date" v-model="formData.next_followup_date" class="form-input print:hidden" />
            <span class="hidden print:block font-bold">{{ formatDate(formData.next_followup_date) }}</span>
          </div>
          <div>
            <label class="block text-sm font-bold text-slate-700 print:text-black mb-1">ระดับความเสี่ยง</label>
            <select v-model="formData.risk_level" class="form-input print:hidden">
              <option value="low">ความเสี่ยงต่ำ (Low)</option>
              <option value="medium">ความเสี่ยงปานกลาง (Medium)</option>
              <option value="high">ความเสี่ยงสูง (High)</option>
            </select>
            <span class="hidden print:block font-bold">
              {{ formData.risk_level === 'low' ? 'ต่ำ' : formData.risk_level === 'medium' ? 'ปานกลาง' : 'สูง' }}
            </span>
          </div>
        </div>
      </div>

      <!-- Signature Section (For Print Only) -->
      <div class="hidden print:block mt-24">
        <div class="grid grid-cols-2 gap-10">
          <div class="text-center">
            <p class="mb-16">(ลงชื่อ)........................................................ผู้รับการตรวจ</p>
            <p>(........................................................)</p>
            <p class="mt-2">ตำแหน่ง ผู้รับอนุญาต / ผู้ดำเนินกิจการ</p>
          </div>
          <div class="text-center">
            <p class="mb-16">(ลงชื่อ)........................................................ผู้ตรวจประเมิน</p>
            <p>(........................................................)</p>
            <p class="mt-2">ตำแหน่ง พนักงานเจ้าหน้าที่</p>
          </div>
        </div>
      </div>

    </div>
  </div>
</template>
