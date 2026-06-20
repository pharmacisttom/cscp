<script setup>
import { ref } from 'vue'
import { supabase } from '../lib/supabase'
import { useRouter } from 'vue-router'
import Swal from 'sweetalert2'

const router = useRouter()
const email = ref('')
const password = ref('')
const loading = ref(false)
const isSignUp = ref(false)

const handleAuth = async () => {
  try {
    loading.value = true
    let authError = null

    if (isSignUp.value) {
      const { error } = await supabase.auth.signUp({
        email: email.value,
        password: password.value,
      })
      authError = error
      if (!error) {
        Swal.fire({
          title: 'สมัครสมาชิกสำเร็จ',
          text: 'กรุณายืนยันอีเมลของคุณ (ถ้าตั้งค่าไว้) หรือเข้าสู่ระบบได้เลย',
          icon: 'success',
          confirmButtonText: 'ตกลง',
          confirmButtonColor: '#0d9488'
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
