-- Events table
CREATE TABLE events (
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

-- Event RSVPs table
CREATE TABLE event_rsvps (
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

-- Event photos table
CREATE TABLE event_photos (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  event_id UUID REFERENCES events(id) ON DELETE CASCADE NOT NULL,
  uploaded_by UUID REFERENCES users(id),
  photo_url TEXT NOT NULL,
  caption TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Indexes
CREATE INDEX idx_events_organizer ON events(organizer_id);
CREATE INDEX idx_events_start_date ON events(start_date);
CREATE INDEX idx_events_published ON events(is_published, start_date) WHERE is_published = true;
CREATE INDEX idx_events_type ON events(event_type);
CREATE INDEX idx_events_featured ON events(is_featured) WHERE is_featured = true;
CREATE INDEX idx_rsvps_event ON event_rsvps(event_id);
CREATE INDEX idx_rsvps_user ON event_rsvps(user_id);
CREATE INDEX idx_rsvps_status ON event_rsvps(status);
CREATE INDEX idx_event_photos_event ON event_photos(event_id);

-- Enable RLS
ALTER TABLE events ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_rsvps ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_photos ENABLE ROW LEVEL SECURITY;

-- Event RLS policies
CREATE POLICY "Anyone can view published events"
ON events FOR SELECT
USING (is_published = true);

CREATE POLICY "Organizers manage own events"
ON events FOR ALL
USING (auth.uid() = organizer_id);

CREATE POLICY "Admins can manage all events"
ON events FOR ALL
USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true));

-- RSVP RLS policies
CREATE POLICY "Anyone can view RSVPs"
ON event_rsvps FOR SELECT
USING (true);

CREATE POLICY "Users can RSVP to events"
ON event_rsvps FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users manage own RSVPs"
ON event_rsvps FOR UPDATE
USING (auth.uid() = user_id OR
       EXISTS (SELECT 1 FROM events WHERE id = event_id AND organizer_id = auth.uid()));

-- Event photos RLS policies
CREATE POLICY "Anyone can view event photos"
ON event_photos FOR SELECT
USING (true);

CREATE POLICY "Authenticated users can upload photos"
ON event_photos FOR INSERT
WITH CHECK (auth.uid() = uploaded_by);

-- Triggers
CREATE TRIGGER update_events_updated_at
BEFORE UPDATE ON events
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- Function to check event capacity
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

CREATE TRIGGER check_capacity_before_rsvp
BEFORE INSERT ON event_rsvps
FOR EACH ROW
EXECUTE FUNCTION check_event_capacity();

-- Comments
COMMENT ON TABLE events IS 'Professional and social events for alumni';
COMMENT ON TABLE event_rsvps IS 'Event registrations and attendance tracking';
COMMENT ON TABLE event_photos IS 'Photo gallery for past events';
COMMENT ON COLUMN event_rsvps.qr_code IS 'Unique QR code for check-in at event';
