-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgvector";

-- Create users table
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email TEXT UNIQUE NOT NULL,
  linkedin_id TEXT UNIQUE,
  full_name TEXT NOT NULL,
  graduation_year INTEGER NOT NULL CHECK (graduation_year >= 1940 AND graduation_year <= EXTRACT(YEAR FROM CURRENT_DATE) + 5),
  program TEXT NOT NULL,
  profile_photo_url TEXT,
  tagline TEXT,
  current_role TEXT,
  current_company TEXT,
  current_industry TEXT,
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

-- Create indexes for performance
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_location ON users(location_city, location_country);
CREATE INDEX idx_users_industry ON users(current_industry);
CREATE INDEX idx_users_graduation_year ON users(graduation_year);
CREATE INDEX idx_users_active ON users(is_active) WHERE is_active = true;
CREATE INDEX idx_users_expertise ON users USING GIN(expertise_tags);

-- Enable Row Level Security
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Anyone can view active users"
ON users FOR SELECT
USING (is_active = true);

CREATE POLICY "Users can update own profile"
ON users FOR UPDATE
USING (auth.uid() = id);

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

-- Trigger to auto-update updated_at
CREATE TRIGGER update_users_updated_at
BEFORE UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- Comments for documentation
COMMENT ON TABLE users IS 'Main users table for Bocconi alumni profiles';
COMMENT ON COLUMN users.onboarding_chat_history IS 'Stores the full AI onboarding conversation history';
COMMENT ON COLUMN users.passions IS 'JSON array of personal interests and hobbies';
COMMENT ON COLUMN users.expertise_tags IS 'Array of professional skills and expertise areas';
