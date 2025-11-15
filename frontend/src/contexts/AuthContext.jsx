import { createContext, useContext, useState, useEffect } from 'react'
import { supabase } from '../services/supabase'
import { authAPI } from '../services/api'
import toast from 'react-hot-toast'

const AuthContext = createContext({})

export const useAuth = () => {
  const context = useContext(AuthContext)
  if (!context) {
    throw new Error('useAuth must be used within AuthProvider')
  }
  return context
}

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null)
  const [session, setSession] = useState(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    // Check active session
    supabase.auth.getSession().then(({ data: { session } }) => {
      setSession(session)
      if (session) {
        fetchUser()
      } else {
        setLoading(false)
      }
    })

    // Listen for auth changes
    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((_event, session) => {
      setSession(session)
      if (session) {
        fetchUser()
      } else {
        setUser(null)
        setLoading(false)
      }
    })

    return () => subscription.unsubscribe()
  }, [])

  const fetchUser = async () => {
    try {
      const { data } = await authAPI.me()
      setUser(data)
    } catch (error) {
      console.error('Failed to fetch user:', error)
      setUser(null)
    } finally {
      setLoading(false)
    }
  }

  const signup = async (email, password, userData) => {
    try {
      const { data } = await authAPI.signup({
        email,
        password,
        ...userData,
      })

      setSession(data.session)
      setUser(data.user)
      toast.success('Account created successfully!')

      return { data, error: null }
    } catch (error) {
      toast.error(error.message)
      return { data: null, error }
    }
  }

  const login = async (email, password) => {
    try {
      const { data } = await authAPI.login({ email, password })

      setSession(data.session)
      setUser(data.user)
      toast.success('Welcome back!')

      return { data, error: null }
    } catch (error) {
      toast.error(error.message)
      return { data: null, error }
    }
  }

  const logout = async () => {
    try {
      await authAPI.logout()
      await supabase.auth.signOut()

      setSession(null)
      setUser(null)
      toast.success('Logged out successfully')
    } catch (error) {
      toast.error('Failed to logout')
    }
  }

  const updateUser = (userData) => {
    setUser((prev) => ({ ...prev, ...userData }))
  }

  const value = {
    user,
    session,
    loading,
    signup,
    login,
    logout,
    updateUser,
    isAuthenticated: !!session,
    isOnboarded: user?.onboarding_completed || false,
  }

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}
