# Database Setup Guide

This directory contains all Supabase database migrations for the Bocconi GCC Alumni Connect platform.

## Prerequisites

- Supabase account and project created
- Supabase CLI installed (`npm install -g supabase`)
- Database credentials from your Supabase project

## Running Migrations

### Option 1: Manual Execution (Recommended for First Setup)

1. Go to your Supabase project dashboard
2. Navigate to **SQL Editor**
3. Execute each migration file in order:
   - `001_create_users.sql`
   - `002_create_profile_relations.sql`
   - `003_create_connections_messages.sql`
   - `004_create_events.sql`
   - `005_create_qa_system.sql`
   - `006_create_ai_notifications.sql`
   - `007_create_platform_settings.sql`

### Option 2: Using Supabase CLI

```bash
# Login to Supabase
supabase login

# Link to your project
supabase link --project-ref your-project-ref

# Push migrations
supabase db push
```

## Database Schema Overview

### Core Tables

- **users**: Alumni profiles with authentication
- **profile_offerings**: What users can offer (mentorship, jobs, etc.)
- **profile_seeking**: What users are looking for
- **connections**: Network connections between users
- **messages**: Direct messaging between connected users

### Features

- **events**: Event management with RSVPs
- **event_rsvps**: Attendance tracking
- **event_photos**: Post-event photo galleries
- **qa_questions**: Community Q&A questions
- **qa_answers**: Answers to questions
- **qa_votes**: Voting system for Q&A
- **user_reputation**: Gamification and reputation tracking

### AI & System

- **profile_embeddings**: Vector embeddings for AI matching
- **ai_interactions**: Log of AI usage for analytics
- **notifications**: Real-time user notifications
- **platform_settings**: Configurable platform settings

## Key Features

### Row Level Security (RLS)
All tables have RLS enabled with appropriate policies to ensure data security.

### Vector Search
Uses `pgvector` extension for semantic search and AI-powered matching.

### Automated Triggers
- Auto-update timestamps
- Automatic notification creation
- Vote count updates
- Reputation calculation

### Helper Functions
- `match_profiles()`: Find similar users using vector search
- `get_setting()`: Retrieve platform configuration
- `create_notification()`: Create notifications programmatically

## Seeding Test Data

For development, you can run seed scripts (coming soon in `seeds/` directory).

## Backup & Restore

```bash
# Backup
supabase db dump -f backup.sql

# Restore
psql -h your-host -U postgres -d postgres -f backup.sql
```

## Storage Buckets

Create these buckets in Supabase Storage dashboard:

1. **profile-photos** (public)
2. **event-banners** (public)
3. **message-attachments** (private)
4. **event-photos** (public)

### Storage RLS Policies

Apply appropriate RLS policies for each bucket to control access.

## Environment Variables

Ensure your backend `.env` file has these Supabase credentials:

```
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_KEY=your-service-role-key
```

## Monitoring

Use Supabase dashboard to monitor:
- Query performance
- Table sizes
- Index usage
- API usage

## Troubleshooting

### pgvector Extension Not Found
```sql
CREATE EXTENSION IF NOT EXISTS "pgvector";
```

### Permission Errors
Ensure you're using the correct Supabase credentials with sufficient permissions.

### Migration Errors
Run migrations in order. If a migration fails, fix the issue and re-run from that point.

## Security Checklist

- ✅ RLS enabled on all tables
- ✅ Proper authentication checks
- ✅ Input validation in CHECK constraints
- ✅ Foreign key cascades configured
- ✅ Sensitive fields protected
- ✅ Service role key never exposed to frontend

---

For more details, see the main project README.
