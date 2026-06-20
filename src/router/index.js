import { createRouter, createWebHashHistory } from 'vue-router'
import { supabase } from '../lib/supabase'

import Login from '../pages/Login.vue'
import Dashboard from '../pages/Dashboard.vue'
import BusinessList from '../pages/BusinessList.vue'
import BusinessForm from '../pages/BusinessForm.vue'
import BusinessDetail from '../pages/BusinessDetail.vue'
import Settings from '../pages/Settings.vue'
import AdminUsers from '../pages/AdminUsers.vue'
import InspectionCalendar from '../pages/InspectionCalendar.vue'
import OfficerList from '../pages/OfficerList.vue'
import TypeStatistics from '../pages/TypeStatistics.vue'
import InspectionRecord from '../pages/InspectionRecord.vue'

const routes = [
  { path: '/login', name: 'Login', component: Login },
  { path: '/', redirect: '/dashboard' },
  { 
    path: '/dashboard', 
    name: 'Dashboard', 
    component: Dashboard,
    meta: { requiresAuth: true }
  },
  { 
    path: '/businesses', 
    name: 'Businesses', 
    component: BusinessList,
    meta: { requiresAuth: true }
  },
  { 
    path: '/calendar', 
    name: 'InspectionCalendar', 
    component: InspectionCalendar,
    meta: { requiresAuth: true }
  },
  { 
    path: '/officers', 
    name: 'OfficerList', 
    component: OfficerList,
    meta: { requiresAuth: true }
  },
  {
    path: '/statistics/:type',
    name: 'TypeStatistics',
    component: TypeStatistics,
    meta: { requiresAuth: true }
  },
  {
    path: '/inspection-record/:id',
    name: 'InspectionRecord',
    component: InspectionRecord,
    meta: { requiresAuth: true }
  },
  { 
    path: '/businesses/new', 
    name: 'NewBusiness', 
    component: BusinessForm,
    meta: { requiresAuth: true }
  },
  { 
    path: '/businesses/:id', 
    name: 'BusinessDetail', 
    component: BusinessDetail,
    meta: { requiresAuth: true }
  },
  { 
    path: '/businesses/:id/edit', 
    name: 'EditBusiness', 
    component: BusinessForm,
    meta: { requiresAuth: true }
  },
  { 
    path: '/settings', 
    name: 'Settings', 
    component: Settings,
    meta: { requiresAuth: true }
  },
  { 
    path: '/users', 
    name: 'AdminUsers', 
    component: AdminUsers,
    meta: { requiresAuth: true }
  },
  { path: '/businesses/:id/inspections', name: 'Inspections', component: () => import('../pages/InspectionForm.vue') },
  { path: '/businesses/:id/products', name: 'Products', component: () => import('../pages/ProductForm.vue') },
  { path: '/businesses/:id/complaints', name: 'BusinessComplaints', component: () => import('../pages/ComplaintForm.vue') },
  { 
    path: '/complaints', 
    name: 'ComplaintList', 
    component: () => import('../pages/ComplaintList.vue'),
    meta: { requiresAuth: true }
  },
  { 
    path: '/complaints/new', 
    name: 'NewComplaint', 
    component: () => import('../pages/ComplaintForm.vue'),
    meta: { requiresAuth: true }
  },
  { 
    path: '/audit-logs', 
    name: 'AuditLogs', 
    component: () => import('../pages/AuditLogViewer.vue'),
    meta: { requiresAuth: true }
  },
  { 
    path: '/inspection-dashboard', 
    name: 'InspectionDashboard', 
    component: () => import('../pages/InspectionDashboard.vue'),
    meta: { requiresAuth: true }
  }
]

const router = createRouter({
  history: createWebHashHistory(), // Use hash history for easier GitHub Pages deployment
  routes,
})

import { useAuthStore } from '../stores/auth'

router.beforeEach(async (to, from, next) => {
  const { data: { session } } = await supabase.auth.getSession()

  if (to.meta.requiresAuth && !session) {
    next('/login')
  } else if (session) {
    const authStore = useAuthStore()
    // Await profile fetch if missing to prevent race conditions on page load
    if (!authStore.profile) {
      await authStore.fetchUserAndProfile()
    }
    
    if (to.path === '/login') {
      next('/dashboard')
    } else {
      next()
    }
  } else {
    next()
  }
})

export default router
