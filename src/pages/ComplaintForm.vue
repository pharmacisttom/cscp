<script setup>
import { ref, onMounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { supabase } from '../lib/supabase'
import Swal from 'sweetalert2'

const router = useRouter()
const route = useRoute()
const goBack = () => router.back()

const isSubmitting = ref(false)
const businesses = ref([])

const form = ref({
  business_id: route.params.id || route.query.business_id || '',
  complaint_date: new Date().toISOString().split('T')[0],
  complainant_name: '',
  complaint_topic: '',
  complaint_detail: '',
  status: 'open',
  action_taken: '',
  close_date: ''
})

const statuses = [
  { value: 'open', label: 'เปิดเรื่อง (Open)' },
  { value: 'investigating', label: 'กำลังตรวจสอบ (Investigating)' },
  { value: 'resolved', label: 'แก้ไขแล้ว (Resolved)' },
  { value: 'closed', label: 'ยุติเรื่อง (Closed)' }
]

onMounted(async () => {
  const { data } = await supabase.from('businesses').select('id, business_name').order('business_name')
  if (data) {
    businesses.value = data
  }
})

const submitForm = async () => {
  if (!form.value.business_id || !form.value.complaint_topic) {
    Swal.fire('ข้อมูลไม่ครบ', 'กรุณาเลือกสถานประกอบการและระบุหัวข้อเรื่องร้องเรียน', 'warning')
    return
  }

  isSubmitting.value = true
  try {
    const { error } = await supabase.from('complaints').insert([
      {
        business_id: form.value.business_id,
        complaint_date: form.value.complaint_date,
        complainant_name: form.value.complainant_name || null,
        complaint_topic: form.value.complaint_topic,
        complaint_detail: form.value.complaint_detail || null,
        status: form.value.status,
        action_taken: form.value.action_taken || null,
        close_date: form.value.status === 'closed' || form.value.status === 'resolved' ? (form.value.close_date || new Date().toISOString().split('T')[0]) : null
      }
    ])

    if (error) throw error

    Swal.fire({
      title: 'บันทึกสำเร็จ!',
      text: 'บันทึกข้อมูลเรื่องร้องเรียนเข้าสู่ระบบเรียบร้อยแล้ว',
      icon: 'success',
      confirmButtonColor: '#0d9488'
    }).then(() => {
      if (route.params.id || route.query.business_id) {
        router.push(`/businesses/${route.params.id || route.query.business_id}`)
      } else {
        router.push('/complaints')
      }
    })
  } catch (error) {
    console.error(error)
    Swal.fire('เกิดข้อผิดพลาด', error.message, 'error')
  } finally {
    isSubmitting.value = false
  }
}
</script>

<template>
  <div class="max-w-3xl mx-auto space-y-6 pb-12">
    <div class="flex items-center justify-between">
      <div>
        <h1 class="text-2xl font-bold text-slate-900">รับเรื่องร้องเรียน</h1>
        <p class="text-sm text-slate-500 mt-1">บันทึกข้อมูลและติดตามสถานะเรื่องร้องเรียน</p>
      </div>
      <button @click="goBack" class="btn-secondary">กลับ</button>
    </div>

    <form @submit.prevent="submitForm" class="card p-6 space-y-6">
      
      <!-- Section 1: ข้อมูลหลัก -->
      <div>
        <h3 class="text-lg font-medium text-slate-900 mb-4 border-b pb-2">ข้อมูลผู้ร้องเรียนและสถานประกอบการ</h3>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div class="md:col-span-2">
            <label class="form-label">สถานประกอบการที่ถูกร้องเรียน <span class="text-red-500">*</span></label>
            <select v-model="form.business_id" class="form-input" required>
              <option value="" disabled>-- เลือกสถานประกอบการ --</option>
              <option v-for="biz in businesses" :key="biz.id" :value="biz.id">
                {{ biz.business_name }}
              </option>
            </select>
          </div>

          <div>
            <label class="form-label">วันที่รับเรื่อง <span class="text-red-500">*</span></label>
            <input v-model="form.complaint_date" type="date" class="form-input" required />
          </div>

          <div>
            <label class="form-label">ชื่อผู้ร้องเรียน</label>
            <input v-model="form.complainant_name" type="text" class="form-input" placeholder="ระบุชื่อ (หรือ ปิดบังชื่อ)" />
          </div>
        </div>
      </div>

      <!-- Section 2: รายละเอียดการร้องเรียน -->
      <div>
        <h3 class="text-lg font-medium text-slate-900 mb-4 border-b pb-2 mt-6">รายละเอียดข้อร้องเรียน</h3>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div class="md:col-span-2">
            <label class="form-label">หัวข้อเรื่องร้องเรียน <span class="text-red-500">*</span></label>
            <input v-model="form.complaint_topic" type="text" class="form-input" placeholder="เช่น อาหารไม่ได้มาตรฐาน, ร้านยาไม่มีเภสัชกร" required />
          </div>

          <div class="md:col-span-2">
            <label class="form-label">รายละเอียดของปัญหา</label>
            <textarea v-model="form.complaint_detail" rows="4" class="form-input" placeholder="อธิบายรายละเอียดสิ่งที่พบเจอ..."></textarea>
          </div>
        </div>
      </div>

      <!-- Section 3: การติดตามผล -->
      <div class="bg-slate-50 p-4 rounded-lg border border-slate-200 mt-6">
        <h3 class="text-md font-medium text-slate-900 mb-4 border-b pb-2">สถานะและการติดตามผล</h3>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div>
            <label class="form-label">สถานะเรื่องร้องเรียน</label>
            <select v-model="form.status" class="form-input">
              <option v-for="s in statuses" :key="s.value" :value="s.value">{{ s.label }}</option>
            </select>
          </div>

          <div v-if="form.status === 'closed' || form.status === 'resolved'">
            <label class="form-label">วันที่ปิดเรื่อง</label>
            <input v-model="form.close_date" type="date" class="form-input" />
          </div>

          <div class="md:col-span-2">
            <label class="form-label">การดำเนินการแก้ไข (Action Taken)</label>
            <textarea v-model="form.action_taken" rows="2" class="form-input" placeholder="ระบุสิ่งเจ้าหน้าที่ได้ดำเนินการแก้ไข..."></textarea>
          </div>
        </div>
      </div>

      <div class="pt-4 flex justify-end space-x-3">
        <button type="button" @click="goBack" class="btn-secondary">ยกเลิก</button>
        <button type="submit" class="btn-primary flex items-center" :disabled="isSubmitting">
          <svg v-if="isSubmitting" class="animate-spin -ml-1 mr-2 h-4 w-4 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path></svg>
          บันทึกเรื่องร้องเรียน
        </button>
      </div>

    </form>
  </div>
</template>
