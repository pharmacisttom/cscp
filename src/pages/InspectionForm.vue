<script setup>
import { ref, onMounted, computed } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { supabase } from '../lib/supabase'
import Swal from 'sweetalert2'

const router = useRouter()
const route = useRoute()
const businessId = route.params.id
const goBack = () => router.back()

const loading = ref(false)
const business = ref(null)

const baseForm = ref({
  inspection_date: new Date().toISOString().split('T')[0],
  inspector_name: '',
  inspection_result: 'passed',
  score: 100,
  problem_found: '',
  recommendation: '',
  next_followup_date: '',
  attachment_url: '',
  is_confidential: false
})

// Dynamic Form Data (Stored as JSONB in DB)
const dynamicData = ref({
  inspection_images: ['', '', '', '', '']
})

onMounted(async () => {
  loading.value = true
  try {
    const { data, error } = await supabase
      .from('businesses')
      .select('id, business_name, business_type')
      .eq('id', businessId)
      .single()
      
    if (error) throw error
    business.value = data
    
    // Initialize default fields based on business type
    if (data.business_type === 'คลินิก / สถานพยาบาล') {
      dynamicData.value = {
        inspection_images: ['', '', '', '', ''],
        has_medical_equipment_checked: false,
        is_patient_record_updated: false,
        cleanliness_score: 5
      }
    } else if (data.business_type === 'ร้านขายยา') {
      dynamicData.value = {
        inspection_images: ['', '', '', '', ''],
        pharmacist_present: false,
        fridge_temperature: 4,
        separated_expired_drugs: false
      }
    } else if (data.business_type.includes('สถานที่ผลิตอาหาร')) {
      dynamicData.value = {
        inspection_images: ['', '', '', '', ''],
        staff_hygiene_passed: false,
        pest_control_active: false,
        water_quality_test_passed: false
      }
    } else {
      dynamicData.value = {
        inspection_images: ['', '', '', '', ''],
        general_safety_passed: false,
        cleanliness_passed: false
      }
    }

  } catch (error) {
    console.error('Error fetching business:', error)
    // Mock for UI demonstration
    business.value = {
      id: businessId,
      business_name: 'คลินิกทดสอบ',
      business_type: 'คลินิก / สถานพยาบาล'
    }
    dynamicData.value = {
      inspection_images: ['', '', '', '', ''],
      has_medical_equipment_checked: false,
      is_patient_record_updated: false,
      cleanliness_score: 5
    }
  } finally {
    loading.value = false
  }
})

const handleSubmit = async () => {
  loading.value = true
  try {
    const { data: userData } = await supabase.auth.getUser()
    const userId = userData?.user?.id || null

    const payload = {
      business_id: businessId,
      inspection_date: baseForm.value.inspection_date,
      inspector_name: baseForm.value.inspector_name,
      inspection_result: baseForm.value.inspection_result,
      score: baseForm.value.score,
      problem_found: baseForm.value.problem_found,
      recommendation: baseForm.value.recommendation,
      next_followup_date: baseForm.value.next_followup_date || null,
      attachment_url: baseForm.value.attachment_url || null,
      is_confidential: baseForm.value.is_confidential,
      created_by: userId,
      form_data: dynamicData.value // Save the entire dynamic object as JSONB
    }

    const { error } = await supabase.from('inspections').insert([payload])
    
    if (error) throw error
    
    Swal.fire('สำเร็จ', 'บันทึกข้อมูลการตรวจประเมินเรียบร้อย', 'success')
    router.back()
  } catch (error) {
    Swal.fire('ข้อผิดพลาด', error.message, 'error')
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <div class="max-w-4xl mx-auto space-y-6 pb-10">
    <div class="flex items-center justify-between">
      <h1 class="text-2xl font-semibold text-slate-900">บันทึกการตรวจประเมิน</h1>
      <button @click="goBack" class="text-slate-500 hover:text-slate-700">กลับ</button>
    </div>

    <div v-if="loading" class="text-center py-10 text-slate-500">
      กำลังโหลดข้อมูล...
    </div>
    
    <div v-else-if="business">
      <div class="bg-blue-50 text-blue-800 p-4 rounded-md mb-6 border border-blue-100">
        <p class="font-medium">สถานประกอบการ: {{ business.business_name }}</p>
        <p class="text-sm">ประเภท: {{ business.business_type }}</p>
      </div>

      <form @submit.prevent="handleSubmit" class="space-y-6">
        
        <!-- ส่วนที่ 1: ข้อมูลการตรวจพื้นฐาน -->
        <div class="card p-4 sm:p-6 space-y-6">
          <h3 class="text-lg font-medium text-slate-900 border-b pb-2">ข้อมูลการตรวจพื้นฐาน (ตารางหลัก)</h3>
          
          <div class="grid grid-cols-1 gap-6 sm:grid-cols-2">
            <div>
              <label class="form-label">วันที่ตรวจประเมิน <span class="text-red-500">*</span></label>
              <input type="date" v-model="baseForm.inspection_date" required class="form-input" />
            </div>
            <div>
              <label class="form-label">ชื่อผู้ตรวจประเมิน <span class="text-red-500">*</span></label>
              <input type="text" v-model="baseForm.inspector_name" required class="form-input" />
            </div>
            <div>
              <label class="form-label">ผลการประเมินเบื้องต้น</label>
              <select v-model="baseForm.inspection_result" class="form-input">
                <option value="passed">ผ่านเกณฑ์</option>
                <option value="requires_improvement">ต้องปรับปรุง (มีข้อบกพร่อง)</option>
                <option value="failed">ไม่ผ่านเกณฑ์ (พักใช้ใบอนุญาต)</option>
              </select>
            </div>
            <div>
              <label class="form-label">คะแนนรวม (%)</label>
              <input type="number" v-model="baseForm.score" class="form-input" />
            </div>
          </div>
        </div>

        <!-- ส่วนที่ 2: แบบฟอร์มเฉพาะกิจการ (Dynamic Form) -->
        <div class="card p-4 sm:p-6 space-y-6 bg-slate-50">
          <h3 class="text-lg font-medium text-slate-900 border-b pb-2 text-primary-700">แบบฟอร์มประเมินสำหรับ: {{ business.business_type }}</h3>
          <p class="text-sm text-slate-500 mb-4">ส่วนนี้ถูกสร้างขึ้นแบบ Dynamic และจะถูกจัดเก็บในฟิลด์ <code>form_data (JSONB)</code></p>
          
          <!-- ฟอร์มสำหรับ คลินิก -->
          <div v-if="business.business_type === 'คลินิก / สถานพยาบาล'" class="space-y-4">
            <div class="flex items-center">
              <input type="checkbox" id="med_equip" v-model="dynamicData.has_medical_equipment_checked" class="h-4 w-4 text-primary-600 border-slate-300 rounded" />
              <label for="med_equip" class="ml-2 block text-sm text-slate-900">ตรวจสอบความพร้อมของเครื่องมือแพทย์ (เครื่องมือฉุกเฉิน, เครื่องช่วยหายใจ)</label>
            </div>
            <div class="flex items-center">
              <input type="checkbox" id="patient_rec" v-model="dynamicData.is_patient_record_updated" class="h-4 w-4 text-primary-600 border-slate-300 rounded" />
              <label for="patient_rec" class="ml-2 block text-sm text-slate-900">ระบบเวชระเบียนผู้ป่วยครบถ้วนสมบูรณ์</label>
            </div>
            <div>
              <label class="form-label">ระดับความสะอาดของคลินิก (1-5)</label>
              <input type="number" min="1" max="5" v-model="dynamicData.cleanliness_score" class="form-input w-32" />
            </div>
          </div>

          <!-- ฟอร์มสำหรับ ร้านขายยา -->
          <div v-else-if="business.business_type === 'ร้านขายยา'" class="space-y-4">
            <div class="flex items-center">
              <input type="checkbox" id="phar_present" v-model="dynamicData.pharmacist_present" class="h-4 w-4 text-primary-600 border-slate-300 rounded" />
              <label for="phar_present" class="ml-2 block text-sm text-slate-900">มีเภสัชกรประจำ ณ เวลาที่ตรวจ</label>
            </div>
            <div class="flex items-center">
              <input type="checkbox" id="sep_drugs" v-model="dynamicData.separated_expired_drugs" class="h-4 w-4 text-primary-600 border-slate-300 rounded" />
              <label for="sep_drugs" class="ml-2 block text-sm text-slate-900">มีการแยกเก็บยาหมดอายุชัดเจน</label>
            </div>
            <div>
              <label class="form-label">อุณหภูมิตู้เย็นแช่ยา (°C)</label>
              <input type="number" step="0.1" v-model="dynamicData.fridge_temperature" class="form-input w-32" />
            </div>
          </div>

          <!-- ฟอร์มสำหรับ สถานที่ผลิตอาหาร -->
          <div v-else-if="business.business_type.includes('สถานที่ผลิตอาหาร')" class="space-y-4">
            <div class="flex items-center">
              <input type="checkbox" id="staff_hygiene" v-model="dynamicData.staff_hygiene_passed" class="h-4 w-4 text-primary-600 border-slate-300 rounded" />
              <label for="staff_hygiene" class="ml-2 block text-sm text-slate-900">พนักงานสวมหมวกคลุมผม และแต่งกายถูกสุขลักษณะ</label>
            </div>
            <div class="flex items-center">
              <input type="checkbox" id="pest_control" v-model="dynamicData.pest_control_active" class="h-4 w-4 text-primary-600 border-slate-300 rounded" />
              <label for="pest_control" class="ml-2 block text-sm text-slate-900">มีมาตรการป้องกันสัตว์พาหะนำโรค</label>
            </div>
            <div class="flex items-center">
              <input type="checkbox" id="water_qual" v-model="dynamicData.water_quality_test_passed" class="h-4 w-4 text-primary-600 border-slate-300 rounded" />
              <label for="water_qual" class="ml-2 block text-sm text-slate-900">ผลตรวจคุณภาพน้ำผ่านเกณฑ์มาตรฐาน</label>
            </div>
          </div>
          
          <!-- ฟอร์ม Default -->
          <div v-else class="space-y-4">
            <div class="flex items-center">
              <input type="checkbox" id="gen_safety" v-model="dynamicData.general_safety_passed" class="h-4 w-4 text-primary-600 border-slate-300 rounded" />
              <label for="gen_safety" class="ml-2 block text-sm text-slate-900">ความปลอดภัยทั่วไปผ่านเกณฑ์</label>
            </div>
            <div class="flex items-center">
              <input type="checkbox" id="gen_clean" v-model="dynamicData.cleanliness_passed" class="h-4 w-4 text-primary-600 border-slate-300 rounded" />
              <label for="gen_clean" class="ml-2 block text-sm text-slate-900">ความสะอาดบริเวณโดยรอบผ่านเกณฑ์</label>
            </div>
          </div>

        </div>

        <!-- ส่วนที่ 3: สรุปผล -->
        <div class="card p-4 sm:p-6 space-y-6 border-l-4 border-l-primary-500">
          <h3 class="text-lg font-medium text-slate-900 border-b pb-2">สรุปผลและข้อเสนอแนะ</h3>
          <div class="grid grid-cols-1 gap-6">
            <div>
              <label class="form-label">สรุปข้อบกพร่องที่พบ (ถ้ามี)</label>
              <textarea v-model="baseForm.problem_found" rows="3" class="form-input"></textarea>
            </div>
            <div>
              <label class="form-label">คำแนะนำ / สิ่งที่ต้องปรับปรุง</label>
              <textarea v-model="baseForm.recommendation" rows="3" class="form-input"></textarea>
            </div>
            <div class="sm:w-1/2">
              <label class="form-label">กำหนดการตรวจติดตามครั้งต่อไป (ถ้ามี)</label>
              <input type="date" v-model="baseForm.next_followup_date" class="form-input" />
            </div>
          </div>
        </div>

        <!-- ส่วนที่ 4: ไฟล์แนบและสิทธิ์การเข้าถึง -->
        <div class="card p-4 sm:p-6 space-y-6">
          <h3 class="text-lg font-medium text-slate-900 border-b pb-2">เอกสารแนบและสิทธิ์การเข้าถึง</h3>
          <div class="space-y-4">
            <div>
              <label class="form-label">ลิงก์ไฟล์ PDF (Google Drive หรือระบบฝากไฟล์อื่นๆ)</label>
              <input type="url" v-model="baseForm.attachment_url" class="form-input" placeholder="https://drive.google.com/..." />
              <p class="text-xs text-red-500 mt-1">* เอกสาร PDF ควรมีจำนวนไม่เกิน 20 หน้า</p>
            </div>
            
            <div class="border-t border-slate-100 pt-4 mt-4">
               <label class="form-label mb-2 block">ลิงก์รูปภาพจากการตรวจ (สูงสุด 5 รูป)</label>
               <div class="space-y-3">
                 <input v-for="(img, idx) in 5" :key="idx" type="url" v-model="dynamicData.inspection_images[idx]" class="form-input text-sm" :placeholder="`ลิงก์รูปภาพที่ ${idx + 1} (Google Drive URL)`" />
               </div>
               <p class="text-xs text-slate-500 mt-2 bg-slate-50 p-2 rounded border border-slate-200">
                 💡 <b>ข้อแนะนำ:</b> สามารถแนบรูปภาพได้สูงสุด 5 รูปเท่านั้น หากต้องการแนบรูปภาพเพิ่มเติม กรุณานำรูปภาพเหล่านั้นไปรวบรวมใส่ในไฟล์ PDF แล้วแนบในช่อง PDF ด้านบนแทนครับ
               </p>
            </div>

            <div class="flex items-center p-4 bg-yellow-50 rounded-lg border border-yellow-200 mt-4">
              <input type="checkbox" id="confidential" v-model="baseForm.is_confidential" class="h-5 w-5 text-yellow-600 border-yellow-400 rounded focus:ring-yellow-500" />
              <label for="confidential" class="ml-3 block text-sm font-medium text-yellow-900 cursor-pointer">
                ทำเครื่องหมายเป็น "ไฟล์ปกปิดความลับ (Confidential)" 
                <span class="block text-xs font-normal text-yellow-700 mt-1">เฉพาะผู้บันทึกข้อมูลนี้และผู้ดูแลระบบ (Admin) เท่านั้นที่จะสามารถดูไฟล์และรายละเอียดได้ ผู้อื่นจะเห็นแค่ประวัติการตรวจเบื้องต้น</span>
              </label>
            </div>
          </div>
        </div>

        <div class="flex justify-end pt-4">
          <button type="submit" :disabled="loading" class="btn-primary w-full sm:w-auto px-8 py-3 text-base">
            {{ loading ? 'กำลังบันทึก...' : 'บันทึกผลการประเมิน' }}
          </button>
        </div>
      </form>
    </div>
  </div>
</template>
