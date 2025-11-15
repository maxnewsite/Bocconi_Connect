-- =====================================================
-- BOCCONI ALUMNI CONNECT - DATABASE SETUP PART 2
-- Run AFTER Part 1 completes successfully
-- =====================================================

-- =====================================================
-- MIGRATION 003: Connections & Messages
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

-- Indexes
CREATE INDEX IF NOT EXISTS idx_connections_requester ON connections(requester_id);
CREATE INDEX IF NOT EXISTS idx_connections_recipient ON connections(recipient_id);
CREATE INDEX IF NOT EXISTS idx_connections_status ON connections(status);
CREATE INDEX IF NOT EXISTS idx_messages_sender ON messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_recipient ON messages(recipient_id);
CREATE INDEX IF NOT EXISTS idx_messages_created ON messages(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_conversation ON messages(sender_id, recipient_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_unread ON messages(recipient_id, is_read) WHERE is_read = false;

-- RLS
ALTER TABLE connections ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- Connection policies
DROP POLICY IF EXISTS "Users see own connections" ON connections;
CREATE POLICY "Users see own connections" ON connections FOR SELECT
USING (auth.uid() = requester_id OR auth.uid() = recipient_id);

DROP POLICY IF EXISTS "Users can request connections" ON connections;
CREATE POLICY "Users can request connections" ON connections FOR INSERT
WITH CHECK (auth.uid() = requester_id);

DROP POLICY IF EXISTS "Recipients can update connection status" ON connections;
CREATE POLICY "Recipients can update connection status" ON connections FOR UPDATE
USING (auth.uid() = recipient_id);

-- Message policies
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
    AND ((requester_id = auth.uid() AND recipient_id = NEW.recipient_id)
      OR (recipient_id = auth.uid() AND requester_id = NEW.recipient_id))
  )
);

DROP POLICY IF EXISTS "Users can update own sent messages" ON messages;
CREATE POLICY "Users can update own sent messages" ON messages FOR UPDATE
USING (auth.uid() = sender_id OR auth.uid() = recipient_id);

-- Triggers
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
CREATE TRIGGER connection_accepted_timestamp
BEFORE UPDATE ON connections
FOR EACH ROW
EXECUTE FUNCTION set_accepted_timestamp();

-- =====================================================
-- MIGRATION 004: Events
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
  location_coordinates POINT,
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
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  CHECK (end_date IS NULL OR end_date > start_date),
  CHECK (NOT is_paid OR (price_amount IS NOT NULL AND price_amount > 0))
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

-- Indexes
CREATE INDEX IF NOT EXISTS idx_events_organizer ON events(organizer_id);
CREATE INDEX IF NOT EXISTS idx_events_start_date ON events(start_date);
CREATE INDEX IF NOT EXISTS idx_events_published ON events(is_published, start_date) WHERE is_published = true;
CREATE INDEX IF NOT EXISTS idx_events_type ON events(event_type);
CREATE INDEX IF NOT EXISTS idx_events_featured ON events(is_featured) WHERE is_featured = true;
CREATE INDEX IF NOT EXISTS idx_rsvps_event ON event_rsvps(event_id);
CREATE INDEX IF NOT EXISTS idx_rsvps_user ON event_rsvps(user_id);
CREATE INDEX IF NOT EXISTS idx_rsvps_status ON event_rsvps(status);
CREATE INDEX IF NOT EXISTS idx_event_photos_event ON event_photos(event_id);

-- RLS
ALTER TABLE events ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_rsvps ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_photos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can view published events" ON events;
CREATE POLICY "Anyone can view published events" ON events FOR SELECT
USING (is_published = true);

DROP POLICY IF EXISTS "Organizers manage own events" ON events;
CREATE POLICY "Organizers manage own events" ON events FOR ALL
USING (auth.uid() = organizer_id);

DROP POLICY IF EXISTS "Admins can manage all events" ON events;
CREATE POLICY "Admins can manage all events" ON events FOR ALL
USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true));

DROP POLICY IF EXISTS "Anyone can view RSVPs" ON event_rsvps;
CREATE POLICY "Anyone can view RSVPs" ON event_rsvps FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can RSVP to events" ON event_rsvps;
CREATE POLICY "Users can RSVP to events" ON event_rsvps FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users manage own RSVPs" ON event_rsvps;
CREATE POLICY "Users manage own RSVPs" ON event_rsvps FOR UPDATE
USING (auth.uid() = user_id OR
       EXISTS (SELECT 1 FROM events WHERE id = event_id AND organizer_id = auth.uid()));

DROP POLICY IF EXISTS "Anyone can view event photos" ON event_photos;
CREATE POLICY "Anyone can view event photos" ON event_photos FOR SELECT USING (true);

DROP POLICY IF EXISTS "Authenticated users can upload photos" ON event_photos;
CREATE POLICY "Authenticated users can upload photos" ON event_photos FOR INSERT
WITH CHECK (auth.uid() = uploaded_by);

-- Triggers
DROP TRIGGER IF EXISTS update_events_updated_at ON events;
CREATE TRIGGER update_events_updated_at
BEFORE UPDATE ON events
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- Check event capacity function
CREATE OR REPLACE FUNCTION check_event_capacity()
RETURNS TRIGGER AS $$
DECLARE
  event_capacity INTEGER;
  current_attendees INTEGER;
BEGIN
  SELECT capacity INTO event_capacity FROM events WHERE id = NEW.event_id;

  IF event_capacity IS NOT NULL THEN
    SELECT COUNT(*) INTO current_attendees
    FROM event_rsvps
    WHERE event_id = NEW.event_id AND status = 'attending';

    IF current_attendees >= event_capacity THEN
      NEW.status := 'waitlist';
    END IF;
  END IF;

  RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS check_capacity_before_rsvp ON event_rsvps;
CREATE TRIGGER check_capacity_before_rsvp
BEFORE INSERT ON event_rsvps
FOR EACH ROW
EXECUTE FUNCTION check_event_capacity();

-- =====================================================
-- SUCCESS! Migrations 003-004 Complete
-- Continue with Part 3
-- =====================================================
