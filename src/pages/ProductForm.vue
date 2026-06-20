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
  product_type: 'อาหาร',
  product_name: '',
  registration_no: '',
  brand: '',
  manufacturer: '',
  expire_date: '',
  product_status: 'active',
  note: ''
})

const productTypes = ['อาหาร', 'น้ำดื่ม', 'ยา', 'เครื่องสำอาง', 'เครื่องมือแพทย์', 'อื่นๆ']
const statuses = [
  { value: 'active', label: 'ปกติ (Active)' },
  { value: 'recalled', label: 'เรียกคืน (Recalled)' },
  { value: 'expired', label: 'หมดอายุ (Expired)' }
]

onMounted(async () => {
  // Fetch businesses for the dropdown
  const { data } = await supabase.from('businesses').select('id, business_name').order('business_name')
  if (data) {
    businesses.value = data
  }
})

const submitForm = async () => {
  if (!form.value.business_id || !form.value.product_name) {
    Swal.fire('ข้อมูลไม่ครบ', 'กรุณาเลือกสถานประกอบการและกรอกชื่อผลิตภัณฑ์', 'warning')
    return
  }

  isSubmitting.value = true
  try {
    const { error } = await supabase.from('products').insert([
      {
        business_id: form.value.business_id,
        product_type: form.value.product_type,
        product_name: form.value.product_name,
        registration_no: form.value.registration_no || null,
        brand: form.value.brand || null,
        manufacturer: form.value.manufacturer || null,
        expire_date: form.value.expire_date || null,
        product_status: form.value.product_status,
        note: form.value.note || null
      }
    ])

    if (error) throw error

    Swal.fire({
      title: 'บันทึกสำเร็จ!',
      text: 'เพิ่มข้อมูลผลิตภัณฑ์เข้าสู่ระบบเรียบร้อยแล้ว',
      icon: 'success',
      confirmButtonColor: '#0d9488'
    }).then(() => {
      // Go back to business detail if came from there, else go to dashboard
      if (route.params.id || route.query.business_id) {
        router.push(`/businesses/${route.params.id || route.query.business_id}`)
      } else {
        router.push('/')
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
        <h1 class="text-2xl font-bold text-slate-900">เพิ่มผลิตภัณฑ์ / สินค้า</h1>
        <p class="text-sm text-slate-500 mt-1">บันทึกข้อมูลผลิตภัณฑ์ที่เกี่ยวข้องกับสถานประกอบการ</p>
      </div>
      <button @click="goBack" class="btn-secondary">กลับ</button>
    </div>

    <form @submit.prevent="submitForm" class="card p-6 space-y-6">
      
      <!-- Section 1: ข้อมูลหลัก -->
      <div>
        <h3 class="text-lg font-medium text-slate-900 mb-4 border-b pb-2">ข้อมูลหลัก</h3>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div class="md:col-span-2">
            <label class="form-label">สถานประกอบการ / ร้านค้า <span class="text-red-500">*</span></label>
            <select v-model="form.business_id" class="form-input" required>
              <option value="" disabled>-- เลือกสถานประกอบการ --</option>
              <option v-for="biz in businesses" :key="biz.id" :value="biz.id">
                {{ biz.business_name }}
              </option>
            </select>
          </div>

          <div>
            <label class="form-label">ประเภทผลิตภัณฑ์ <span class="text-red-500">*</span></label>
            <select v-model="form.product_type" class="form-input" required>
              <option v-for="pt in productTypes" :key="pt" :value="pt">{{ pt }}</option>
            </select>
          </div>

          <div>
            <label class="form-label">ชื่อผลิตภัณฑ์ <span class="text-red-500">*</span></label>
            <input v-model="form.product_name" type="text" class="form-input" placeholder="ระบุชื่อผลิตภัณฑ์" required />
          </div>

          <div>
            <label class="form-label">เลขที่จดแจ้ง / อย.</label>
            <input v-model="form.registration_no" type="text" class="form-input" placeholder="เช่น 10-1-xxxxxxx" />
          </div>

          <div>
            <label class="form-label">แบรนด์ / ยี่ห้อ</label>
            <input v-model="form.brand" type="text" class="form-input" placeholder="ระบุแบรนด์ (ถ้ามี)" />
          </div>
        </div>
      </div>

      <!-- Section 2: รายละเอียดการผลิต -->
      <div>
        <h3 class="text-lg font-medium text-slate-900 mb-4 border-b pb-2 mt-6">รายละเอียดการผลิตและสถานะ</h3>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div class="md:col-span-2">
            <label class="form-label">สถานที่ผลิต / ผู้ผลิต</label>
            <input v-model="form.manufacturer" type="text" class="form-input" placeholder="ระบุชื่อผู้ผลิตหรือโรงงาน" />
          </div>

          <div>
            <label class="form-label">วันหมดอายุ (Expire Date)</label>
            <input v-model="form.expire_date" type="date" class="form-input" />
          </div>

          <div>
            <label class="form-label">สถานะของผลิตภัณฑ์</label>
            <select v-model="form.product_status" class="form-input">
              <option v-for="s in statuses" :key="s.value" :value="s.value">{{ s.label }}</option>
            </select>
          </div>

          <div class="md:col-span-2">
            <label class="form-label">หมายเหตุเพิ่มเติม</label>
            <textarea v-model="form.note" rows="3" class="form-input" placeholder="ระบุรายละเอียดเพิ่มเติม หรือข้อควรระวัง..."></textarea>
          </div>
        </div>
      </div>

      <div class="pt-4 flex justify-end space-x-3">
        <button type="button" @click="goBack" class="btn-secondary">ยกเลิก</button>
        <button type="submit" class="btn-primary flex items-center" :disabled="isSubmitting">
          <svg v-if="isSubmitting" class="animate-spin -ml-1 mr-2 h-4 w-4 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path></svg>
          บันทึกผลิตภัณฑ์
        </button>
      </div>

    </form>
  </div>
</template>
