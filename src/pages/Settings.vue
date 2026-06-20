<script setup>
import { ref, onMounted } from 'vue'
import { supabase } from '../lib/supabase'
import * as XLSX from 'xlsx'
import Swal from 'sweetalert2'
import { useAuthStore } from '../stores/auth'
import { storeToRefs } from 'pinia'

const authStore = useAuthStore()
const { isAdmin } = storeToRefs(authStore)

const activeTab = ref('mapper')

// --- Smart Mapper Logic ---
const importLoading = ref(false)
const progressText = ref('')
const progressPercent = ref(0)
const fileInput = ref(null)
const importSummary = ref(null)

const handleFileChange = async (e) => {
  const file = e.target.files[0]
  if (!file) return

  Swal.fire({
    title: 'นำเข้าข้อมูล Smart Mapper?',
    text: `ระบบจะทำการอ่านทุกชีต (Sheet) ในไฟล์ Excel ทันที และจะอัปเดตข้อมูลทับของเดิมหากพบเลขใบอนุญาตหรือชื่อกิจการที่ตรงกัน`,
    icon: 'warning',
    showCancelButton: true,
    confirmButtonColor: '#0d9488',
    cancelButtonColor: '#d33',
    confirmButtonText: 'เริ่มนำเข้าข้อมูล',
    cancelButtonText: 'ยกเลิก'
  }).then(async (result) => {
    if (result.isConfirmed) {
      await processSmartExcel(file)
    } else {
      fileInput.value.value = ''
    }
  })
}

const sheetConfig = {
  'สถานพยาบาล': {
    type: 'คลินิก / สถานพยาบาล',
    map: (row) => ({
      business_name: String(row['name'] || '').trim(),
      license_no: String(row['รหัสคลินิก'] || '').trim(),
      old_license_no: String(row['รหัสคลินิกเดิม'] || '').trim(),
      licensee_name: String(row['ผู้รับอนุญาต'] || '').trim(),
      operator_name: String(row['ผู้ดำเนินการ'] || '').trim(),
      professional_license_no: String(row['เลขที่ใบประกอบวิชาชีพ'] || '').trim(),
      address: String(row['ที่อยู่'] || '').trim(),
      subdistrict: String(row['ตำบล'] || '').trim(),
      district: String(row['อำเภอ'] || 'เมืองระยอง').trim(),
      phone: String(row['โทรศัพท์ติดต่อ'] || '').trim(),
      opening_hours: String(row['เวลาเปิดทำการ'] || '').trim(),
      waste_management: String(row['แหล่งกำจัดขยะติดเชื้อ'] || '').trim(),
      expire_year: String(row['วันที่หมดอายุ'] || '').trim(),
      current_expire_year: String(row['วันที่หมดอายุปัจจุบัน'] || '').trim(),
      note: String(row['ข้อเพิ่มเติม'] || '').trim(),
      medical_equipment: String(row['เครื่องมือแพทย์หรือกิจกรรมที่เพิ่มเติม'] || '').trim(),
      image_front: String(row['รูปคลินิก'] || '').trim(),
      image_inside_1: String(row['รูปภายในคลินิก'] || '').trim(),
      image_inside_2: String(row['รูปภายในคลินิก2'] || '').trim(),
      image_specific: String(row['รูปในห้องตรวจ'] || '').trim(),
      latlon: String(row['พิกัดคลินิก'] || '')
    })
  },
  'น้ำบริโภค': {
    type: 'สถานที่ผลิตน้ำดื่ม',
    map: (row) => ({
      business_name: String(row['ชื่อสถานประกอบการ'] || '').trim(),
      license_no: String(row['เลขสถานที่'] || '').trim(),
      operator_name: String(row['ผู้ดำเนินกิจการ'] || '').trim(),
      address: [row['เลขที่'], row['หมู่'] ? 'ม.'+row['หมู่'] : '', row['ซอย'] ? 'ซ.'+row['ซอย'] : '', row['ถนน'] ? 'ถ.'+row['ถนน'] : ''].filter(Boolean).join(' '),
      subdistrict: String(row['ตำบล'] || '').trim(),
      district: String(row['อำเภอ'] || '').trim(),
      phone: String(row['เบอร์โทรศัพท์'] || '').trim(),
      note: String(row['หมายเหตุ'] || '').trim(),
      medical_equipment: String(row['อาหารที่ผลิต'] || '').trim(),
      image_front: String(row['รูปหน้าสถานที่ผลิต'] || '').trim(),
      image_inside_1: String(row['รูปภายใน1'] || '').trim(),
      image_inside_2: String(row['รูปภายใน2'] || '').trim(),
      image_specific: String(row['รูปภายนอกรอบอาคาร'] || '').trim(),
      latlon: String(row['พิกัด'] || '')
    })
  },
  'สถานที่อาหาร': {
    type: 'สถานที่ผลิตอาหาร',
    map: (row) => ({
      business_name: String(row['ชื่อสถานประกอบการ'] || '').trim(),
      license_no: String(row['เลขสถานที่'] || '').trim(),
      operator_name: String(row['ผู้ดำเนินกิจการ'] || '').trim(),
      address: [row['เลขที่'], row['หมู่'] ? 'ม.'+row['หมู่'] : '', row['ซอย'] ? 'ซ.'+row['ซอย'] : '', row['ถนน'] ? 'ถ.'+row['ถนน'] : ''].filter(Boolean).join(' '),
      subdistrict: String(row['ตำบล'] || '').trim(),
      district: String(row['อำเภอ'] || '').trim(),
      phone: String(row['เบอร์โทรศัพท์'] || '').trim(),
      note: String(row['หมายเหต'] || row['หมายเหตุ'] || '').trim(),
      medical_equipment: String(row['อาหารที่ผลิต'] || '').trim(),
      image_front: String(row['รูปหน้าที่ผลิต'] || '').trim(),
      image_inside_1: String(row['รูปภายในสถานที่ผลิต1'] || '').trim(),
      image_inside_2: String(row['รูปภายในสถานที่ผลิต2'] || '').trim(),
      image_specific: String(row['รูปบริเวณโดยรอบ'] || '').trim(),
      latlon: String(row['พิกัด'] || '')
    })
  },
  'ร้านขายยา': {
    type: 'ร้านขายยา',
    map: (row) => ({
      business_name: String(row['ชื่อสถานประกอบการ'] || '').trim(),
      license_no: String(row['ใบอนุญาตเลขที่'] || '').trim(),
      address: String(row['ที่อยู่'] || '').trim(),
      opening_hours: String(row['เวลาปฏิบัติการ'] || '').trim(),
      operator_name: String(row['ชื่อผู้มีหน้าที่ปฏิบัติการ'] || '').trim(),
      licensee_name: String(row['ชื่อผู้ดำเนินการ'] || '').trim(),
      image_front: String(row['รูปหน้าร้าน'] || '').trim(),
      image_inside_1: String(row['รูป1'] || '').trim(),
      image_inside_2: String(row['รูป2'] || '').trim(),
      image_specific: String(row['รูป3'] || '').trim(), 
      latlon: String(row['ที่ตั้ง'] || '').includes(',') ? String(row['ที่ตั้ง']) : '',
      note: String(row['บันทึกขณะตรวจ'] || '').trim()
    })
  },
  'GRDU': {
    type: 'ร้านชำ / ร้านค้าชุมชน',
    map: (row) => ({
      business_name: String(row['company'] || '').trim(),
      license_no: String(row['customer_cid'] || '').trim(),
      licensee_name: String(row['customer'] || '').trim(),
      address: [row['addr'], row['moo'] ? 'ม.'+row['moo'] : '', row['moobaan'] ? 'หมู่บ้าน '+row['moobaan'] : ''].filter(Boolean).join(' '),
      subdistrict: String(row['tmppart'] || '').trim(),
      district: String(row['amppart'] || '').trim(),
      province: String(row['chwpart'] || '').trim(),
      phone: String(row['tel'] || '').trim(),
      image_front: String(row['image'] || '').trim(),
      image_inside_1: String(row['image1'] || '').trim(),
      image_inside_2: String(row['image2'] || '').trim(),
      latlon: String(row['พิกัด'] || row['map'] || '')
    })
  }
}

const processSmartExcel = async (file) => {
  importLoading.value = true
  progressPercent.value = 0
  importSummary.value = null
  let summary = { sheetsParsed: 0, rowsSuccess: 0, rowsFailed: 0, skipped: 0 }

  try {
    progressText.value = 'กำลังอ่านไฟล์ Excel...'
    const data = await file.arrayBuffer()
    const workbook = XLSX.read(data)
    
    let totalRows = 0;
    for (const sheetName of workbook.SheetNames) {
      if (sheetConfig[sheetName]) {
        const rows = XLSX.utils.sheet_to_json(workbook.Sheets[sheetName])
        totalRows += rows.length
      }
    }
    
    if (totalRows === 0) throw new Error("ไม่พบข้อมูล หรือชื่อชีตไม่ตรงกับระบบที่ตั้งค่าไว้")
    
    let processedRows = 0;

    for (const sheetName of workbook.SheetNames) {
      const config = sheetConfig[sheetName]
      if (!config) continue 
      
      summary.sheetsParsed++
      progressText.value = `กำลังประมวลผลชีต: ${sheetName}`
      
      const rows = XLSX.utils.sheet_to_json(workbook.Sheets[sheetName])
      
      for (const row of rows) {
        processedRows++
        progressPercent.value = Math.floor((processedRows / totalRows) * 100)
        
        try {
          const mapped = config.map(row)
          
          if (!mapped.business_name && !mapped.license_no) {
            summary.skipped++
            continue
          }

          const payload = {
            business_type: config.type,
            business_name: mapped.business_name,
            license_no: mapped.license_no,
            old_license_no: mapped.old_license_no || null,
            licensee_name: mapped.licensee_name || null,
            operator_name: mapped.operator_name || null,
            professional_license_no: mapped.professional_license_no || null,
            address: mapped.address || null,
            subdistrict: mapped.subdistrict || null,
            district: mapped.district || null,
            province: mapped.province || 'ระยอง',
            phone: mapped.phone || null,
            opening_hours: mapped.opening_hours || null,
            waste_management: mapped.waste_management || null,
            expire_year: mapped.expire_year || null,
            current_expire_year: mapped.current_expire_year || null,
            note: mapped.note || null,
            medical_equipment: mapped.medical_equipment || null,
            image_front: mapped.image_front || null,
            image_inside_1: mapped.image_inside_1 || null,
            image_inside_2: mapped.image_inside_2 || null,
            image_specific: mapped.image_specific || null
          }

          if (mapped.latlon && mapped.latlon.includes(',')) {
            const parts = mapped.latlon.split(',')
            payload.latitude = parseFloat(parts[0].trim()) || null
            payload.longitude = parseFloat(parts[1].trim()) || null
          }

          let existing = null;
          if (payload.license_no) {
            const { data: ex1, error: err1 } = await supabase.from('businesses').select('id').eq('license_no', payload.license_no).maybeSingle()
            if (err1) throw err1
            existing = ex1
          } 
          if (!existing && payload.business_name) {
            const { data: ex2, error: err2 } = await supabase.from('businesses').select('id').eq('business_name', payload.business_name).maybeSingle()
            if (err2) throw err2
            existing = ex2
          }

          if (existing) {
            const { error: updErr } = await supabase.from('businesses').update(payload).eq('id', existing.id)
            if (updErr) throw updErr
          } else {
            const { error: insErr } = await supabase.from('businesses').insert([payload])
            if (insErr) throw insErr
          }
          
          summary.rowsSuccess++
        } catch (err) {
          console.error("Row error:", err)
          summary.rowsFailed++
        }
      }
    }

    importSummary.value = summary
    Swal.fire({
      title: 'นำเข้าข้อมูล Smart Mapper เสร็จสิ้น!',
      html: `
        <div class="text-left mt-4 text-sm space-y-2">
          <p>✅ อัปเดต/นำเข้าสำเร็จ: <b>${summary.rowsSuccess}</b> รายการ</p>
          <p>❌ ผิดพลาด: <b>${summary.rowsFailed}</b> รายการ</p>
          <p>⏭️ ข้าม (ข้อมูลว่าง): <b>${summary.skipped}</b> รายการ</p>
          <p>📄 จำนวนชีตที่อ่านได้: <b>${summary.sheetsParsed}</b> ชีต</p>
        </div>
      `,
      icon: 'success',
      confirmButtonColor: '#0d9488'
    })

  } catch (error) {
    Swal.fire('ข้อผิดพลาด', error.message, 'error')
  } finally {
    importLoading.value = false
    progressText.value = ''
    fileInput.value.value = ''
  }
}

// --- Admin: Business Types Logic ---
const businessTypes = ref([])
const newTypeName = ref('')

const fetchBusinessTypes = async () => {
  const { data } = await supabase.from('business_types').select('*').order('type_name')
  if (data) businessTypes.value = data
}

onMounted(() => {
  if (isAdmin.value) {
    fetchBusinessTypes()
  }
})

</script>

<template>
  <div class="space-y-6 max-w-5xl mx-auto">
    <h1 class="text-2xl font-semibold text-slate-900">ตั้งค่าระบบ (Settings)</h1>
    
    <!-- Admin Warning if not admin -->
    <div v-if="!isAdmin" class="bg-red-50 text-red-700 p-4 rounded-lg border border-red-200">
      <p class="font-bold">❌ ไม่มีสิทธิ์เข้าถึง</p>
      <p class="text-sm">หน้านี้สงวนไว้สำหรับผู้ดูแลระบบ (สสจ.ระยอง) เท่านั้นครับ</p>
    </div>

    <!-- Tabs for Admin -->
    <div v-if="isAdmin">
      <div class="border-b border-slate-200 mb-6">
        <nav class="-mb-px flex space-x-8">
          <button @click="activeTab = 'mapper'" :class="[activeTab === 'mapper' ? 'border-primary-500 text-primary-600' : 'border-transparent text-slate-500 hover:text-slate-700 hover:border-slate-300', 'whitespace-nowrap pb-4 px-1 border-b-2 font-medium text-sm']">
            Smart Mapper (นำเข้าข้อมูล)
          </button>
          <button @click="activeTab = 'types'" :class="[activeTab === 'types' ? 'border-primary-500 text-primary-600' : 'border-transparent text-slate-500 hover:text-slate-700 hover:border-slate-300', 'whitespace-nowrap pb-4 px-1 border-b-2 font-medium text-sm']">
            จัดการประเภทกิจการ/งาน
          </button>
        </nav>
      </div>

      <!-- Tab: Smart Mapper -->
      <div v-show="activeTab === 'mapper'" class="card p-6 border border-slate-200 shadow-sm relative overflow-hidden">
        <div class="absolute top-0 right-0 -mt-4 -mr-4 w-24 h-24 bg-primary-50 rounded-full blur-2xl opacity-50"></div>
        <div class="flex items-center space-x-3 mb-4 relative">
          <div class="bg-gradient-to-br from-primary-500 to-teal-400 text-white p-2 rounded-lg shadow-sm">
            <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m21.64 3.64-1.28-1.28a1.21 1.21 0 0 0-1.72 0L2.36 18.64a1.21 1.21 0 0 0 0 1.72l1.28 1.28a1.2 1.2 0 0 0 1.72 0L21.64 5.36a1.2 1.2 0 0 0 0-1.72Z"/><path d="m14 7 3 3"/><path d="M5 6v4"/><path d="M19 14v4"/><path d="M10 2v2"/><path d="M7 8H3"/><path d="M21 16h-4"/><path d="M11 3H9"/></svg>
          </div>
          <h3 class="text-lg leading-6 font-bold text-slate-900">ระบบ Smart Mapper (นำเข้าทุกชีตอัตโนมัติ)</h3>
        </div>
        <p class="text-sm text-slate-500 mb-6 relative">เพียงอัปโหลดไฟล์ <code>clinicpdh.xlsx</code> ระบบจะดึงข้อมูลจากทุกชีตอัตโนมัติ</p>
        <div class="space-y-4 relative">
          <div class="bg-white border-2 border-dashed border-slate-300 rounded-lg p-8 text-center hover:bg-slate-50 transition-colors">
            <label class="block text-sm font-medium text-slate-700 mb-2">เลือกไฟล์ Excel ของคุณ</label>
            <input type="file" accept=".xlsx, .xls" class="block w-full text-sm text-slate-500 file:mr-4 file:py-2.5 file:px-4 file:rounded-md file:border-0 file:text-sm file:font-semibold file:bg-primary-50 file:text-primary-700 hover:file:bg-primary-100 cursor-pointer mx-auto max-w-xs" @change="handleFileChange" ref="fileInput" :disabled="importLoading" />
          </div>
          <div v-if="importLoading" class="mt-6 p-5 bg-white rounded-xl shadow-sm border border-slate-200">
            <div class="flex items-center justify-between text-sm font-medium text-slate-700 mb-3">
              <span class="flex items-center">{{ progressText }}</span>
              <span class="text-primary-600 font-bold">{{ progressPercent }}%</span>
            </div>
            <div class="w-full bg-slate-100 rounded-full h-3 overflow-hidden">
              <div class="bg-gradient-to-r from-teal-400 to-primary-600 h-3 rounded-full transition-all duration-300 ease-out" :style="{ width: progressPercent + '%' }"></div>
            </div>
          </div>
        </div>
      </div>

      <!-- Tab: Business Types -->
      <div v-show="activeTab === 'types'" class="card p-6 border border-slate-200 shadow-sm">
        <h3 class="text-lg leading-6 font-bold text-slate-900 mb-4">จัดการประเภทกิจการ/งาน</h3>
        
        <div class="flex space-x-2 mb-6">
          <input v-model="newTypeName" @keyup.enter="addBusinessType" type="text" placeholder="เช่น งาน otop, งานเครื่องสำอาง..." class="form-input flex-1" />
          <button @click="addBusinessType" class="btn-primary">เพิ่มประเภท</button>
        </div>

        <div class="bg-white border border-slate-200 rounded-lg overflow-hidden">
          <table class="min-w-full divide-y divide-slate-200">
            <thead class="bg-slate-50">
              <tr>
                <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-slate-500 uppercase tracking-wider">ชื่อประเภทงาน</th>
                <th scope="col" class="px-6 py-3 text-right text-xs font-medium text-slate-500 uppercase tracking-wider">จัดการ</th>
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-slate-200">
              <tr v-for="t in businessTypes" :key="t.id">
                <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-slate-900">{{ t.type_name }}</td>
                <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                  <button @click="deleteBusinessType(t.id)" class="text-red-600 hover:text-red-900">ลบ</button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

    </div>
  </div>
</template>
