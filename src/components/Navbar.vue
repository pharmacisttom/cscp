<script setup>
import { ref } from 'vue'
import { Menu, UserCircle } from 'lucide-vue-next'

const showMobileMenu = ref(false)
</script>

<template>
  <header class="bg-white border-b border-slate-200 h-16 flex items-center justify-between px-4 md:px-6 shadow-sm z-10">
    <div class="flex items-center md:hidden">
      <button 
        @click="showMobileMenu = !showMobileMenu"
        class="text-slate-500 hover:text-slate-700 focus:outline-none focus:ring-2 focus:ring-inset focus:ring-primary-500 rounded-md p-2"
      >
        <Menu class="h-6 w-6" />
      </button>
      <span class="ml-2 text-lg font-bold text-primary-800">CSCP</span>
    </div>
    
    <div class="hidden md:flex flex-1 items-center justify-between">
      <h1 class="text-xl font-semibold text-slate-800 tracking-tight">ระบบงาน Postmarket Health Customer Product</h1>
      <div class="flex items-center space-x-4">
        <button class="text-slate-400 hover:text-slate-600 transition-colors">
          <span class="sr-only">Profile</span>
          <UserCircle class="h-8 w-8" />
        </button>
      </div>
    </div>

    <!-- Mobile view header items -->
    <div class="md:hidden flex items-center">
       <UserCircle class="h-7 w-7 text-slate-400" />
    </div>
  </header>
</template>
