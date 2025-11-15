# ⚡ EASIEST Setup - Run This ONE File

**Problem:** Your Supabase instance doesn't have `pgvector` extension installed.
**Solution:** Use this simplified migration that works WITHOUT vector search.

---

## 🚀 **3-Minute Setup**

### **Step 1: Open Supabase SQL Editor**

1. Go to [Supabase Dashboard](https://supabase.com/dashboard)
2. Select your project: `tqqfeowkzgxmlafltuhp`
3. Click **SQL Editor** in the sidebar

---

### **Step 2: Run ONE File**

Copy the entire contents of this file:
📄 **`database/MIGRATION_NO_VECTOR.sql`**

Paste into SQL Editor and click **Run**

⏱️ **Takes ~10 seconds**

---

### **Step 3: Done! ✅**

You should see: "Setup Complete! 16 tables created"

---

## 🎯 **What Works Without Vector Search?**

### ✅ **All Features Work:**
- AI Onboarding Chat
- Member Directory & Search (text-based)
- Connection Requests
- Real-time Messaging
- Events & RSVP
- Q&A Platform
- Notifications
- Admin Panel

### ⚠️ **What's Disabled:**
- AI Semantic Search (will fall back to text search)
- Vector Similarity Matching (will use basic algorithm)

**Impact:** Minimal! The platform is fully functional. Semantic search is nice-to-have, not essential.

---

## 🔧 **Want to Enable Vector Search Later?**

Contact Supabase support to enable `pgvector` extension on your project.
Once enabled, run the vector migration separately.

---

## 📋 **Next Steps After Migration**

### **1. Add AI Keys** (backend/.env)
```bash
ANTHROPIC_API_KEY=sk-ant-...
OPENAI_API_KEY=sk-...  # Optional if no vector search
```

### **2. Create Storage Buckets**

In Supabase Dashboard → Storage:
- `profile-photos` (public)
- `event-banners` (public)
- `message-attachments` (private)
- `event-photos` (public)

### **3. Start Backend**
```bash
cd backend
npm install
npm run dev
```

### **4. Start Frontend**
```bash
cd frontend
npm install
npm run dev
```

---

## 🎉 **You're Ready!**

Open `http://localhost:5173` and test:
1. Sign up for account
2. Chat with B_AI for onboarding
3. Browse member directory
4. Send connection requests

---

## ❓ **Troubleshooting**

### Still getting errors?

**Clear your database first:**
1. Supabase Dashboard → Database → Schema
2. Drop all tables if any exist
3. Run the migration again

### Need help?

Check `QUICK_START.md` for full setup guide.

---

**Ready to run? Just paste `MIGRATION_NO_VECTOR.sql` and you're done!** 🚀
