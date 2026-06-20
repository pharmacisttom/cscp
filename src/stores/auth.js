import { defineStore } from 'pinia'
import { supabase } from '../lib/supabase'

export const useAuthStore = defineStore('auth', {
  state: () => ({
    user: null,
    profile: null,
    loading: true,
  }),
  getters: {
    isAdmin: (state) => state.profile?.role === 'admin',
    userDistrict: (state) => state.profile?.district || null,
  },
  actions: {
    async fetchUserAndProfile() {
      this.loading = true
      try {
        const { data: { session } } = await supabase.auth.getSession()
        
        if (session && session.user) {
          this.user = session.user
          
          // Fetch profile
          const { data: profileData, error } = await supabase
            .from('profiles')
            .select('*, officers(full_name)')
            .eq('id', session.user.id)
            .single()
            
          if (!error && profileData) {
            this.profile = profileData
          } else {
            // Auto-create profile if missing (fallback for manual signups before this feature)
            const { data: newProfile, error: insertError } = await supabase
              .from('profiles')
              .insert([{ id: session.user.id, email: session.user.email, role: 'district_user' }])
              .select()
              .single()
              
            if (!insertError) {
              this.profile = newProfile
            }
          }
        } else {
          this.user = null
          this.profile = null
        }
      } catch (error) {
        console.error('Error fetching auth state:', error)
      } finally {
        this.loading = false
      }
    },
    async signOut() {
      await supabase.auth.signOut()
      this.user = null
      this.profile = null
    }
  }
})
