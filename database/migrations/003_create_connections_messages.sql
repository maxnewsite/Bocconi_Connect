-- Connections table
CREATE TABLE connections (
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

-- Messages table
CREATE TABLE messages (
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
CREATE INDEX idx_connections_requester ON connections(requester_id);
CREATE INDEX idx_connections_recipient ON connections(recipient_id);
CREATE INDEX idx_connections_status ON connections(status);
CREATE INDEX idx_messages_sender ON messages(sender_id);
CREATE INDEX idx_messages_recipient ON messages(recipient_id);
CREATE INDEX idx_messages_created ON messages(created_at DESC);
CREATE INDEX idx_messages_conversation ON messages(sender_id, recipient_id, created_at DESC);
CREATE INDEX idx_messages_unread ON messages(recipient_id, is_read) WHERE is_read = false;

-- Enable RLS
ALTER TABLE connections ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- Connection RLS policies
CREATE POLICY "Users see own connections"
ON connections FOR SELECT
USING (auth.uid() = requester_id OR auth.uid() = recipient_id);

CREATE POLICY "Users can request connections"
ON connections FOR INSERT
WITH CHECK (auth.uid() = requester_id);

CREATE POLICY "Recipients can update connection status"
ON connections FOR UPDATE
USING (auth.uid() = recipient_id);

-- Message RLS policies
CREATE POLICY "Users see own messages"
ON messages FOR SELECT
USING (auth.uid() = sender_id OR auth.uid() = recipient_id);

CREATE POLICY "Users can send messages if connected"
ON messages FOR INSERT
WITH CHECK (
  auth.uid() = sender_id AND
  EXISTS (
    SELECT 1 FROM connections
    WHERE status = 'accepted'
    AND ((requester_id = auth.uid() AND recipient_id = NEW.recipient_id)
      OR (recipient_id = auth.uid() AND requester_id = NEW.recipient_id))
  )
);

CREATE POLICY "Users can update own sent messages"
ON messages FOR UPDATE
USING (auth.uid() = sender_id OR auth.uid() = recipient_id);

-- Function to auto-accept timestamp
CREATE OR REPLACE FUNCTION set_accepted_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'accepted' AND OLD.status != 'accepted' THEN
    NEW.accepted_at = now();
  END IF;
  RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER connection_accepted_timestamp
BEFORE UPDATE ON connections
FOR EACH ROW
EXECUTE FUNCTION set_accepted_timestamp();

-- Comments
COMMENT ON TABLE connections IS 'Connection requests and relationships between users';
COMMENT ON TABLE messages IS 'Direct messages between connected users';
COMMENT ON COLUMN connections.ai_match_reasons IS 'AI-generated reasons why these users are a good match';
