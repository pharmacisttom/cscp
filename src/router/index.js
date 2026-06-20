import { createRouter, createWebHashHistory } from 'vue-router'
import { supabase } from '../lib/supabase'

import Login from '../pages/Login.vue'
import Dashboard from '../pages/Dashboard.vue'
import BusinessList from '../pages/BusinessList.vue'
import BusinessForm from '../pages/BusinessForm.vue'
import BusinessDetail from '../pages/BusinessDetail.vue'
import Settings from '../pages/Settings.vue'
import AdminUsers from '../pages/AdminUsers.vue'

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
  { path: '/businesses/:id/complaints', name: 'Complaints', component: () => import('../pages/ComplaintForm.vue') }
]

const router = createRouter({
  history: createWebHashHistory(), // Use hash history for easier GitHub Pages deployment
  routes,
})

router.beforeEach(async (to, from, next) => {
  const { data: { session } } = await supabase.auth.getSession()

  if (to.meta.requiresAuth && !session) {
    next('/login')
  } else if (to.path === '/login' && session) {
    next('/dashboard')
  } else {
    next()
  }
})

export default router
