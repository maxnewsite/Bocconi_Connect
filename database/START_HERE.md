# 🚨 **IMPORTANT: Which Migration File to Use?**

## ⚠️ **Only Run This File:**

```
database/MIGRATION_NO_VECTOR.sql
```

This single file contains the **complete** database setup in the correct order.

---

## ❌ **DO NOT Run These Files:**

### Individual Migration Files (database/migrations/)
```
database/migrations/001_create_users.sql          ❌ Don't use
database/migrations/002_create_profiles.sql       ❌ Don't use
database/migrations/003_create_connections.sql    ❌ Don't use
database/migrations/004_create_events.sql         ❌ Don't use
database/migrations/005_create_qa_system.sql      ❌ Don't use
database/migrations/006_create_ai_notifications.sql ❌ Don't use
database/migrations/007_create_platform_settings.sql ❌ Don't use
```

**Why?** These files:
- Require pgvector extension (not available on your Supabase plan)
- May create triggers before tables exist
- Are designed for development, not production deployment

### Part Files (database/MIGRATION_PART_*.sql)
```
database/MIGRATION_PART_1.sql       ❌ Don't use (requires pgvector)
database/MIGRATION_PART_2.sql       ❌ Don't use (requires pgvector)
database/MIGRATION_PART_3.sql       ❌ Don't use (requires pgvector)
database/MIGRATION_PART_4_FINAL.sql ❌ Don't use (requires pgvector)
```

**Why?** These also require pgvector and create the `profile_embeddings` table.

---

## ✅ **Step-by-Step: Run the Correct Migration**

### **Step 1: Open Supabase SQL Editor**

1. Go to [Supabase Dashboard](https://supabase.com/dashboard/project/tqqfeowkzgxmlafltuhp)
2. Click **SQL Editor** in the left sidebar

### **Step 2: Copy the Migration File**

1. Open `database/MIGRATION_NO_VECTOR.sql` from your project
2. **Copy the entire file contents** (it's ~470 lines)

### **Step 3: Run the Migration**

1. Paste the entire contents into Supabase SQL Editor
2. Click **Run** (or press `Ctrl+Enter`)
3. Wait ~10 seconds for completion

### **Step 4: Verify Success**

You should see output like:
```
status          | tables_created
----------------+--------------
Setup Complete! | 14
```

---

## 🎯 **What Gets Created?**

The `MIGRATION_NO_VECTOR.sql` file creates:

### Tables (14 total)
- ✅ `users` - User profiles
- ✅ `profile_offerings` - What users offer
- ✅ `profile_seeking` - What users seek
- ✅ `connections` - Connection requests
- ✅ `messages` - Direct messaging
- ✅ `events` - Event management
- ✅ `event_rsvps` - Event attendance
- ✅ `event_photos` - Event photo galleries
- ✅ `qa_questions` - Q&A questions
- ✅ `qa_answers` - Q&A answers
- ✅ `qa_votes` - Voting system
- ✅ `user_reputation` - Gamification scores
- ✅ `notifications` - User notifications
- ✅ `platform_settings` - Platform configuration

### What's **NOT** Created (Intentionally)
- ❌ `profile_embeddings` - Requires pgvector
- ❌ `ai_interactions` - Optional AI logging

### Features That Work WITHOUT pgvector
- ✅ User profiles and onboarding
- ✅ Connection matching (uses industry/location instead of vectors)
- ✅ Search (uses text search instead of semantic search)
- ✅ Messaging
- ✅ Events & RSVP
- ✅ Q&A platform
- ✅ Notifications
- ✅ AI conversational onboarding (Claude API)

---

## 🐛 **If You Get Errors:**

### Error: "relation already exists"
**Solution:** Your database already has some tables. You have two options:

**Option A - Reset Database (CAREFUL: Deletes all data)**
1. Supabase Dashboard → **Database** → **Reset Database**
2. Re-run `MIGRATION_NO_VECTOR.sql`

**Option B - Drop Specific Tables**
```sql
-- Copy this into SQL Editor and run BEFORE the migration
DROP TABLE IF EXISTS notifications CASCADE;
DROP TABLE IF EXISTS messages CASCADE;
DROP TABLE IF EXISTS connections CASCADE;
DROP TABLE IF EXISTS qa_votes CASCADE;
DROP TABLE IF EXISTS qa_answers CASCADE;
DROP TABLE IF EXISTS qa_questions CASCADE;
DROP TABLE IF EXISTS user_reputation CASCADE;
DROP TABLE IF EXISTS event_photos CASCADE;
DROP TABLE IF EXISTS event_rsvps CASCADE;
DROP TABLE IF EXISTS events CASCADE;
DROP TABLE IF EXISTS profile_seeking CASCADE;
DROP TABLE IF EXISTS profile_offerings CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS platform_settings CASCADE;
```

### Error: "extension pgvector does not exist"
**You're running the wrong file!** Make sure you're using `MIGRATION_NO_VECTOR.sql`, not the other files.

### Error: "missing FROM-clause entry for table new"
**You're running the wrong file!** Use `MIGRATION_NO_VECTOR.sql` instead.

---

## 📁 **File Reference**

| File | Use? | Notes |
|------|------|-------|
| `MIGRATION_NO_VECTOR.sql` | ✅ **YES** | Production-ready, no pgvector |
| `MIGRATION_PART_*.sql` | ❌ NO | Requires pgvector |
| `migrations/00*.sql` | ❌ NO | Development only |
| `EASY_SETUP.md` | 📖 Read | Setup instructions |
| `RUN_MIGRATIONS.md` | 📖 Read | Alternative instructions (for pgvector version) |
| `START_HERE.md` | 📖 **YOU ARE HERE** | This file |

---

## ✅ **After Migration Succeeds**

Continue with:
1. Add Anthropic API key to `backend/.env`
2. Create storage buckets in Supabase
3. Test backend: `cd backend && npm install && npm run dev`

---

**Need help?** Check `EASY_SETUP.md` for the full deployment guide.
