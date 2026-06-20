<script setup>
import { ref, onMounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { supabase } from '../lib/supabase'
import Swal from 'sweetalert2'

const router = useRouter()
const route = useRoute()
const isEditing = route.params.id != null
const loading = ref(false)
const isSubmitting = ref(false)

const form = ref({
  business_type: 'คลินิก / สถานพยาบาล',
  business_name: '',
  license_no: '',
  licensee_name: '',
  operator_name: '',
  professional_license_no: '',
  address: '',
  subdistrict: '',
  district: 'ปลวกแดง',
  province: 'ระยอง',
  phone: '',
  opening_hours: '',
  latitude: '',
  longitude: '',
  expire_year: '',
  current_expire_year: '',
  risk_level: 'low',
  license_status: 'active',
  note: ''
})

const businessTypes = [
  'คลินิก / สถานพยาบาล',
  'ร้านขายยา',
  'สถานที่ผลิตอาหาร',
  'สถานที่ผลิตน้ำดื่ม',
  'ร้านชำ / ร้านค้าชุมชน',
  'สถานประกอบการอื่น ๆ'
]

onMounted(async () => {
  if (isEditing) {
    loading.value = true
    try {
      const { data, error } = await supabase
        .from('businesses')
        .select('*')
        .eq('id', route.params.id)
        .single()
        
      if (error) throw error
      if (data) {
        Object.assign(form.value, data)
      }
    } catch (error) {
      console.error(error)
      Swal.fire('ข้อผิดพลาด', 'ไม่สามารถโหลดข้อมูลกิจการได้', 'error')
    } finally {
      loading.value = false
    }
  }
})

const submitForm = async () => {
  isSubmitting.value = true
  try {
    const payload = { ...form.value }
    // Clean empty string to null for decimals
    if (!payload.latitude) payload.latitude = null
    if (!payload.longitude) payload.longitude = null

    if (isEditing) {
      const { error } = await supabase.from('businesses').update(payload).eq('id', route.params.id)
      if (error) throw error
      Swal.fire('สำเร็จ', 'อัปเดตข้อมูลกิจการเรียบร้อยแล้ว', 'success')
      router.push(`/businesses/${route.params.id}`)
    } else {
      const { data, error } = await supabase.from('businesses').insert([payload]).select().single()
      if (error) throw error
      Swal.fire('สำเร็จ', 'เพิ่มกิจการใหม่เข้าสู่ระบบเรียบร้อยแล้ว', 'success')
      router.push(`/businesses/${data.id}`)
    }
  } catch (error) {
    console.error(error)
    Swal.fire('ข้อผิดพลาด', error.message, 'error')
  } finally {
    isSubmitting.value = false
  }
}
</script>

<template>
  <div class="max-w-4xl mx-auto space-y-6 pb-12">
    <div class="flex items-center justify-between">
      <div>
        <h1 class="text-2xl font-bold text-slate-900">{{ isEditing ? 'แก้ไขข้อมูลกิจการ' : 'เพิ่มกิจการใหม่' }}</h1>
        <p class="text-sm text-slate-500 mt-1">กรอกข้อมูลรายละเอียดของสถานประกอบการให้ครบถ้วน</p>
      </div>
      <button @click="router.back()" class="btn-secondary">ยกเลิก / กลับ</button>
    </div>

    <div v-if="loading" class="text-center py-10 text-slate-500">
      กำลังโหลดข้อมูล...
    </div>

    <form v-else @submit.prevent="submitForm" class="space-y-6">
      
      <!-- Section 1: ข้อมูลหลัก -->
      <div class="card p-6 space-y-6">
        <h3 class="text-lg font-medium text-slate-900 border-b pb-2">ข้อมูลหลักและใบอนุญาต</h3>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div class="md:col-span-2">
            <label class="form-label">ชื่อกิจการ / สถานประกอบการ <span class="text-red-500">*</span></label>
            <input type="text" v-model="form.business_name" required class="form-input text-lg font-bold text-slate-900" placeholder="ระบุชื่อกิจการ..." />
          </div>
          <div>
            <label class="form-label">ประเภทกิจการ <span class="text-red-500">*</span></label>
            <select v-model="form.business_type" class="form-input">
              <option v-for="type in businessTypes" :key="type" :value="type">{{ type }}</option>
            </select>
          </div>
          <div>
            <label class="form-label">เลขที่ใบอนุญาต</label>
            <input type="text" v-model="form.license_no" class="form-input" placeholder="เช่น 12345/2567" />
          </div>
          <div>
            <label class="form-label">ชื่อผู้รับอนุญาต</label>
            <input type="text" v-model="form.licensee_name" class="form-input" placeholder="ชื่อบุคคล/นิติบุคคล ที่ได้รับอนุญาต" />
          </div>
          <div>
            <label class="form-label">ชื่อผู้ดำเนินการ (เช่น เภสัชกร, ผู้จัดการ)</label>
            <input type="text" v-model="form.operator_name" class="form-input" />
          </div>
          <div>
            <label class="form-label">เลขที่ใบประกอบวิชาชีพ (ถ้ามี)</label>
            <input type="text" v-model="form.professional_license_no" class="form-input" placeholder="สำหรับคลินิก หรือร้านยา" />
          </div>
          <div class="flex gap-4">
             <div class="flex-1">
               <label class="form-label">ปีที่หมดอายุเดิม</label>
               <input type="text" v-model="form.expire_year" class="form-input" placeholder="พ.ศ. (เช่น 2567)" />
             </div>
             <div class="flex-1">
               <label class="form-label">ปีที่หมดอายุปัจจุบัน</label>
               <input type="text" v-model="form.current_expire_year" class="form-input" placeholder="พ.ศ. (เช่น 2568)" />
             </div>
          </div>
        </div>
      </div>

      <!-- Section 2: ข้อมูลที่ตั้ง -->
      <div class="card p-6 space-y-6">
        <h3 class="text-lg font-medium text-slate-900 border-b pb-2">สถานที่ตั้งและการติดต่อ</h3>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div class="md:col-span-2">
            <label class="form-label">ที่อยู่ (เลขที่, หมู่, ซอย, ถนน)</label>
            <input type="text" v-model="form.address" class="form-input" />
          </div>
          <div>
            <label class="form-label">ตำบล</label>
            <input type="text" v-model="form.subdistrict" class="form-input" />
          </div>
          <div>
            <label class="form-label">อำเภอ</label>
            <input type="text" v-model="form.district" class="form-input" />
          </div>
          <div>
            <label class="form-label">เบอร์โทรศัพท์ติดต่อ</label>
            <input type="text" v-model="form.phone" class="form-input" />
          </div>
          <div>
            <label class="form-label">เวลาเปิดทำการ</label>
            <input type="text" v-model="form.opening_hours" class="form-input" placeholder="เช่น 08:00 - 20:00 น." />
          </div>
          <div>
            <label class="form-label">พิกัด Latitude</label>
            <input type="number" step="any" v-model="form.latitude" class="form-input" placeholder="เช่น 12.98123" />
          </div>
          <div>
            <label class="form-label">พิกัด Longitude</label>
            <input type="number" step="any" v-model="form.longitude" class="form-input" placeholder="เช่น 101.2131" />
          </div>
        </div>
      </div>

      <!-- Section 3: สถานะ -->
      <div class="card p-6 space-y-6 bg-slate-50">
        <h3 class="text-lg font-medium text-slate-900 border-b pb-2">สถานะและการบริหารจัดการ</h3>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div>
            <label class="form-label">สถานะใบอนุญาต</label>
            <select v-model="form.license_status" class="form-input">
              <option value="active">ปกติ (Active)</option>
              <option value="expired">หมดอายุ (Expired)</option>
              <option value="revoked">เพิกถอน/ยกเลิก (Revoked)</option>
            </select>
          </div>
          <div>
            <label class="form-label">ระดับความเสี่ยง</label>
            <select v-model="form.risk_level" class="form-input">
              <option value="low">ความเสี่ยงต่ำ (Low)</option>
              <option value="medium">ความเสี่ยงปานกลาง (Medium)</option>
              <option value="high">ความเสี่ยงสูง (High)</option>
            </select>
          </div>
          <div class="md:col-span-2">
            <label class="form-label">หมายเหตุเพิ่มเติม</label>
            <textarea v-model="form.note" rows="3" class="form-input"></textarea>
          </div>
        </div>
      </div>

      <div class="flex justify-end pt-4 space-x-4">
        <button type="button" @click="router.back()" class="btn-secondary">ยกเลิก</button>
        <button type="submit" :disabled="isSubmitting" class="btn-primary w-full sm:w-auto px-8 py-3 text-base font-bold shadow-md">
          <svg v-if="isSubmitting" class="animate-spin -ml-1 mr-2 h-5 w-5 text-white inline-block" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path></svg>
          {{ isSubmitting ? 'กำลังบันทึก...' : (isEditing ? 'บันทึกการเปลี่ยนแปลง' : 'ยืนยันเพิ่มกิจการใหม่') }}
        </button>
      </div>
    </form>
  </div>
</template>
