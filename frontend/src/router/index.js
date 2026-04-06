import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const routes = [
  {
    path: '/login',
    name: 'Login',
    component: () => import('@/views/LoginView.vue'),
    meta: { public: true }
  },
  {
    path: '/',
    component: () => import('@/layouts/AppLayout.vue'),
    children: [
      {
        path: '',
        redirect: '/tasks'
      },
      {
        path: 'tasks',
        name: 'Tasks',
        component: () => import('@/views/TaskListView.vue')
      },
      {
        path: 'email/:id',
        name: 'Email',
        component: () => import('@/views/EmailView.vue')
      },
      {
        path: 'backoffice',
        name: 'BackOffice',
        component: () => import('@/views/BackOfficeView.vue')
      },
      {
        path: 'calendar',
        name: 'Calendar',
        component: () => import('@/views/CalendarView.vue')
      },
      {
        path: 'contacts',
        name: 'Contacts',
        component: () => import('@/views/ContactsView.vue')
      },
      {
        path: 'contacts/:id',
        name: 'Contact',
        component: () => import('@/views/ContactView.vue')
      },
      {
        path: 'skills',
        name: 'Skills',
        component: () => import('@/views/SkillsView.vue')
      },
      {
        path: 'settings',
        name: 'Settings',
        component: () => import('@/views/SettingsView.vue')
      },
      {
        path: 'search',
        name: 'search',
        component: () => import('@/views/SearchView.vue')
      }
    ]
  }
]

const router = createRouter({
  history: createWebHistory(),
  routes
})

router.beforeEach((to) => {
  const auth = useAuthStore()
  if (!to.meta.public && !auth.token) {
    return '/login'
  }
})

export default router
