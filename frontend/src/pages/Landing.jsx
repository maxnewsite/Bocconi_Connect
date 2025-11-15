import { useNavigate } from 'react-router-dom'
import { useAuth } from '../contexts/AuthContext'
import { useEffect } from 'react'

export default function Landing() {
  const navigate = useNavigate()
  const { isAuthenticated } = useAuth()

  useEffect(() => {
    if (isAuthenticated) {
      navigate('/dashboard')
    }
  }, [isAuthenticated, navigate])

  return (
    <div className="min-h-screen bg-gradient-to-br from-bocconi-blue to-blue-900">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        <div className="text-center text-white">
          <h1 className="text-5xl font-bold mb-4">Bocconi GCC Alumni Connect</h1>
          <p className="text-xl mb-8">Connect, collaborate, and grow with fellow Bocconi alumni in the GCC</p>
          <div className="space-x-4">
            <button onClick={() => navigate('/login')} className="btn-primary bg-white text-bocconi-blue hover:bg-gray-100">
              Log In
            </button>
            <button onClick={() => navigate('/signup')} className="btn-secondary bg-bocconi-gold text-white hover:bg-yellow-600">
              Sign Up
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}
