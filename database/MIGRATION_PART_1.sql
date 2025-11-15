-- =====================================================
-- BOCCONI ALUMNI CONNECT - DATABASE SETUP
-- Run these migrations IN ORDER in Supabase SQL Editor
-- =====================================================

-- =====================================================
-- MIGRATION 001: Users Table & Extensions
-- =====================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgvector";

-- Create users table
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email TEXT UNIQUE NOT NULL,
  linkedin_id TEXT UNIQUE,
  full_name TEXT NOT NULL,
  graduation_year INTEGER NOT NULL CHECK (graduation_year >= 1940 AND graduation_year <= EXTRACT(YEAR FROM CURRENT_DATE) + 5),
  program TEXT NOT NULL,
  profile_photo_url TEXT,
  tagline TEXT,
  "current_role" TEXT,
  "current_company" TEXT,
  "current_industry" TEXT,
  location_city TEXT,
  location_country TEXT,
  bio TEXT,
  passions JSONB DEFAULT '[]'::jsonb,
  expertise_tags TEXT[] DEFAULT ARRAY[]::TEXT[],
  linkedin_url TEXT,
  phone TEXT,
  onboarding_completed BOOLEAN DEFAULT false,
  onboarding_chat_history JSONB DEFAULT '[]'::jsonb,
  is_admin BOOLEAN DEFAULT false,
  is_active BOOLEAN DEFAULT true,
  last_active_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_location ON users(location_city, location_country);
CREATE INDEX IF NOT EXISTS idx_users_industry ON users("current_industry");
CREATE INDEX IF NOT EXISTS idx_users_graduation_year ON users(graduation_year);
CREATE INDEX IF NOT EXISTS idx_users_active ON users(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_users_expertise ON users USING GIN(expertise_tags);

-- Enable RLS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- RLS Policies
DROP POLICY IF EXISTS "Anyone can view active users" ON users;
CREATE POLICY "Anyone can view active users"
ON users FOR SELECT
USING (is_active = true);

DROP POLICY IF EXISTS "Users can update own profile" ON users;
CREATE POLICY "Users can update own profile"
ON users FOR UPDATE
USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can insert own profile" ON users;
CREATE POLICY "Users can insert own profile"
ON users FOR INSERT
WITH CHECK (auth.uid() = id);

-- Auto-update timestamp function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
   NEW.updated_at = now();
   RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger
DROP TRIGGER IF EXISTS update_users_updated_at ON users;
CREATE TRIGGER update_users_updated_at
BEFORE UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- MIGRATION 002: Profile Relations
-- =====================================================

CREATE TABLE IF NOT EXISTS profile_offerings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  offering_type TEXT NOT NULL CHECK (offering_type IN ('mentorship', 'job_opportunities', 'investment', 'advice', 'connections')),
  description TEXT,
  time_commitment TEXT CHECK (time_commitment IN ('one-time', 'monthly', 'ongoing', 'project-based')),
  specific_domains TEXT[] DEFAULT ARRAY[]::TEXT[],
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

CREATE TABLE IF NOT EXISTS profile_seeking (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  seeking_type TEXT NOT NULL CHECK (seeking_type IN ('mentorship', 'job_opportunities', 'investment', 'partnerships', 'learning')),
  description TEXT,
  time_commitment TEXT CHECK (time_commitment IN ('one-time', 'monthly', 'ongoing', 'project-based')),
  specific_domains TEXT[] DEFAULT ARRAY[]::TEXT[],
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_offerings_user ON profile_offerings(user_id);
CREATE INDEX IF NOT EXISTS idx_offerings_type ON profile_offerings(offering_type);
CREATE INDEX IF NOT EXISTS idx_seeking_user ON profile_seeking(user_id);
CREATE INDEX IF NOT EXISTS idx_seeking_type ON profile_seeking(seeking_type);

ALTER TABLE profile_offerings ENABLE ROW LEVEL SECURITY;
ALTER TABLE profile_seeking ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can view offerings" ON profile_offerings;
CREATE POLICY "Anyone can view offerings" ON profile_offerings FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users manage own offerings" ON profile_offerings;
CREATE POLICY "Users manage own offerings" ON profile_offerings FOR ALL USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Anyone can view seeking" ON profile_seeking;
CREATE POLICY "Anyone can view seeking" ON profile_seeking FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users manage own seeking" ON profile_seeking;
CREATE POLICY "Users manage own seeking" ON profile_seeking FOR ALL USING (auth.uid() = user_id);

-- =====================================================
-- SUCCESS! Migrations 001-002 Complete
-- Continue with migrations 003-007 in separate batches
-- =====================================================
