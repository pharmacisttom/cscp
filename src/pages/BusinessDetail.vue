<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase } from '../lib/supabase'
import BusinessTypeBadge from '../components/BusinessTypeBadge.vue'
import RiskBadge from '../components/RiskBadge.vue'
import LicenseStatusBadge from '../components/LicenseStatusBadge.vue'
import { MapPin, Edit, FileText, Package, AlertCircle, Image as ImageIcon, ExternalLink, Lock, CheckCircle, Clock } from 'lucide-vue-next'
import dayjs from 'dayjs'
import 'dayjs/locale/th'

dayjs.locale('th')

const route = useRoute()
const router = useRouter()
const business = ref(null)
const loading = ref(true)

const currentTab = ref('overview')
const currentUser = ref(null)

const inspections = ref([])
const products = ref([])
const complaints = ref([])

onMounted(async () => {
  try {
    const { data: userData } = await supabase.auth.getUser()
    currentUser.value = userData?.user || null

    const { data, error } = await supabase
      .from('businesses')
      .select('*')
      .eq('id', route.params.id)
      .single()
      
    if (error) throw error
    business.value = data

    // Fetch related data
    const [inspRes, prodRes, compRes] = await Promise.all([
      supabase.from('inspections').select('*').eq('business_id', route.params.id).order('inspection_date', { ascending: false }),
      supabase.from('products').select('*').eq('business_id', route.params.id).order('created_at', { ascending: false }),
      supabase.from('complaints').select('*').eq('business_id', route.params.id).order('complaint_date', { ascending: false })
    ])

    inspections.value = inspRes.data || []
    products.value = prodRes.data || []
    complaints.value = compRes.data || []

  } catch (error) {
    console.error(error)
  } finally {
    loading.value = false
  }
})

const openMap = () => {
  if (business.value?.latitude && business.value?.longitude) {
    window.open(`https://www.google.com/maps/search/?api=1&query=${business.value.latitude},${business.value.longitude}`, '_blank')
  }
}

const getGoogleDriveImage = (url) => {
  if (!url) return null;
  const match = url.match(/\/d\/(.*?)\//);
  if (match && match[1]) {
    return `https://drive.google.com/uc?export=view&id=${match[1]}`;
  }
  return url;
}

const images = computed(() => {
  if (!business.value) return [];
  const list = [];
  if (business.value.image_front) list.push({ title: 'ป้ายหน้าร้าน / ด้านหน้า', url: getGoogleDriveImage(business.value.image_front) });
  if (business.value.image_inside_1) list.push({ title: 'ภายในจุดบริการ 1', url: getGoogleDriveImage(business.value.image_inside_1) });
  if (business.value.image_inside_2) list.push({ title: 'ภายในจุดบริการ 2', url: getGoogleDriveImage(business.value.image_inside_2) });
  if (business.value.image_specific) list.push({ title: 'พื้นที่เฉพาะ/ห้องตรวจ', url: getGoogleDriveImage(business.value.image_specific) });
  if (business.value.image_document) list.push({ title: 'เอกสารใบอนุญาต', url: getGoogleDriveImage(business.value.image_document) });
  return list;
})

const formatDate = (dateStr) => {
  if (!dateStr) return '-'
  return dayjs(dateStr).format('D MMM YYYY')
}

// Logic to check if an inspection is viewable by current user
const canViewInspection = (insp) => {
  if (!insp.is_confidential) return true
  if (currentUser.value && currentUser.value.id === insp.created_by) return true
  // Note: If you have an admin role logic, add it here. Currently we assume all users are standard unless created_by matches.
  return false
}
</script>

<template>
  <div v-if="loading" class="text-center py-20">
    <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-600 mx-auto"></div>
    <p class="mt-4 text-slate-500 font-medium">กำลังโหลดข้อมูลกิจการ...</p>
  </div>

  <div v-else-if="business" class="space-y-6 max-w-7xl mx-auto pb-12">
    <!-- Header -->
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
      <div>
        <h1 class="text-3xl font-extrabold text-slate-900 tracking-tight">{{ business.business_name }}</h1>
        <div class="mt-3 flex flex-wrap items-center gap-3">
          <BusinessTypeBadge :type="business.business_type" />
          <RiskBadge :level="business.risk_level" />
          <LicenseStatusBadge :status="business.license_status" />
        </div>
      </div>
      <button @click="router.push(`/businesses/${business.id}/edit`)" class="btn-secondary w-full sm:w-auto shadow-sm">
        <Edit class="w-4 h-4 mr-2" />
        แก้ไขข้อมูลกิจการ
      </button>
    </div>

    <!-- Tabs Navigation -->
    <div class="border-b border-slate-200">
      <nav class="-mb-px flex space-x-8 overflow-x-auto hide-scrollbar" aria-label="Tabs">
        <button 
          @click="currentTab = 'overview'" 
          :class="[currentTab === 'overview' ? 'border-primary-500 text-primary-600' : 'border-transparent text-slate-500 hover:text-slate-700 hover:border-slate-300', 'whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm transition-colors']"
        >
          ข้อมูลทั่วไป
        </button>
        <button 
          @click="currentTab = 'inspections'" 
          :class="[currentTab === 'inspections' ? 'border-primary-500 text-primary-600' : 'border-transparent text-slate-500 hover:text-slate-700 hover:border-slate-300', 'whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm transition-colors flex items-center']"
        >
          ประวัติการตรวจ
          <span v-if="inspections.length" class="ml-2 bg-slate-100 text-slate-600 py-0.5 px-2 rounded-full text-xs">{{ inspections.length }}</span>
        </button>
        <button 
          @click="currentTab = 'products'" 
          :class="[currentTab === 'products' ? 'border-primary-500 text-primary-600' : 'border-transparent text-slate-500 hover:text-slate-700 hover:border-slate-300', 'whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm transition-colors flex items-center']"
        >
          ผลิตภัณฑ์
          <span v-if="products.length" class="ml-2 bg-slate-100 text-slate-600 py-0.5 px-2 rounded-full text-xs">{{ products.length }}</span>
        </button>
        <button 
          @click="currentTab = 'complaints'" 
          :class="[currentTab === 'complaints' ? 'border-primary-500 text-primary-600' : 'border-transparent text-slate-500 hover:text-slate-700 hover:border-slate-300', 'whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm transition-colors flex items-center']"
        >
          เรื่องร้องเรียน
          <span v-if="complaints.length" class="ml-2 bg-red-100 text-red-600 py-0.5 px-2 rounded-full text-xs">{{ complaints.length }}</span>
        </button>
      </nav>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-4 gap-6">
      
      <!-- Main Content Area -->
      <div class="lg:col-span-3 space-y-6">
        
        <!-- TAB: OVERVIEW -->
        <div v-show="currentTab === 'overview'" class="space-y-6 animate-fadeIn">
          <!-- Info Card -->
          <div class="card p-6 border-t-4 border-t-primary-500">
            <h3 class="text-lg font-bold text-slate-900 mb-6 flex items-center"><Store class="w-5 h-5 mr-2 text-primary-600" /> ข้อมูลสถานประกอบการ</h3>
            <dl class="grid grid-cols-1 sm:grid-cols-2 gap-x-6 gap-y-6">
              <div class="sm:col-span-1 bg-slate-50 p-3 rounded-lg">
                <dt class="text-xs font-semibold text-slate-500 uppercase tracking-wider">เลขที่ใบอนุญาต</dt>
                <dd class="mt-1 text-sm font-medium text-slate-900">{{ business.license_no || '-' }}</dd>
              </div>
              <div class="sm:col-span-1 bg-slate-50 p-3 rounded-lg">
                <dt class="text-xs font-semibold text-slate-500 uppercase tracking-wider">ชื่อผู้รับอนุญาต</dt>
                <dd class="mt-1 text-sm font-medium text-slate-900">{{ business.licensee_name || '-' }}</dd>
              </div>
              <div class="sm:col-span-1 bg-slate-50 p-3 rounded-lg">
                <dt class="text-xs font-semibold text-slate-500 uppercase tracking-wider">ชื่อผู้ดำเนินการ / เภสัชกร</dt>
                <dd class="mt-1 text-sm font-medium text-slate-900">{{ business.operator_name || '-' }}</dd>
              </div>
              <div class="sm:col-span-1 bg-slate-50 p-3 rounded-lg" v-if="business.professional_license_no">
                <dt class="text-xs font-semibold text-slate-500 uppercase tracking-wider">เลขที่ใบประกอบวิชาชีพ</dt>
                <dd class="mt-1 text-sm font-medium text-slate-900">{{ business.professional_license_no }}</dd>
              </div>
              
              <div class="sm:col-span-2 bg-slate-50 p-3 rounded-lg">
                <dt class="text-xs font-semibold text-slate-500 uppercase tracking-wider">ที่อยู่</dt>
                <dd class="mt-1 text-sm font-medium text-slate-900">
                  {{ business.address }} 
                  {{ business.subdistrict ? `ต.${business.subdistrict}` : '' }} 
                  {{ business.district ? `อ.${business.district}` : '' }} 
                  {{ business.province ? `จ.${business.province}` : '' }}
                </dd>
              </div>
              <div class="sm:col-span-1 bg-slate-50 p-3 rounded-lg">
                <dt class="text-xs font-semibold text-slate-500 uppercase tracking-wider">เบอร์โทรศัพท์ติดต่อ</dt>
                <dd class="mt-1 text-sm font-medium text-slate-900">{{ business.phone || '-' }}</dd>
              </div>
              <div class="sm:col-span-1 bg-slate-50 p-3 rounded-lg">
                <dt class="text-xs font-semibold text-slate-500 uppercase tracking-wider">เวลาเปิดทำการ</dt>
                <dd class="mt-1 text-sm font-medium text-slate-900">{{ business.opening_hours || '-' }}</dd>
              </div>
            </dl>
            
            <!-- Map Button -->
            <div class="mt-6 pt-6 border-t border-slate-200">
              <button @click="openMap" class="btn-secondary w-full sm:w-auto text-primary-700 bg-primary-50 border-primary-200 hover:bg-primary-100 transition-colors">
                <MapPin class="w-4 h-4 mr-2" />
                เปิด Google Maps (พิกัด: {{ business.latitude || 'N/A' }}, {{ business.longitude || 'N/A' }})
              </button>
            </div>
          </div>

          <!-- Images Card -->
          <div class="card p-6">
             <h3 class="text-lg font-bold text-slate-900 mb-6 flex items-center">
               <ImageIcon class="w-5 h-5 mr-2 text-slate-400" /> รูปภาพที่เกี่ยวข้อง
             </h3>
             <div v-if="images.length > 0" class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-6">
                <div v-for="(img, idx) in images" :key="idx" class="border border-slate-200 rounded-xl overflow-hidden group shadow-sm hover:shadow-md transition-shadow">
                   <div class="aspect-w-4 aspect-h-3 bg-slate-100 relative cursor-pointer" @click="window.open(img.url, '_blank')">
                     <img :src="img.url" alt="Business Image" class="object-cover w-full h-full group-hover:scale-105 transition-transform duration-300" onerror="this.src='data:image/svg+xml;charset=UTF-8,%3Csvg xmlns=%22http://www.w3.org/2000/svg%22 width=%22100%25%22 height=%22100%25%22 viewBox=%220 0 24 24%22 fill=%22none%22 stroke=%22%23cbd5e1%22 stroke-width=%221%22 stroke-linecap=%22round%22 stroke-linejoin=%22round%22%3E%3Crect x=%223%22 y=%223%22 width=%2218%22 height=%2218%22 rx=%222%22 ry=%222%22/%3E%3Ccircle cx=%228.5%22 cy=%228.5%22 r=%221.5%22/%3E%3Cpolyline points=%2221 15 16 10 5 21%22/%3E%3C/svg%3E'; this.className='object-contain p-8 w-full h-full';" />
                     <div class="absolute inset-0 bg-black bg-opacity-0 group-hover:bg-opacity-10 transition-all flex items-center justify-center">
                        <ExternalLink class="text-white opacity-0 group-hover:opacity-100 w-8 h-8 drop-shadow-md" />
                     </div>
                   </div>
                   <div class="p-3 bg-white border-t border-slate-100">
                     <p class="text-xs font-semibold text-slate-700 truncate text-center">{{ img.title }}</p>
                   </div>
                </div>
             </div>
             <div v-else class="text-center py-12 text-slate-500 bg-slate-50 rounded-xl border-2 border-dashed border-slate-200">
               <ImageIcon class="w-12 h-12 text-slate-300 mx-auto mb-3" />
               ไม่มีรูปภาพในระบบ
             </div>
          </div>
        </div>

        <!-- TAB: INSPECTIONS -->
        <div v-show="currentTab === 'inspections'" class="animate-fadeIn space-y-4">
          <div class="flex justify-between items-center mb-4">
            <h3 class="text-lg font-bold text-slate-900">ประวัติการตรวจประเมิน</h3>
            <button @click="router.push(`/businesses/${business.id}/inspections`)" class="btn-primary text-sm py-1.5 px-3">
              <Plus class="w-4 h-4 mr-1" /> ตรวจประเมินใหม่
            </button>
          </div>
          
          <div v-if="inspections.length === 0" class="text-center py-12 bg-white rounded-xl border border-slate-200 shadow-sm text-slate-500">
            <FileText class="w-12 h-12 text-slate-300 mx-auto mb-3" />
            ยังไม่มีประวัติการตรวจประเมิน
          </div>

          <div v-else class="space-y-4">
            <div v-for="insp in inspections" :key="insp.id" class="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden">
              <div class="p-5 flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 bg-slate-50/50 border-b border-slate-100">
                <div class="flex items-center space-x-3">
                  <div class="bg-primary-100 text-primary-700 p-2 rounded-lg">
                    <FileText class="w-6 h-6" />
                  </div>
                  <div>
                    <h4 class="font-bold text-slate-900">การตรวจวันที่ {{ formatDate(insp.inspection_date) }}</h4>
                    <p class="text-sm text-slate-500">ผู้ตรวจ: {{ insp.inspector_name }}</p>
                  </div>
                </div>
                <div class="flex items-center space-x-3">
                  <span v-if="insp.is_confidential" class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800 border border-yellow-200">
                    <Lock class="w-3 h-3 mr-1" /> ปกปิด
                  </span>
                  <span :class="[
                    'px-3 py-1 rounded-full text-xs font-bold border',
                    insp.inspection_result === 'passed' ? 'bg-green-50 text-green-700 border-green-200' : 
                    insp.inspection_result === 'failed' ? 'bg-red-50 text-red-700 border-red-200' : 
                    'bg-orange-50 text-orange-700 border-orange-200'
                  ]">
                    {{ insp.inspection_result === 'passed' ? 'ผ่านเกณฑ์' : insp.inspection_result === 'failed' ? 'ไม่ผ่านเกณฑ์' : 'ต้องปรับปรุง' }}
                  </span>
                </div>
              </div>
              
              <div class="p-5">
                <!-- If confidential and not authorized -->
                <div v-if="!canViewInspection(insp)" class="text-center py-6 bg-slate-50 rounded-lg border border-dashed border-slate-300">
                   <Lock class="w-8 h-8 text-slate-400 mx-auto mb-2" />
                   <p class="text-sm font-medium text-slate-700">ไฟล์ปกปิดความลับ (Confidential)</p>
                   <p class="text-xs text-slate-500 mt-1">เฉพาะผู้บันทึก หรือผู้ดูแลระบบเท่านั้นที่สามารถดูรายละเอียดได้</p>
                </div>
                
                <!-- If authorized to view -->
                <div v-else class="space-y-4">
                  <div class="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm">
                    <div>
                      <span class="block font-medium text-slate-500 mb-1">ปัญหาที่พบ</span>
                      <p class="text-slate-900 bg-slate-50 p-2 rounded">{{ insp.problem_found || '-' }}</p>
                    </div>
                    <div>
                      <span class="block font-medium text-slate-500 mb-1">คำแนะนำ / สิ่งที่ต้องปรับปรุง</span>
                      <p class="text-slate-900 bg-slate-50 p-2 rounded">{{ insp.recommendation || '-' }}</p>
                    </div>
                  </div>
                  <div v-if="insp.next_followup_date" class="text-sm flex items-center text-orange-600 bg-orange-50 p-2 rounded border border-orange-100 w-max">
                    <Clock class="w-4 h-4 mr-2" /> กำหนดตรวจซ้ำ: {{ formatDate(insp.next_followup_date) }}
                  </div>
                  
                  <!-- Inspection Images -->
                  <div v-if="insp.form_data && insp.form_data.inspection_images && insp.form_data.inspection_images.filter(img => img).length > 0" class="pt-4 mt-2">
                    <span class="block font-medium text-slate-500 mb-2">รูปภาพจากการตรวจ</span>
                    <div class="flex flex-wrap gap-3">
                      <div v-for="(img, idx) in insp.form_data.inspection_images.filter(img => img)" :key="idx" class="w-24 h-24 rounded-lg overflow-hidden border border-slate-200 cursor-pointer shadow-sm hover:shadow-md hover:opacity-90 transition-all" @click="window.open(getGoogleDriveImage(img), '_blank')">
                        <img :src="getGoogleDriveImage(img)" class="w-full h-full object-cover" onerror="this.src='data:image/svg+xml;charset=UTF-8,%3Csvg xmlns=%22http://www.w3.org/2000/svg%22 width=%22100%25%22 height=%22100%25%22 viewBox=%220 0 24 24%22 fill=%22none%22 stroke=%22%23cbd5e1%22 stroke-width=%221%22 stroke-linecap=%22round%22 stroke-linejoin=%22round%22%3E%3Crect x=%223%22 y=%223%22 width=%2218%22 height=%2218%22 rx=%222%22 ry=%222%22/%3E%3Ccircle cx=%228.5%22 cy=%228.5%22 r=%221.5%22/%3E%3Cpolyline points=%2221 15 16 10 5 21%22/%3E%3C/svg%3E';" />
                      </div>
                    </div>
                  </div>
                  
                  <!-- PDF Attachment -->
                  <div class="pt-4 mt-4 border-t border-slate-100 flex justify-between items-center">
                    <div v-if="insp.attachment_url">
                       <a :href="insp.attachment_url" target="_blank" class="inline-flex items-center text-sm font-medium text-primary-600 hover:text-primary-800">
                         <FileText class="w-4 h-4 mr-1.5" /> ดูไฟล์เอกสารแนบ (PDF)
                       </a>
                    </div>
                    <div v-else class="text-sm text-slate-400 italic">ไม่มีไฟล์แนบ</div>
                    
                    <button class="text-sm text-slate-500 hover:text-primary-600 font-medium">ดูข้อมูลเต็ม (JSON)</button>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- TAB: PRODUCTS -->
        <div v-show="currentTab === 'products'" class="animate-fadeIn space-y-4">
          <div class="flex justify-between items-center mb-4">
            <h3 class="text-lg font-bold text-slate-900">ผลิตภัณฑ์ / สินค้า</h3>
            <button @click="router.push(`/businesses/${business.id}/products`)" class="btn-primary text-sm py-1.5 px-3">
              <Plus class="w-4 h-4 mr-1" /> เพิ่มผลิตภัณฑ์
            </button>
          </div>

          <div v-if="products.length === 0" class="text-center py-12 bg-white rounded-xl border border-slate-200 shadow-sm text-slate-500">
            <Package class="w-12 h-12 text-slate-300 mx-auto mb-3" />
            ยังไม่มีข้อมูลผลิตภัณฑ์
          </div>

          <div v-else class="bg-white rounded-xl shadow-sm border border-slate-200 overflow-hidden">
            <table class="min-w-full divide-y divide-slate-200">
              <thead class="bg-slate-50">
                <tr>
                  <th class="px-6 py-3 text-left text-xs font-semibold text-slate-500 uppercase">ชื่อผลิตภัณฑ์</th>
                  <th class="px-6 py-3 text-left text-xs font-semibold text-slate-500 uppercase">ประเภท</th>
                  <th class="px-6 py-3 text-left text-xs font-semibold text-slate-500 uppercase">เลขจดแจ้ง/อย.</th>
                  <th class="px-6 py-3 text-left text-xs font-semibold text-slate-500 uppercase">สถานะ</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-slate-100">
                <tr v-for="prod in products" :key="prod.id" class="hover:bg-slate-50">
                  <td class="px-6 py-4">
                    <p class="text-sm font-bold text-slate-900">{{ prod.product_name }}</p>
                    <p class="text-xs text-slate-500">{{ prod.brand || 'ไม่มีแบรนด์' }}</p>
                  </td>
                  <td class="px-6 py-4 text-sm text-slate-700">{{ prod.product_type }}</td>
                  <td class="px-6 py-4 text-sm text-slate-700">{{ prod.registration_no || '-' }}</td>
                  <td class="px-6 py-4">
                    <span :class="[
                      'px-2.5 py-1 rounded-full text-xs font-medium',
                      prod.product_status === 'active' ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'
                    ]">
                      {{ prod.product_status === 'active' ? 'ปกติ' : 'เรียกคืน/หมดอายุ' }}
                    </span>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <!-- TAB: COMPLAINTS -->
        <div v-show="currentTab === 'complaints'" class="animate-fadeIn space-y-4">
          <div class="flex justify-between items-center mb-4">
            <h3 class="text-lg font-bold text-slate-900">เรื่องร้องเรียน</h3>
            <button @click="router.push(`/businesses/${business.id}/complaints`)" class="btn-primary text-sm py-1.5 px-3 bg-red-600 hover:bg-red-700 ring-red-500">
              <AlertCircle class="w-4 h-4 mr-1" /> รับเรื่องร้องเรียน
            </button>
          </div>

          <div v-if="complaints.length === 0" class="text-center py-12 bg-white rounded-xl border border-slate-200 shadow-sm text-slate-500">
            <CheckCircle class="w-12 h-12 text-green-300 mx-auto mb-3" />
            ไม่มีประวัติเรื่องร้องเรียน (สถานะปกติ)
          </div>

          <div v-else class="space-y-4">
            <div v-for="comp in complaints" :key="comp.id" class="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden">
              <div class="p-5 flex justify-between items-center bg-slate-50/50 border-b border-slate-100">
                <div>
                  <h4 class="font-bold text-slate-900 text-lg">{{ comp.complaint_topic }}</h4>
                  <p class="text-sm text-slate-500">วันที่ร้องเรียน: {{ formatDate(comp.complaint_date) }} | ผู้ร้องเรียน: {{ comp.complainant_name || 'ไม่ประสงค์ออกนาม' }}</p>
                </div>
                <div>
                  <span :class="[
                    'px-3 py-1 rounded-full text-xs font-bold border',
                    comp.status === 'open' ? 'bg-red-50 text-red-700 border-red-200' : 
                    comp.status === 'investigating' ? 'bg-orange-50 text-orange-700 border-orange-200' : 
                    'bg-green-50 text-green-700 border-green-200'
                  ]">
                    {{ comp.status === 'open' ? 'เปิดเรื่อง' : comp.status === 'investigating' ? 'กำลังตรวจสอบ' : 'ปิดเรื่องแล้ว' }}
                  </span>
                </div>
              </div>
              <div class="p-5 space-y-3">
                <div>
                  <span class="block text-xs font-semibold text-slate-500 uppercase mb-1">รายละเอียด</span>
                  <p class="text-sm text-slate-800">{{ comp.complaint_detail || '-' }}</p>
                </div>
                <div v-if="comp.action_taken" class="pt-3 border-t border-slate-100">
                  <span class="block text-xs font-semibold text-slate-500 uppercase mb-1">การดำเนินการแก้ไข</span>
                  <p class="text-sm text-slate-800 bg-green-50 p-3 rounded-lg border border-green-100">{{ comp.action_taken }}</p>
                </div>
              </div>
            </div>
          </div>
        </div>

      </div>
      
      <!-- Right Sidebar Actions -->
      <div class="lg:col-span-1 space-y-6">
        <div class="card p-6 bg-slate-50 border-none shadow-none ring-1 ring-slate-200">
          <h3 class="text-xs font-bold text-slate-500 uppercase tracking-wider mb-4">เมนูจัดการด่วน</h3>
          <div class="space-y-3">
            <button @click="router.push(`/businesses/${business.id}/inspections`)" class="w-full flex items-center justify-start px-4 py-3 border border-slate-200 shadow-sm text-sm font-bold rounded-xl text-slate-700 bg-white hover:bg-slate-50 hover:border-slate-300 transition-all group">
              <div class="bg-primary-100 text-primary-600 p-1.5 rounded-lg mr-3 group-hover:bg-primary-500 group-hover:text-white transition-colors">
                <FileText class="w-4 h-4" />
              </div>
              บันทึกการตรวจประเมิน
            </button>
            <button @click="router.push(`/businesses/${business.id}/products`)" class="w-full flex items-center justify-start px-4 py-3 border border-slate-200 shadow-sm text-sm font-bold rounded-xl text-slate-700 bg-white hover:bg-slate-50 hover:border-slate-300 transition-all group">
              <div class="bg-indigo-100 text-indigo-600 p-1.5 rounded-lg mr-3 group-hover:bg-indigo-500 group-hover:text-white transition-colors">
                <Package class="w-4 h-4" />
              </div>
              เพิ่มผลิตภัณฑ์
            </button>
            <button @click="router.push(`/businesses/${business.id}/complaints`)" class="w-full flex items-center justify-start px-4 py-3 border border-slate-200 shadow-sm text-sm font-bold rounded-xl text-slate-700 bg-white hover:bg-slate-50 hover:border-slate-300 transition-all group">
              <div class="bg-red-100 text-red-600 p-1.5 rounded-lg mr-3 group-hover:bg-red-500 group-hover:text-white transition-colors">
                <AlertCircle class="w-4 h-4" />
              </div>
              รับเรื่องร้องเรียน
            </button>
          </div>
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
  animation: fadeIn 0.3s ease-in-out;
}
@keyframes fadeIn {
  from { opacity: 0; transform: translateY(5px); }
  to { opacity: 1; transform: translateY(0); }
}
</style>
