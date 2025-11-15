import axios from 'axios'
import { supabase } from './supabase'

const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:3001'

// Create axios instance
const api = axios.create({
  baseURL: `${API_URL}/api`,
  headers: {
    'Content-Type': 'application/json',
  },
})

// Request interceptor to add auth token
api.interceptors.request.use(
  async (config) => {
    const { data: { session } } = await supabase.auth.getSession()

    if (session?.access_token) {
      config.headers.Authorization = `Bearer ${session.access_token}`
    }

    return config
  },
  (error) => Promise.reject(error)
)

// Response interceptor for error handling
api.interceptors.response.use(
  (response) => response.data,
  (error) => {
    const message = error.response?.data?.error?.message || error.message || 'An error occurred'
    return Promise.reject(new Error(message))
  }
)

// API service methods
export const authAPI = {
  signup: (data) => api.post('/auth/signup', data),
  login: (data) => api.post('/auth/login', data),
  logout: () => api.post('/auth/logout'),
  me: () => api.get('/auth/me'),
}

export const onboardingAPI = {
  start: () => api.post('/onboarding/start'),
  chat: (message) => api.post('/onboarding/chat', { message }),
  extractProfile: () => api.post('/onboarding/extract-profile'),
  saveProfile: (data) => api.post('/onboarding/save-profile', data),
  resume: () => api.get('/onboarding/resume'),
}

export const membersAPI = {
  getAll: (params) => api.get('/members', { params }),
  getById: (id) => api.get(`/users/profile/${id}`),
  search: (q, limit) => api.get('/members/search/semantic', { params: { q, limit } }),
  suggestions: (limit) => api.get('/members/suggestions', { params: { limit } }),
  filters: () => api.get('/members/filters'),
}

export const connectionsAPI = {
  request: (data) => api.post('/connections/request', data),
  accept: (id) => api.post(`/connections/${id}/accept`),
  decline: (id) => api.post(`/connections/${id}/decline`),
  getPending: () => api.get('/connections/pending'),
  getAll: () => api.get('/connections'),
  draftMessage: (recipientId) => api.post('/connections/draft-message', { recipient_id: recipientId }),
  remove: (id) => api.delete(`/connections/${id}`),
}

export const messagesAPI = {
  getConversations: () => api.get('/messages/conversations'),
  getMessages: (userId, params) => api.get(`/messages/${userId}`, { params }),
  send: (data) => api.post('/messages/send', data),
  enhance: (message, context) => api.post('/messages/enhance', { message, context }),
  markRead: (id) => api.put(`/messages/${id}/read`),
  unreadCount: () => api.get('/messages/unread/count'),
}

export const eventsAPI = {
  getAll: (params) => api.get('/events', { params }),
  getById: (id) => api.get(`/events/${id}`),
  create: (data) => api.post('/events', data),
  update: (id, data) => api.put(`/events/${id}`, data),
  rsvp: (id) => api.post(`/events/${id}/rsvp`),
  cancelRsvp: (id) => api.delete(`/events/${id}/rsvp`),
  myEvents: () => api.get('/events/my/attending'),
}

export const qaAPI = {
  getQuestions: (params) => api.get('/qa/questions', { params }),
  getQuestion: (id) => api.get(`/qa/questions/${id}`),
  askQuestion: (data) => api.post('/qa/questions', data),
  answerQuestion: (id, content) => api.post(`/qa/questions/${id}/answers`, { content }),
  acceptAnswer: (id) => api.post(`/qa/answers/${id}/accept`),
  vote: (data) => api.post('/qa/vote', data),
  leaderboard: (limit) => api.get('/qa/leaderboard', { params: { limit } }),
}

export const notificationsAPI = {
  getAll: (params) => api.get('/notifications', { params }),
  markRead: (id) => api.put(`/notifications/${id}/read`),
  markAllRead: () => api.put('/notifications/read-all'),
  delete: (id) => api.delete(`/notifications/${id}`),
  unreadCount: () => api.get('/notifications/unread/count'),
}

export const aiAPI = {
  quickAsk: (question) => api.post('/ai/quick-ask', { question }),
  suggestTags: (title, description) => api.post('/ai/suggest-tags', { title, description }),
}

export default api
