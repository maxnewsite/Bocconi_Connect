-- =====================================================
-- BOCCONI ALUMNI CONNECT - COMPLETE DATABASE SETUP
-- Version: WITHOUT pgvector (works on all Supabase plans)
-- Run this SINGLE file in Supabase SQL Editor
-- =====================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
-- NOTE: Skipping pgvector - vector search will be disabled

-- =====================================================
-- USERS & PROFILES
-- =====================================================

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

CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_location ON users(location_city, location_country);
CREATE INDEX IF NOT EXISTS idx_users_industry ON users("current_industry");
CREATE INDEX IF NOT EXISTS idx_users_graduation_year ON users(graduation_year);
CREATE INDEX IF NOT EXISTS idx_users_active ON users(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_users_expertise ON users USING GIN(expertise_tags);

ALTER TABLE users ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can view active users" ON users;
CREATE POLICY "Anyone can view active users" ON users FOR SELECT USING (is_active = true);

DROP POLICY IF EXISTS "Users can update own profile" ON users;
CREATE POLICY "Users can update own profile" ON users FOR UPDATE USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can insert own profile" ON users;
CREATE POLICY "Users can insert own profile" ON users FOR INSERT WITH CHECK (auth.uid() = id);

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
   NEW.updated_at = now();
   RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS update_users_updated_at ON users;
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

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
-- CONNECTIONS & MESSAGES
-- =====================================================

CREATE TABLE IF NOT EXISTS connections (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  requester_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  recipient_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'declined')),
  introduction_message TEXT,
  ai_match_score INTEGER CHECK (ai_match_score >= 0 AND ai_match_score <= 100),
  ai_match_reasons JSONB DEFAULT '[]'::jsonb,
  accepted_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  UNIQUE(requester_id, recipient_id),
  CHECK (requester_id != recipient_id)
);

CREATE TABLE IF NOT EXISTS messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  sender_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  recipient_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  content TEXT NOT NULL,
  attachment_url TEXT,
  is_read BOOLEAN DEFAULT false,
  read_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  CHECK (sender_id != recipient_id)
);

CREATE INDEX IF NOT EXISTS idx_connections_requester ON connections(requester_id);
CREATE INDEX IF NOT EXISTS idx_connections_recipient ON connections(recipient_id);
CREATE INDEX IF NOT EXISTS idx_connections_status ON connections(status);
CREATE INDEX IF NOT EXISTS idx_messages_sender ON messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_recipient ON messages(recipient_id);
CREATE INDEX IF NOT EXISTS idx_messages_created ON messages(created_at DESC);

ALTER TABLE connections ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users see own connections" ON connections;
CREATE POLICY "Users see own connections" ON connections FOR SELECT
USING (auth.uid() = requester_id OR auth.uid() = recipient_id);

DROP POLICY IF EXISTS "Users can request connections" ON connections;
CREATE POLICY "Users can request connections" ON connections FOR INSERT WITH CHECK (auth.uid() = requester_id);

DROP POLICY IF EXISTS "Recipients can update connection status" ON connections;
CREATE POLICY "Recipients can update connection status" ON connections FOR UPDATE USING (auth.uid() = recipient_id);

DROP POLICY IF EXISTS "Users see own messages" ON messages;
CREATE POLICY "Users see own messages" ON messages FOR SELECT
USING (auth.uid() = sender_id OR auth.uid() = recipient_id);

DROP POLICY IF EXISTS "Users can send messages if connected" ON messages;
CREATE POLICY "Users can send messages if connected" ON messages FOR INSERT
WITH CHECK (
  auth.uid() = sender_id AND
  EXISTS (
    SELECT 1 FROM connections
    WHERE status = 'accepted'
    AND ((connections.requester_id = auth.uid() AND connections.recipient_id = messages.recipient_id)
      OR (connections.recipient_id = auth.uid() AND connections.requester_id = messages.recipient_id))
  )
);

DROP POLICY IF EXISTS "Users can update own sent messages" ON messages;
CREATE POLICY "Users can update own sent messages" ON messages FOR UPDATE
USING (auth.uid() = sender_id OR auth.uid() = recipient_id);

CREATE OR REPLACE FUNCTION set_accepted_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'accepted' AND OLD.status != 'accepted' THEN
    NEW.accepted_at = now();
  END IF;
  RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS connection_accepted_timestamp ON connections;
CREATE TRIGGER connection_accepted_timestamp BEFORE UPDATE ON connections FOR EACH ROW EXECUTE FUNCTION set_accepted_timestamp();

-- =====================================================
-- EVENTS
-- =====================================================

CREATE TABLE IF NOT EXISTS events (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  organizer_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  event_type TEXT NOT NULL CHECK (event_type IN ('professional', 'social', 'educational', 'investment')),
  start_date TIMESTAMP WITH TIME ZONE NOT NULL,
  end_date TIMESTAMP WITH TIME ZONE,
  location_name TEXT,
  location_address TEXT,
  is_virtual BOOLEAN DEFAULT false,
  virtual_link TEXT,
  banner_image_url TEXT,
  capacity INTEGER CHECK (capacity > 0),
  is_paid BOOLEAN DEFAULT false,
  price_amount DECIMAL(10,2) CHECK (price_amount >= 0),
  price_currency TEXT DEFAULT 'AED',
  stripe_product_id TEXT,
  requires_rsvp BOOLEAN DEFAULT true,
  rsvp_deadline TIMESTAMP WITH TIME ZONE,
  is_published BOOLEAN DEFAULT false,
  is_featured BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

CREATE TABLE IF NOT EXISTS event_rsvps (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  event_id UUID REFERENCES events(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  status TEXT DEFAULT 'attending' CHECK (status IN ('attending', 'waitlist', 'cancelled')),
  payment_status TEXT CHECK (payment_status IN ('paid', 'pending', 'free')),
  payment_amount DECIMAL(10,2),
  stripe_payment_id TEXT,
  qr_code TEXT NOT NULL,
  checked_in BOOLEAN DEFAULT false,
  checked_in_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  UNIQUE(event_id, user_id)
);

CREATE TABLE IF NOT EXISTS event_photos (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  event_id UUID REFERENCES events(id) ON DELETE CASCADE NOT NULL,
  uploaded_by UUID REFERENCES users(id),
  photo_url TEXT NOT NULL,
  caption TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_events_organizer ON events(organizer_id);
CREATE INDEX IF NOT EXISTS idx_events_start_date ON events(start_date);
CREATE INDEX IF NOT EXISTS idx_events_published ON events(is_published, start_date) WHERE is_published = true;

ALTER TABLE events ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_rsvps ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_photos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can view published events" ON events;
CREATE POLICY "Anyone can view published events" ON events FOR SELECT USING (is_published = true);

DROP POLICY IF EXISTS "Organizers manage own events" ON events;
CREATE POLICY "Organizers manage own events" ON events FOR ALL USING (auth.uid() = organizer_id);

DROP POLICY IF EXISTS "Anyone can view RSVPs" ON event_rsvps;
CREATE POLICY "Anyone can view RSVPs" ON event_rsvps FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can RSVP to events" ON event_rsvps;
CREATE POLICY "Users can RSVP to events" ON event_rsvps FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users manage own RSVPs" ON event_rsvps;
CREATE POLICY "Users manage own RSVPs" ON event_rsvps FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Anyone can view event photos" ON event_photos;
CREATE POLICY "Anyone can view event photos" ON event_photos FOR SELECT USING (true);

DROP POLICY IF EXISTS "Authenticated users can upload photos" ON event_photos;
CREATE POLICY "Authenticated users can upload photos" ON event_photos FOR INSERT WITH CHECK (auth.uid() = uploaded_by);

DROP TRIGGER IF EXISTS update_events_updated_at ON events;
CREATE TRIGGER update_events_updated_at BEFORE UPDATE ON events FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- Q&A SYSTEM
-- =====================================================

CREATE TABLE IF NOT EXISTS qa_questions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  asker_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  category TEXT NOT NULL,
  tags TEXT[] DEFAULT ARRAY[]::TEXT[],
  is_anonymous BOOLEAN DEFAULT false,
  view_count INTEGER DEFAULT 0,
  upvotes INTEGER DEFAULT 0,
  downvotes INTEGER DEFAULT 0,
  has_accepted_answer BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

CREATE TABLE IF NOT EXISTS qa_answers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  question_id UUID REFERENCES qa_questions(id) ON DELETE CASCADE NOT NULL,
  answerer_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  content TEXT NOT NULL,
  upvotes INTEGER DEFAULT 0,
  downvotes INTEGER DEFAULT 0,
  is_accepted BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

CREATE TABLE IF NOT EXISTS qa_votes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  votable_type TEXT NOT NULL CHECK (votable_type IN ('question', 'answer')),
  votable_id UUID NOT NULL,
  vote_type TEXT NOT NULL CHECK (vote_type IN ('upvote', 'downvote')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  UNIQUE(user_id, votable_type, votable_id)
);

CREATE TABLE IF NOT EXISTS user_reputation (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE UNIQUE NOT NULL,
  total_points INTEGER DEFAULT 0,
  questions_asked INTEGER DEFAULT 0,
  answers_given INTEGER DEFAULT 0,
  accepted_answers INTEGER DEFAULT 0,
  badge_level TEXT DEFAULT 'bronze',
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

ALTER TABLE qa_questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE qa_answers ENABLE ROW LEVEL SECURITY;
ALTER TABLE qa_votes ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_reputation ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can view questions" ON qa_questions;
CREATE POLICY "Anyone can view questions" ON qa_questions FOR SELECT USING (true);

DROP POLICY IF EXISTS "Authenticated users can ask" ON qa_questions;
CREATE POLICY "Authenticated users can ask" ON qa_questions FOR INSERT WITH CHECK (auth.uid() = asker_id);

DROP POLICY IF EXISTS "Anyone can view answers" ON qa_answers;
CREATE POLICY "Anyone can view answers" ON qa_answers FOR SELECT USING (true);

DROP POLICY IF EXISTS "Authenticated users can answer" ON qa_answers;
CREATE POLICY "Authenticated users can answer" ON qa_answers FOR INSERT WITH CHECK (auth.uid() = answerer_id);

DROP POLICY IF EXISTS "Authenticated users can vote" ON qa_votes;
CREATE POLICY "Authenticated users can vote" ON qa_votes FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Anyone can view reputation" ON user_reputation;
CREATE POLICY "Anyone can view reputation" ON user_reputation FOR SELECT USING (true);

-- =====================================================
-- AI & NOTIFICATIONS
-- =====================================================

-- NOTE: Skipping profile_embeddings table (requires pgvector)
-- Vector search will not be available, but text search will work

CREATE TABLE IF NOT EXISTS ai_interactions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  interaction_type TEXT NOT NULL,
  prompt TEXT,
  response TEXT,
  model_used TEXT,
  tokens_used INTEGER,
  cost_usd DECIMAL(10,4),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  type TEXT NOT NULL,
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  link_url TEXT,
  is_read BOOLEAN DEFAULT false,
  read_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_unread ON notifications(user_id, is_read) WHERE is_read = false;

ALTER TABLE ai_interactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users see own notifications" ON notifications;
CREATE POLICY "Users see own notifications" ON notifications FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users update own notifications" ON notifications;
CREATE POLICY "Users update own notifications" ON notifications FOR UPDATE USING (auth.uid() = user_id);

-- Notification helper function
CREATE OR REPLACE FUNCTION create_notification(
  p_user_id UUID,
  p_type TEXT,
  p_title TEXT,
  p_message TEXT,
  p_link_url TEXT DEFAULT NULL
)
RETURNS UUID LANGUAGE plpgsql AS $$
DECLARE notification_id UUID;
BEGIN
  INSERT INTO notifications (user_id, type, title, message, link_url)
  VALUES (p_user_id, p_type, p_title, p_message, p_link_url)
  RETURNING id INTO notification_id;
  RETURN notification_id;
END;
$$;

-- Auto-notification triggers
CREATE OR REPLACE FUNCTION notify_connection_request() RETURNS TRIGGER AS $$
DECLARE requester_name TEXT;
BEGIN
  SELECT full_name INTO requester_name FROM users WHERE id = NEW.requester_id;
  PERFORM create_notification(NEW.recipient_id, 'connection_request', 'New Connection Request', requester_name || ' wants to connect', '/connections/pending');
  RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS connection_request_notification ON connections;
CREATE TRIGGER connection_request_notification AFTER INSERT ON connections FOR EACH ROW EXECUTE FUNCTION notify_connection_request();

CREATE OR REPLACE FUNCTION notify_new_message() RETURNS TRIGGER AS $$
DECLARE sender_name TEXT;
BEGIN
  SELECT full_name INTO sender_name FROM users WHERE id = NEW.sender_id;
  PERFORM create_notification(NEW.recipient_id, 'new_message', 'New Message', 'You have a new message from ' || sender_name, '/messages');
  RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS new_message_notification ON messages;
CREATE TRIGGER new_message_notification AFTER INSERT ON messages FOR EACH ROW EXECUTE FUNCTION notify_new_message();

-- =====================================================
-- PLATFORM SETTINGS
-- =====================================================

CREATE TABLE IF NOT EXISTS platform_settings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  key TEXT UNIQUE NOT NULL,
  value JSONB NOT NULL,
  description TEXT,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

ALTER TABLE platform_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can view settings" ON platform_settings;
CREATE POLICY "Anyone can view settings" ON platform_settings FOR SELECT USING (true);

INSERT INTO platform_settings (key, value, description) VALUES
('platform_name', '"Bocconi GCC Alumni Connect"', 'Platform display name'),
('max_file_upload_mb', '10', 'Maximum file upload size in MB'),
('ai_models', '{"primary": "claude-sonnet-4-20250514", "embeddings": "disabled"}', 'AI models configuration'),
('feature_flags', '{"qa_enabled": true, "events_enabled": true, "messaging_enabled": true, "vector_search_enabled": false}', 'Feature toggles')
ON CONFLICT (key) DO NOTHING;

-- =====================================================
-- 🎉 SUCCESS! Database Setup Complete (Without Vector Search)
-- =====================================================

SELECT 'Setup Complete!' as status, COUNT(*) as tables_created
FROM information_schema.tables
WHERE table_schema = 'public' AND table_type = 'BASE TABLE';
