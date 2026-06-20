<script setup>
import { ref } from 'vue'
import { supabase } from '../lib/supabase'
import { useRouter } from 'vue-router'
import Swal from 'sweetalert2'

const router = useRouter()
const email = ref('')
const password = ref('')
const selectedDistrict = ref('')
const loading = ref(false)
const isSignUp = ref(false)

const handleAuth = async () => {
  try {
    loading.value = true
    let authError = null

      if (isSignUp.value && !selectedDistrict.value) {
        Swal.fire('แจ้งเตือน', 'กรุณาระบุอำเภอ หรือ สสจ. ที่สังกัด', 'warning')
        loading.value = false
        return
      }

    if (isSignUp.value) {
      const { data, error } = await supabase.auth.signUp({
        email: email.value,
        password: password.value,
      })
      authError = error
      if (!error && data?.user) {
        // Insert profile data
        const role = selectedDistrict.value === 'สสจ.ระยอง' ? 'admin' : 'district_user'
        await supabase.from('profiles').upsert({
          id: data.user.id,
          email: email.value,
          district: selectedDistrict.value,
          role: role
        })

        Swal.fire({
          title: 'สมัครสมาชิกสำเร็จ',
          text: 'กรุณายืนยันอีเมลของคุณ (ถ้าตั้งค่าไว้) หรือเข้าสู่ระบบได้เลย',
          icon: 'success',
          confirmButtonText: 'ตกลง',
          confirmButtonColor: '#4f46e5'
        })
        isSignUp.value = false
        return
      }
    } else {
      const { error } = await supabase.auth.signInWithPassword({
        email: email.value,
        password: password.value,
      })
      authError = error
      if (!error) {
        router.push('/dashboard')
        return
      }
    }
    
    if (authError) throw authError
    
  } catch (error) {
    Swal.fire({
      title: isSignUp.value ? 'สมัครสมาชิกไม่สำเร็จ' : 'เข้าสู่ระบบไม่สำเร็จ',
      text: error.message,
      icon: 'error',
      confirmButtonText: 'ตกลง',
      confirmButtonColor: '#0d9488'
    })
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <div class="max-w-md w-full mx-auto bg-white rounded-xl shadow-md overflow-hidden p-8 border border-slate-100">
    <div class="text-center mb-8">
      <h2 class="text-3xl font-extrabold text-slate-900 tracking-tight">CSCP</h2>
      <p class="mt-2 text-sm text-slate-500">ระบบงาน Postmarket Health Customer Product</p>
    </div>
    <form class="space-y-6" @submit.prevent="handleAuth">
      <div>
        <label for="email" class="form-label">อีเมล</label>
        <div class="mt-1">
          <input id="email" name="email" type="email" autocomplete="email" required v-model="email" class="form-input" placeholder="admin@example.com" />
        </div>
      </div>

      <div>
        <label for="password" class="form-label">รหัสผ่าน</label>
        <div class="mt-1">
          <input id="password" name="password" type="password" autocomplete="current-password" required v-model="password" class="form-input" placeholder="••••••••" />
        </div>
      </div>

      <div v-if="isSignUp" class="animate-fadeIn">
        <label for="district" class="form-label">สังกัด (สสจ. หรือ อำเภอ) <span class="text-red-500">*</span></label>
        <select id="district" v-model="selectedDistrict" class="form-input mt-1" required>
          <option value="" disabled>-- เลือกสังกัด --</option>
          <option value="สสจ.ระยอง">สสจ.ระยอง (สิทธิ์ Admin)</option>
          <option value="เมืองระยอง">อำเภอเมืองระยอง</option>
          <option value="ปลวกแดง">อำเภอปลวกแดง</option>
          <option value="แกลง">อำเภอแกลง</option>
          <option value="บ้านค่าย">อำเภอบ้านค่าย</option>
          <option value="บ้านฉาง">อำเภอบ้านฉาง</option>
          <option value="นิคมพัฒนา">อำเภอนิคมพัฒนา</option>
          <option value="วังจันทร์">อำเภอวังจันทร์</option>
          <option value="เขาชะเมา">อำเภอเขาชะเมา</option>
        </select>
        <p class="text-xs text-slate-500 mt-1">ใช้สำหรับกำหนดสิทธิ์การเข้าถึงข้อมูลโดยอัตโนมัติ</p>
      </div>

      <div>
        <button type="submit" :disabled="loading" class="w-full btn-primary flex justify-center py-2.5 text-base">
          <span v-if="loading">{{ isSignUp ? 'กำลังสมัครสมาชิก...' : 'กำลังเข้าสู่ระบบ...' }}</span>
          <span v-else>{{ isSignUp ? 'สมัครสมาชิก' : 'เข้าสู่ระบบ' }}</span>
        </button>
      </div>
      
      <div class="text-center mt-4">
        <button type="button" @click="isSignUp = !isSignUp" class="text-sm text-primary-600 hover:text-primary-500 font-medium">
          {{ isSignUp ? 'มีบัญชีอยู่แล้ว? เข้าสู่ระบบ' : 'ยังไม่มีบัญชี? สมัครสมาชิก' }}
        </button>
      </div>
    </form>
  </div>
</template>
