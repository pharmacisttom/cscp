<script setup>
import { onMounted, ref } from 'vue'
import { supabase } from './lib/supabase'
import { useRouter } from 'vue-router'
import Navbar from './components/Navbar.vue'
import Sidebar from './components/Sidebar.vue'

const router = useRouter()
const session = ref(null)

onMounted(() => {
  supabase.auth.getSession().then(({ data }) => {
    session.value = data.session
  })

  supabase.auth.onAuthStateChange((_event, _session) => {
    session.value = _session
  })
})
</script>

<template>
  <div v-if="!session" class="min-h-screen bg-slate-50 flex flex-col justify-center py-12 sm:px-6 lg:px-8">
    <router-view />
  </div>
  <div v-else class="min-h-screen bg-slate-50 flex">
    <Sidebar class="hidden md:flex" />
    <div class="flex-1 flex flex-col min-w-0">
      <Navbar />
      <main class="flex-1 overflow-y-auto p-4 md:p-6 lg:p-8">
        <router-view />
      </main>
    </div>
  </div>
</template>
