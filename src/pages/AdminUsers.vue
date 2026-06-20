<script setup>
import { ref, onMounted } from 'vue'
import { supabase } from '../lib/supabase'
import Swal from 'sweetalert2'
import { useAuthStore } from '../stores/auth'
import { storeToRefs } from 'pinia'

const authStore = useAuthStore()
const { isAdmin } = storeToRefs(authStore)

const users = ref([])

const districtsList = [
  'อำเภอเมืองระยอง', 'อำเภอแกลง', 'อำเภอบ้านค่าย', 'อำเภอปลวกแดง', 'อำเภอบ้านฉาง', 'อำเภอวังจันทร์', 'อำเภอเขาชะเมา', 'อำเภอนิคมพัฒนา'
]

const fetchUsers = async () => {
  const { data } = await supabase.from('profiles').select('*').order('email')
  if (data) users.value = data
}

const updateUserRole = async (user, newRole) => {
  const { error } = await supabase.from('profiles').update({ role: newRole }).eq('id', user.id)
  if (error) {
    Swal.fire('ข้อผิดพลาด', error.message, 'error')
  } else {
    Swal.fire({ toast: true, position: 'top-end', showConfirmButton: false, timer: 3000, icon: 'success', title: 'อัปเดตระดับสิทธิ์สำเร็จ' })
  }
}

const updateUserDistrict = async (user, newDistrict) => {
  const { error } = await supabase.from('profiles').update({ district: newDistrict }).eq('id', user.id)
  if (error) {
    Swal.fire('ข้อผิดพลาด', error.message, 'error')
  } else {
    Swal.fire({ toast: true, position: 'top-end', showConfirmButton: false, timer: 3000, icon: 'success', title: 'อัปเดตเขตรับผิดชอบสำเร็จ' })
  }
}

onMounted(() => {
  if (isAdmin.value) {
    fetchUsers()
  }
})
</script>

<template>
  <div class="space-y-6 max-w-6xl mx-auto">
    <div class="flex items-center justify-between">
      <div>
        <h1 class="text-2xl font-bold text-slate-900">ระบบจัดการผู้ใช้งาน (Admin Only)</h1>
        <p class="text-sm text-slate-500 mt-1">กำหนดสิทธิ์ สสจ. หรือมอบหมายเขตพื้นที่รับผิดชอบประจำอำเภอให้กับบัญชีผู้ใช้</p>
      </div>
    </div>

    <!-- Admin Warning if not admin -->
    <div v-if="!isAdmin" class="bg-red-50 text-red-700 p-6 rounded-xl border border-red-200 text-center shadow-sm">
      <svg class="w-12 h-12 text-red-400 mx-auto mb-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
      </svg>
      <h2 class="text-lg font-bold">❌ ไม่มีสิทธิ์เข้าถึง</h2>
      <p class="text-sm mt-1">หน้านี้สงวนไว้สำหรับผู้ดูแลระบบ (สสจ.ระยอง) เท่านั้นครับ หากต้องการเข้าถึงกรุณาติดต่อผู้ดูแลระบบหลัก</p>
    </div>

    <!-- Main Table Card for Admin -->
    <div v-else class="card border border-slate-200 shadow-sm overflow-hidden">
      <div class="bg-white p-5 border-b border-slate-200 bg-slate-50/50">
        <h3 class="text-lg leading-6 font-bold text-slate-900 flex items-center">
          รายชื่อผู้ใช้งานทั้งหมดในระบบ
          <span class="ml-2 px-2.5 py-0.5 rounded-full text-xs font-medium bg-primary-100 text-primary-800">
            {{ users.length }} บัญชี
          </span>
        </h3>
      </div>
      
      <div class="overflow-x-auto">
        <table class="min-w-full divide-y divide-slate-200">
          <thead class="bg-slate-50">
            <tr>
              <th scope="col" class="px-6 py-4 text-left text-xs font-medium text-slate-500 uppercase tracking-wider">บัญชีผู้ใช้ (อีเมล)</th>
              <th scope="col" class="px-6 py-4 text-left text-xs font-medium text-slate-500 uppercase tracking-wider">ระดับสิทธิ์ (Role)</th>
              <th scope="col" class="px-6 py-4 text-left text-xs font-medium text-slate-500 uppercase tracking-wider">เขตพื้นที่รับผิดชอบ (เฉพาะ User)</th>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-slate-200">
            <tr v-if="users.length === 0">
              <td colspan="3" class="px-6 py-8 text-center text-slate-500">กำลังโหลดข้อมูล...</td>
            </tr>
            <tr v-for="user in users" :key="user.id" class="hover:bg-slate-50 transition-colors">
              <td class="px-6 py-4 whitespace-nowrap">
                <div class="flex items-center">
                  <div class="h-8 w-8 rounded-full bg-primary-100 flex items-center justify-center text-primary-700 font-bold mr-3">
                    {{ user.email.charAt(0).toUpperCase() }}
                  </div>
                  <div class="text-sm font-medium text-slate-900">{{ user.email }}</div>
                </div>
              </td>
              <td class="px-6 py-4 whitespace-nowrap">
                <select 
                  v-model="user.role" 
                  @change="updateUserRole(user, user.role)" 
                  class="form-input py-1.5 text-sm w-48 font-medium shadow-sm"
                  :class="user.role === 'admin' ? 'bg-amber-50 border-amber-200 text-amber-800' : 'bg-white border-slate-300'"
                >
                  <option value="admin">⭐ สสจ. (Admin)</option>
                  <option value="district_user">👤 ประจำอำเภอ (User)</option>
                </select>
              </td>
              <td class="px-6 py-4 whitespace-nowrap">
                <select 
                  v-model="user.district" 
                  @change="updateUserDistrict(user, user.district)" 
                  :disabled="user.role === 'admin'" 
                  class="form-input py-1.5 text-sm w-56 shadow-sm"
                  :class="user.role === 'admin' ? 'bg-slate-100 text-slate-400 cursor-not-allowed' : 'bg-white border-slate-300'"
                >
                  <option value="">-- ไม่ได้กำหนด / ดูทั้งหมด --</option>
                  <option v-for="d in districtsList" :key="d" :value="d">{{ d }}</option>
                </select>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>
