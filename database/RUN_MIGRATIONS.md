# 🚀 Run Database Migrations - Easy Guide

**Fixed:** PostgreSQL reserved keyword errors resolved!

---

## ✅ **Quick Setup (4 Steps)**

### **Step 1: Go to Supabase**

1. Open [Supabase Dashboard](https://supabase.com/dashboard)
2. Select your project: `tqqfeowkzgxmlafltuhp`
3. Click **SQL Editor** in the left sidebar

---

### **Step 2: Run Migrations in Order**

Copy and paste each file into the SQL Editor and click **Run**:

#### **Part 1: Core Tables** (Users, Profiles)
- File: `MIGRATION_PART_1.sql`
- Tables: `users`, `profile_offerings`, `profile_seeking`
- Time: ~5 seconds

#### **Part 2: Social Features** (Connections, Messages, Events)
- File: `MIGRATION_PART_2.sql`
- Tables: `connections`, `messages`, `events`, `event_rsvps`, `event_photos`
- Time: ~10 seconds

#### **Part 3: Q&A Platform**
- File: `MIGRATION_PART_3.sql`
- Tables: `qa_questions`, `qa_answers`, `qa_votes`, `user_reputation`
- Time: ~10 seconds

#### **Part 4: AI & Settings** (Final)
- File: `MIGRATION_PART_4_FINAL.sql`
- Tables: `profile_embeddings`, `ai_interactions`, `notifications`, `platform_settings`
- Time: ~10 seconds

---

### **Step 3: Verify Success**

After running Part 4, you should see a verification query result showing:

```
Users          | 0
Connections    | 0
Messages       | 0
Events         | 0
Q&A Questions  | 0
Notifications  | 0
Settings       | 8
```

The `Settings` row should show **8** - these are pre-configured platform settings!

---

### **Step 4: Create Storage Buckets**

1. In Supabase Dashboard → **Storage**
2. Create these buckets:

| Bucket Name | Public? | Description |
|-------------|---------|-------------|
| `profile-photos` | ✅ Yes | User profile pictures |
| `event-banners` | ✅ Yes | Event banner images |
| `message-attachments` | ❌ No | Private file attachments |
| `event-photos` | ✅ Yes | Event photo galleries |

---

## 🎉 **Done!**

Your database is ready. Now you can:

1. Start the backend: `cd backend && npm run dev`
2. Test API endpoints
3. Create your first user!

---

## 🐛 **Troubleshooting**

### Error: "extension pgvector does not exist"

**Solution:** The extension might not be available. You can skip it for now and the platform will work without vector search.

Comment out this line in `MIGRATION_PART_1.sql`:
```sql
-- CREATE EXTENSION IF NOT EXISTS "pgvector";
```

### Error: "permission denied"

**Solution:** Make sure you're using the correct Supabase service role key.

### Want to start fresh?

1. Go to Database → Migrations
2. Click "Reset database"
3. Re-run all 4 migration files

---

## 📊 **What Got Created**

- **17 Tables** with full functionality
- **Row Level Security** on all tables
- **50+ Indexes** for performance
- **20+ Triggers** for automation
- **Notification system** ready
- **AI embeddings** support (if pgvector available)
- **Q&A reputation** system
- **Event management** with QR codes

---

## ✅ **Fixes Applied**

**Problem:** PostgreSQL reserved keywords (`current_role`, etc.)
**Solution:** Wrapped in double quotes: `"current_role"`

All migrations now use proper escaping!

---

**Need help?** Check the main documentation or create an issue.
