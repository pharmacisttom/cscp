<script setup>
import { ref, onMounted } from 'vue'
import { supabase } from '../lib/supabase'
import * as XLSX from 'xlsx'
import Swal from 'sweetalert2'
import { Download, Palette } from 'lucide-vue-next'
import { useAuthStore } from '../stores/auth'
import { useThemeStore } from '../stores/theme'
import { storeToRefs } from 'pinia'

const authStore = useAuthStore()
const { isAdmin, userDistrict, user, profile } = storeToRefs(authStore)
const themeStore = useThemeStore()

const activeTab = ref('theme')

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

const downloadTemplate = () => {
  const wb = XLSX.utils.book_new()
  
  const sheets = [
    { name: 'สถานพยาบาล', headers: ['name', 'รหัสคลินิก', 'รหัสคลินิกเดิม', 'ผู้รับอนุญาต', 'ผู้ดำเนินการ', 'เลขที่ใบประกอบวิชาชีพ', 'ที่อยู่', 'ตำบล', 'อำเภอ', 'โทรศัพท์ติดต่อ', 'เวลาเปิดทำการ', 'แหล่งกำจัดขยะติดเชื้อ', 'วันที่หมดอายุ', 'วันที่หมดอายุปัจจุบัน', 'ข้อเพิ่มเติม', 'เครื่องมือแพทย์หรือกิจกรรมที่เพิ่มเติม', 'รูปคลินิก', 'รูปภายในคลินิก', 'รูปภายในคลินิก2', 'รูปในห้องตรวจ', 'พิกัดคลินิก'] },
    { name: 'น้ำบริโภค', headers: ['ชื่อสถานประกอบการ', 'เลขสถานที่', 'ผู้ดำเนินกิจการ', 'เลขที่', 'หมู่', 'ซอย', 'ถนน', 'ตำบล', 'อำเภอ', 'เบอร์โทรศัพท์', 'หมายเหตุ', 'อาหารที่ผลิต', 'รูปหน้าสถานที่ผลิต', 'รูปภายใน1', 'รูปภายใน2', 'รูปภายนอกรอบอาคาร', 'พิกัด'] },
    { name: 'สถานที่อาหาร', headers: ['ชื่อสถานประกอบการ', 'เลขสถานที่', 'ผู้ดำเนินกิจการ', 'เลขที่', 'หมู่', 'ซอย', 'ถนน', 'ตำบล', 'อำเภอ', 'เบอร์โทรศัพท์', 'หมายเหตุ', 'อาหารที่ผลิต', 'รูปหน้าที่ผลิต', 'รูปภายในสถานที่ผลิต1', 'รูปภายในสถานที่ผลิต2', 'รูปบริเวณโดยรอบ', 'พิกัด'] },
    { name: 'ร้านขายยา', headers: ['ชื่อสถานประกอบการ', 'ใบอนุญาตเลขที่', 'ที่อยู่', 'เวลาปฏิบัติการ', 'ชื่อผู้มีหน้าที่ปฏิบัติการ', 'ชื่อผู้ดำเนินการ', 'รูปหน้าร้าน', 'รูป1', 'รูป2', 'รูป3', 'ที่ตั้ง', 'บันทึกขณะตรวจ'] },
    { name: 'GRDU', headers: ['company', 'customer_cid', 'customer', 'addr', 'moo', 'moobaan', 'tmppart', 'amppart', 'chwpart', 'tel', 'image', 'image1', 'image2', 'พิกัด'] }
  ]
  
  sheets.forEach(s => {
    const ws = XLSX.utils.aoa_to_sheet([s.headers])
    ws['!cols'] = s.headers.map(() => ({wch: 15}))
    XLSX.utils.book_append_sheet(wb, ws, s.name)
  })

  XLSX.writeFile(wb, "cscp.xlsx")
}

const defaultDistrict = ref('ปลวกแดง')

const importHistories = ref([])

const fetchImportHistory = async () => {
  try {
    let query = supabase.from('import_history').select('*').order('created_at', { ascending: false })
    
    if (!isAdmin.value) {
      if (userDistrict.value) {
        query = query.eq('district', userDistrict.value)
      } else if (user.value) {
        query = query.eq('uploader_id', user.value.id)
      }
    }
    
    const { data, error } = await query
    if (error) throw error
    importHistories.value = data || []
  } catch (error) {
    console.error("Error fetching import history", error)
  }
}

const arrayBufferToBase64 = (buffer) => {
  let binary = '';
  const bytes = new Uint8Array(buffer);
  const len = bytes.byteLength;
  for (let i = 0; i < len; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return window.btoa(binary);
};

const downloadBase64File = (base64Data, fileName) => {
  const linkSource = `data:application/vnd.openxmlformats-officedocument.spreadsheetml.sheet;base64,${base64Data}`;
  const downloadLink = document.createElement("a");
  downloadLink.href = linkSource;
  downloadLink.download = fileName;
  downloadLink.click();
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
      district: String(row['อำเภอ'] || defaultDistrict.value).trim(),
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
      district: String(row['อำเภอ'] || defaultDistrict.value).trim(),
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
      district: String(row['อำเภอ'] || defaultDistrict.value).trim(),
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
      note: String(row['บันทึกขณะตรวจ'] || '').trim(),
      district: defaultDistrict.value
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
      district: String(row['amppart'] || defaultDistrict.value).trim(),
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

    // Save to import_history
    try {
      const base64Content = arrayBufferToBase64(data)
      const { error: histErr } = await supabase.from('import_history').insert([{
        file_name: file.name,
        file_content_base64: base64Content,
        summary: summary,
        uploader_id: user.value?.id,
        uploader_email: profile.value?.email || user.value?.email,
        district: isAdmin.value ? 'สสจ.' : userDistrict.value
      }])
      if (histErr) console.error("Error saving import history", histErr)
      fetchImportHistory()
    } catch(e) {
      console.error("Error processing base64", e)
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

const addBusinessType = async () => {
  if (!newTypeName.value.trim()) return
  try {
    const { error } = await supabase.from('business_types').insert([{ type_name: newTypeName.value.trim() }])
    if (error) throw error
    Swal.fire({ icon: 'success', title: 'เพิ่มประเภทสำเร็จ', showConfirmButton: false, timer: 1500 })
    newTypeName.value = ''
    fetchBusinessTypes()
  } catch (err) {
    console.error(err)
    Swal.fire('ข้อผิดพลาด', err.message, 'error')
  }
}

const deleteBusinessType = async (id) => {
  const result = await Swal.fire({
    title: 'ยืนยันการลบ',
    text: "คุณต้องการลบประเภทกิจการนี้ใช่หรือไม่?",
    icon: 'warning',
    showCancelButton: true,
    confirmButtonColor: '#d33',
    cancelButtonColor: '#3085d6',
    confirmButtonText: 'ใช่, ลบเลย'
  })
  
  if (result.isConfirmed) {
    try {
      const { error } = await supabase.from('business_types').delete().eq('id', id)
      if (error) throw error
      Swal.fire('ลบแล้ว', '', 'success')
      fetchBusinessTypes()
    } catch (err) {
      console.error(err)
      Swal.fire('ข้อผิดพลาด', err.message, 'error')
    }
  }
}

onMounted(() => {
  fetchImportHistory()
  if (isAdmin.value) {
    fetchBusinessTypes()
  } else if (userDistrict.value) {
    defaultDistrict.value = userDistrict.value
  }
})

</script>

<template>
  <div class="space-y-6 max-w-5xl mx-auto">
    <h1 class="text-2xl font-semibold text-slate-900">ตั้งค่าระบบ (Settings)</h1>
    
    <!-- Tabs for Everyone -->
    <div class="border-b border-slate-200 mb-6">
      <nav class="-mb-px flex space-x-8">
        <button @click="activeTab = 'theme'" :class="[activeTab === 'theme' ? 'border-primary-500 text-primary-600' : 'border-transparent text-slate-500 hover:text-slate-700 hover:border-slate-300', 'whitespace-nowrap pb-4 px-1 border-b-2 font-medium text-sm flex items-center']">
          <Palette class="w-4 h-4 mr-2" /> ตั้งค่ารูปลักษณ์ (Theme)
        </button>
        <button @click="activeTab = 'mapper'" :class="[activeTab === 'mapper' ? 'border-primary-500 text-primary-600' : 'border-transparent text-slate-500 hover:text-slate-700 hover:border-slate-300', 'whitespace-nowrap pb-4 px-1 border-b-2 font-medium text-sm']">
          Smart Mapper (นำเข้าข้อมูล)
        </button>
        <button v-if="isAdmin" @click="activeTab = 'types'" :class="[activeTab === 'types' ? 'border-primary-500 text-primary-600' : 'border-transparent text-slate-500 hover:text-slate-700 hover:border-slate-300', 'whitespace-nowrap pb-4 px-1 border-b-2 font-medium text-sm']">
          จัดการประเภทกิจการ/งาน
        </button>
      </nav>
    </div>

    <!-- Tab: Theme Settings (For Everyone) -->
    <div v-show="activeTab === 'theme'" class="card p-6 border border-slate-200 shadow-sm">
      <h3 class="text-lg leading-6 font-bold text-slate-900 mb-4">เลือกธีมสีของระบบ</h3>
      <p class="text-sm text-slate-500 mb-6">ปรับแต่งสีสันของแอปพลิเคชันให้เข้ากับความชอบของคุณ (บันทึกอัตโนมัติเฉพาะเครื่องนี้)</p>
      
      <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
        
        <!-- Medical Green -->
        <div 
          @click="themeStore.setTheme('medical')"
          :class="['cursor-pointer rounded-2xl border-2 transition-all p-4', themeStore.currentTheme === 'medical' ? 'border-teal-500 bg-teal-50' : 'border-slate-200 hover:border-teal-300']"
        >
          <div class="h-20 rounded-xl bg-gradient-to-r from-teal-400 to-teal-600 mb-3 shadow-inner"></div>
          <h4 class="font-bold text-teal-900 text-center">Medical Green (ค่าเริ่มต้น)</h4>
          <p class="text-xs text-teal-700 text-center mt-1">สะอาด สบายตา ปลอดภัย</p>
        </div>

        <!-- Ocean Blue -->
        <div 
          @click="themeStore.setTheme('ocean')"
          :class="['cursor-pointer rounded-2xl border-2 transition-all p-4', themeStore.currentTheme === 'ocean' ? 'border-indigo-500 bg-indigo-50' : 'border-slate-200 hover:border-indigo-300']"
        >
          <div class="h-20 rounded-xl bg-gradient-to-r from-indigo-400 to-indigo-600 mb-3 shadow-inner"></div>
          <h4 class="font-bold text-indigo-900 text-center">Ocean Blue</h4>
          <p class="text-xs text-indigo-700 text-center mt-1">สุขุม เป็นทางการ น่าเชื่อถือ</p>
        </div>

        <!-- Warm Sunset -->
        <div 
          @click="themeStore.setTheme('sunset')"
          :class="['cursor-pointer rounded-2xl border-2 transition-all p-4', themeStore.currentTheme === 'sunset' ? 'border-rose-500 bg-rose-50' : 'border-slate-200 hover:border-rose-300']"
        >
          <div class="h-20 rounded-xl bg-gradient-to-r from-rose-400 to-rose-600 mb-3 shadow-inner"></div>
          <h4 class="font-bold text-rose-900 text-center">Warm Sunset</h4>
          <p class="text-xs text-rose-700 text-center mt-1">อบอุ่น เป็นมิตร มีชีวิตชีวา</p>
        </div>

      </div>
    </div>

    <!-- Admin Warning for protected tabs -->
    <div v-if="!isAdmin && !['theme', 'mapper'].includes(activeTab)" class="bg-red-50 text-red-700 p-4 rounded-lg border border-red-200">
      <p class="font-bold">❌ ไม่มีสิทธิ์เข้าถึง</p>
      <p class="text-sm">หน้านี้สงวนไว้สำหรับผู้ดูแลระบบ (สสจ.ระยอง) เท่านั้นครับ</p>
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
        <p class="text-sm text-slate-500 mb-6 relative">เพียงอัปโหลดไฟล์ <code>cscp.xlsx</code> ระบบจะดึงข้อมูลจากทุกชีตอัตโนมัติ</p>
        <div class="space-y-4 relative">
          <div class="bg-white border-2 border-dashed border-slate-300 rounded-lg p-8 text-center hover:bg-slate-50 transition-colors">
            
            <button @click="downloadTemplate" class="mx-auto mb-6 flex items-center justify-center px-4 py-2 bg-white border border-slate-300 text-slate-700 rounded-xl hover:bg-slate-50 transition-colors shadow-sm text-sm font-medium">
              <Download class="w-4 h-4 mr-2 text-slate-500" />
              ดาวน์โหลดไฟล์มาตรฐาน (cscp.xlsx)
            </button>

            <div class="max-w-xs mx-auto mb-6 text-left">
              <label class="block text-sm font-bold text-slate-700 mb-2">📍 กำหนดอำเภอเริ่มต้น</label>
              <p class="text-xs text-slate-500 mb-2">ระบบจะใช้อำเภอนี้ หากในไฟล์ Excel ไม่ได้ระบุไว้</p>
              <select v-model="defaultDistrict" :disabled="!isAdmin" class="block w-full text-sm text-slate-700 border-slate-300 rounded-md shadow-sm focus:border-primary-500 focus:ring-primary-500 disabled:bg-slate-100 disabled:text-slate-500">
                <option value="เมืองระยอง">เมืองระยอง</option>
                <option value="ปลวกแดง">ปลวกแดง</option>
                <option value="บ้านค่าย">บ้านค่าย</option>
                <option value="บ้านฉาง">บ้านฉาง</option>
                <option value="แกลง">แกลง</option>
                <option value="วังจันทร์">วังจันทร์</option>
                <option value="นิคมพัฒนา">นิคมพัฒนา</option>
                <option value="เขาชะเมา">เขาชะเมา</option>
              </select>
            </div>

            <label class="block text-sm font-medium text-slate-700 mb-2">เลือกไฟล์ Excel ของคุณเพื่อนำเข้า</label>
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
        
        <!-- Import History Table -->
        <div class="mt-8 border-t border-slate-200 pt-6 relative">
          <h4 class="text-md font-bold text-slate-800 mb-4 flex items-center">
            <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="mr-2 text-primary-500"><path d="M3 3v18h18"/><path d="m19 9-5 5-4-4-3 3"/></svg>
            ประวัติการนำเข้าไฟล์
          </h4>
          <div class="overflow-x-auto bg-white rounded-lg border border-slate-200">
            <table class="min-w-full divide-y divide-slate-200 text-sm">
              <thead class="bg-slate-50">
                <tr>
                  <th class="px-4 py-3 text-left text-xs font-medium text-slate-500 uppercase tracking-wider">วันเวลา</th>
                  <th class="px-4 py-3 text-left text-xs font-medium text-slate-500 uppercase tracking-wider">ชื่อไฟล์</th>
                  <th class="px-4 py-3 text-left text-xs font-medium text-slate-500 uppercase tracking-wider">ผู้นำเข้า</th>
                  <th class="px-4 py-3 text-left text-xs font-medium text-slate-500 uppercase tracking-wider">ผลลัพธ์</th>
                  <th class="px-4 py-3 text-center text-xs font-medium text-slate-500 uppercase tracking-wider">ดาวน์โหลด</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-slate-200">
                <tr v-for="h in importHistories" :key="h.id" class="hover:bg-slate-50">
                  <td class="px-4 py-3 whitespace-nowrap">{{ new Date(h.created_at).toLocaleString('th-TH') }}</td>
                  <td class="px-4 py-3 whitespace-nowrap font-medium text-slate-700 truncate max-w-[150px]">{{ h.file_name }}</td>
                  <td class="px-4 py-3 whitespace-nowrap">
                    <div>{{ h.uploader_email || 'ไม่ระบุ' }}</div>
                    <div class="text-xs text-slate-500">{{ h.district }}</div>
                  </td>
                  <td class="px-4 py-3 whitespace-nowrap">
                    <span v-if="h.summary" class="text-xs">
                      <span class="text-emerald-600 font-bold mr-2">{{ h.summary.rowsSuccess }} สำเร็จ</span>
                      <span v-if="h.summary.rowsFailed" class="text-red-500">{{ h.summary.rowsFailed }} พลาด</span>
                    </span>
                  </td>
                  <td class="px-4 py-3 whitespace-nowrap text-center">
                    <button @click="downloadBase64File(h.file_content_base64, h.file_name)" class="text-primary-600 hover:text-primary-800 bg-primary-50 p-2 rounded-full inline-flex hover:bg-primary-100 transition-colors" title="โหลดไฟล์ต้นฉบับ">
                      <Download class="w-4 h-4" />
                    </button>
                  </td>
                </tr>
                <tr v-if="importHistories.length === 0">
                  <td colspan="5" class="px-4 py-8 text-center text-slate-500">ไม่มีประวัติการนำเข้า</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

      </div>

      <!-- Tab: Business Types -->
      <div v-if="isAdmin" v-show="activeTab === 'types'" class="card p-6 border border-slate-200 shadow-sm">
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
</template>
