# 🚀 Quick Start Guide

Get the Bocconi GCC Alumni Connect platform running in minutes!

---

## ⚡ **Prerequisites**

- Node.js 18+ installed ([Download](https://nodejs.org/))
- Git installed
- Anthropic API key ([Get one](https://console.anthropic.com/))
- OpenAI API key ([Get one](https://platform.openai.com/))

---

## 📦 **Step 1: Database Setup (5 minutes)**

### Go to Supabase Dashboard

Your Supabase project is already configured:
- **URL**: `https://tqqfeowkzgxmlafltuhp.supabase.co`
- **Password**: `PersonaIQ2024!`

### Run Database Migrations

1. Go to your Supabase project dashboard
2. Click **SQL Editor** in the left sidebar
3. Run each migration file in order (copy & paste the contents):

```bash
database/migrations/001_create_users.sql
database/migrations/002_create_profile_relations.sql
database/migrations/003_create_connections_messages.sql
database/migrations/004_create_events.sql
database/migrations/005_create_qa_system.sql
database/migrations/006_create_ai_notifications.sql
database/migrations/007_create_platform_settings.sql
```

4. Click **Run** for each migration

### Get Service Role Key

1. In Supabase Dashboard → **Settings** → **API**
2. Copy the **service_role** key (secret)
3. You'll need this in the next step

---

## 🔑 **Step 2: Configure API Keys**

### Backend Environment Variables

Edit `backend/.env` and add your API keys:

```bash
# Already configured:
SUPABASE_URL=https://tqqfeowkzgxmlafltuhp.supabase.co
SUPABASE_ANON_KEY=eyJhbGc...

# ADD THESE:
SUPABASE_SERVICE_KEY=<paste-your-service-role-key-here>
ANTHROPIC_API_KEY=<paste-your-anthropic-key-here>
OPENAI_API_KEY=<paste-your-openai-key-here>
```

**Optional (for testing paid events):**
```bash
STRIPE_SECRET_KEY=sk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...
```

Frontend is already configured! ✅

---

## 🎬 **Step 3: Install & Run**

### Terminal 1: Start Backend

```bash
cd backend
npm install
npm run dev
```

You should see:
```
🚀 Server running on port 3001 in development mode
📡 Frontend URL: http://localhost:5173
```

### Terminal 2: Start Frontend

```bash
cd frontend
npm install
npm run dev
```

You should see:
```
  VITE v5.0.8  ready in 500 ms

  ➜  Local:   http://localhost:5173/
  ➜  Network: use --host to expose
```

---

## 🎉 **Step 4: Test the Platform**

1. **Open your browser**: `http://localhost:5173`

2. **Sign up for an account**:
   - Click "Sign Up"
   - Enter your email, password, and Bocconi info
   - You'll be redirected to the AI onboarding chat

3. **Test AI Onboarding**:
   - Chat with B_AI to create your profile
   - Answer questions naturally
   - See your profile get auto-generated!

4. **Explore Features**:
   - Browse member directory
   - Search for other alumni
   - Send connection requests
   - Create events
   - Ask questions in Q&A

---

## 🐛 **Troubleshooting**

### Backend won't start?

**Error**: `Missing required environment variable`
- **Fix**: Make sure you added `SUPABASE_SERVICE_KEY`, `ANTHROPIC_API_KEY`, and `OPENAI_API_KEY` in `backend/.env`

**Error**: `EADDRINUSE: address already in use`
- **Fix**: Port 3001 is busy. Kill the process or change `PORT` in `backend/.env`

### Frontend won't start?

**Error**: `Failed to resolve module`
- **Fix**: Run `npm install` in the frontend directory

### AI Onboarding not working?

**Error**: `AI service unavailable`
- **Fix**: Check your Anthropic API key is valid and has credits

### Database errors?

**Error**: `relation "users" does not exist`
- **Fix**: You forgot to run the migrations! Go to Supabase SQL Editor and run all 7 migration files

---

## 📊 **What's Working vs. What's Not**

### ✅ **Fully Functional (Backend)**
- User authentication (signup/login)
- AI onboarding chat
- Member directory & search
- AI-powered matching
- Connection requests
- Messaging API (WebSocket ready)
- Events creation & RSVP
- Q&A platform
- Notifications
- Admin panel

### ⏳ **Placeholder (Frontend UI)**
- Most page components show "To be implemented"
- You'll see the layout and navigation
- Login/Landing pages work
- Full UI needs to be built (that's the next phase!)

---

## 🎯 **Next Steps**

### For Testing API Directly

Use Postman or curl:

```bash
# Sign up
curl -X POST http://localhost:3001/api/auth/signup \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@bocconi.it",
    "password": "password123",
    "full_name": "Test User",
    "graduation_year": 2020,
    "program": "MBA"
  }'

# Login
curl -X POST http://localhost:3001/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@bocconi.it",
    "password": "password123"
  }'
```

See full API docs in `docs/API.md`

### For Building Frontend

The structure is ready! Build the page components:
- `frontend/src/pages/Onboarding.jsx` - AI chat interface
- `frontend/src/pages/MemberDirectory.jsx` - Member cards, filters
- `frontend/src/pages/Messages.jsx` - Chat UI
- etc.

---

## 📚 **Documentation**

- **API Reference**: `docs/API.md`
- **Deployment Guide**: `docs/DEPLOYMENT.md`
- **Database Schema**: `database/README.md`
- **Implementation Summary**: `IMPLEMENTATION_SUMMARY.md`

---

## 💡 **Pro Tips**

1. **Test with real AI**: The onboarding conversation is REALLY conversational. Try it!

2. **Check logs**: Backend logs show all API calls and AI interactions

3. **Supabase Dashboard**: Monitor your database in real-time

4. **Database changes**: If you modify migrations, reset your database:
   - Supabase Dashboard → Database → Migrations → Reset

5. **Hot reload**: Both frontend and backend auto-reload on file changes

---

## 🆘 **Need Help?**

- Check `IMPLEMENTATION_SUMMARY.md` for detailed status
- Review `docs/API.md` for endpoint details
- Look at `backend/src/routes/` for API implementation examples

---

**🎊 You're all set! The backend is production-ready and waiting for you to build the beautiful frontend.**

**Questions or issues?** Check the main README.md or documentation files.
