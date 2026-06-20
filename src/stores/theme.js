import { defineStore } from 'pinia'
import { ref, watch } from 'vue'

export const useThemeStore = defineStore('theme', () => {
  // Try to load from localStorage, default to 'medical'
  const currentTheme = ref(localStorage.getItem('cscp_theme') || 'medical')

  // Apply theme to document on init
  const applyTheme = (themeName) => {
    if (themeName === 'medical') {
      document.documentElement.removeAttribute('data-theme')
    } else {
      document.documentElement.setAttribute('data-theme', themeName)
    }
  }

  // Watch for changes and save to localStorage + apply
  watch(currentTheme, (newTheme) => {
    localStorage.setItem('cscp_theme', newTheme)
    applyTheme(newTheme)
  }, { immediate: true })

  const setTheme = (themeName) => {
    currentTheme.value = themeName
  }

  return {
    currentTheme,
    setTheme
  }
})
