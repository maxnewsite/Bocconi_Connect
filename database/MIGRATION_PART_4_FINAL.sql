-- =====================================================
-- BOCCONI ALUMNI CONNECT - DATABASE SETUP PART 4 (FINAL)
-- Run AFTER Part 3 completes successfully
-- =====================================================

-- =====================================================
-- MIGRATION 006: AI & Notifications
-- =====================================================

CREATE TABLE IF NOT EXISTS profile_embeddings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE UNIQUE NOT NULL,
  embedding VECTOR(1536),
  embedding_text TEXT,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

CREATE TABLE IF NOT EXISTS ai_interactions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  interaction_type TEXT NOT NULL,
  prompt TEXT,
  response TEXT,
  model_used TEXT,
  tokens_used INTEGER,
  cost_usd DECIMAL(10,4),
  feedback_rating INTEGER CHECK (feedback_rating >= 1 AND feedback_rating <= 5),
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

-- Indexes
CREATE INDEX IF NOT EXISTS idx_embeddings_user ON profile_embeddings(user_id);
CREATE INDEX IF NOT EXISTS idx_ai_interactions_user ON ai_interactions(user_id);
CREATE INDEX IF NOT EXISTS idx_ai_interactions_type ON ai_interactions(interaction_type);
CREATE INDEX IF NOT EXISTS idx_ai_interactions_created ON ai_interactions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_unread ON notifications(user_id, is_read) WHERE is_read = false;
CREATE INDEX IF NOT EXISTS idx_notifications_created ON notifications(created_at DESC);

-- Vector similarity index
CREATE INDEX IF NOT EXISTS idx_embeddings_vector ON profile_embeddings
USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);

-- RLS
ALTER TABLE profile_embeddings ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_interactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can view embeddings" ON profile_embeddings;
CREATE POLICY "Anyone can view embeddings" ON profile_embeddings FOR SELECT USING (true);

DROP POLICY IF EXISTS "System can manage embeddings" ON profile_embeddings;
CREATE POLICY "System can manage embeddings" ON profile_embeddings FOR ALL USING (true);

DROP POLICY IF EXISTS "Users can view own AI interactions" ON ai_interactions;
CREATE POLICY "Users can view own AI interactions" ON ai_interactions FOR SELECT
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Admins can view all AI interactions" ON ai_interactions;
CREATE POLICY "Admins can view all AI interactions" ON ai_interactions FOR SELECT
USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true));

DROP POLICY IF EXISTS "Users see own notifications" ON notifications;
CREATE POLICY "Users see own notifications" ON notifications FOR SELECT
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users update own notifications" ON notifications;
CREATE POLICY "Users update own notifications" ON notifications FOR UPDATE
USING (auth.uid() = user_id);

-- Vector similarity search function
CREATE OR REPLACE FUNCTION match_profiles(
  query_embedding VECTOR(1536),
  match_threshold FLOAT DEFAULT 0.7,
  match_count INT DEFAULT 10
)
RETURNS TABLE (
  user_id UUID,
  similarity FLOAT
)
LANGUAGE SQL STABLE
AS $$
  SELECT
    profile_embeddings.user_id,
    1 - (profile_embeddings.embedding <=> query_embedding) AS similarity
  FROM profile_embeddings
  WHERE 1 - (profile_embeddings.embedding <=> query_embedding) > match_threshold
  ORDER BY similarity DESC
  LIMIT match_count;
$$;

-- Notification helper function
CREATE OR REPLACE FUNCTION mark_notification_read()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.read_at IS NOT NULL AND OLD.read_at IS NULL THEN
    NEW.is_read := true;
  END IF;
  RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS notification_read_trigger ON notifications;
CREATE TRIGGER notification_read_trigger
BEFORE UPDATE ON notifications
FOR EACH ROW
EXECUTE FUNCTION mark_notification_read();

-- Create notification function
CREATE OR REPLACE FUNCTION create_notification(
  p_user_id UUID,
  p_type TEXT,
  p_title TEXT,
  p_message TEXT,
  p_link_url TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
AS $$
DECLARE
  notification_id UUID;
BEGIN
  INSERT INTO notifications (user_id, type, title, message, link_url)
  VALUES (p_user_id, p_type, p_title, p_message, p_link_url)
  RETURNING id INTO notification_id;

  RETURN notification_id;
END;
$$;

-- Notification triggers
CREATE OR REPLACE FUNCTION notify_connection_request()
RETURNS TRIGGER AS $$
DECLARE
  requester_name TEXT;
BEGIN
  SELECT full_name INTO requester_name FROM users WHERE id = NEW.requester_id;

  PERFORM create_notification(
    NEW.recipient_id,
    'connection_request',
    'New Connection Request',
    requester_name || ' wants to connect with you',
    '/connections/pending'
  );

  RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS connection_request_notification ON connections;
CREATE TRIGGER connection_request_notification
AFTER INSERT ON connections
FOR EACH ROW
EXECUTE FUNCTION notify_connection_request();

CREATE OR REPLACE FUNCTION notify_connection_accepted()
RETURNS TRIGGER AS $$
DECLARE
  recipient_name TEXT;
BEGIN
  IF NEW.status = 'accepted' AND OLD.status = 'pending' THEN
    SELECT full_name INTO recipient_name FROM users WHERE id = NEW.recipient_id;

    PERFORM create_notification(
      NEW.requester_id,
      'connection_accepted',
      'Connection Accepted',
      recipient_name || ' accepted your connection request',
      '/connections'
    );
  END IF;

  RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS connection_accepted_notification ON connections;
CREATE TRIGGER connection_accepted_notification
AFTER UPDATE ON connections
FOR EACH ROW
EXECUTE FUNCTION notify_connection_accepted();

CREATE OR REPLACE FUNCTION notify_new_message()
RETURNS TRIGGER AS $$
DECLARE
  sender_name TEXT;
BEGIN
  SELECT full_name INTO sender_name FROM users WHERE id = NEW.sender_id;

  PERFORM create_notification(
    NEW.recipient_id,
    'new_message',
    'New Message',
    'You have a new message from ' || sender_name,
    '/messages'
  );

  RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS new_message_notification ON messages;
CREATE TRIGGER new_message_notification
AFTER INSERT ON messages
FOR EACH ROW
EXECUTE FUNCTION notify_new_message();

CREATE OR REPLACE FUNCTION notify_question_answer()
RETURNS TRIGGER AS $$
DECLARE
  question_asker UUID;
  answerer_name TEXT;
  question_title TEXT;
BEGIN
  SELECT asker_id, title INTO question_asker, question_title
  FROM qa_questions
  WHERE id = NEW.question_id;

  SELECT full_name INTO answerer_name FROM users WHERE id = NEW.answerer_id;

  IF question_asker != NEW.answerer_id THEN
    PERFORM create_notification(
      question_asker,
      'qa_answer',
      'New Answer to Your Question',
      answerer_name || ' answered your question: ' || question_title,
      '/qa/questions/' || NEW.question_id
    );
  END IF;

  RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS question_answer_notification ON qa_answers;
CREATE TRIGGER question_answer_notification
AFTER INSERT ON qa_answers
FOR EACH ROW
EXECUTE FUNCTION notify_question_answer();

-- =====================================================
-- MIGRATION 007: Platform Settings
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

DROP POLICY IF EXISTS "Only admins can update settings" ON platform_settings;
CREATE POLICY "Only admins can update settings" ON platform_settings FOR ALL
USING (
  EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true)
);

DROP TRIGGER IF EXISTS update_settings_updated_at ON platform_settings;
CREATE TRIGGER update_settings_updated_at
BEFORE UPDATE ON platform_settings
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- Seed initial settings
INSERT INTO platform_settings (key, value, description) VALUES
('platform_name', '"Bocconi GCC Alumni Connect"', 'Platform display name'),
('max_file_upload_mb', '10', 'Maximum file upload size in MB'),
('ai_models', '{"primary": "claude-sonnet-4-20250514", "embeddings": "text-embedding-3-small"}', 'AI models configuration'),
('email_settings', '{"daily_digest": true, "weekly_report": true, "event_reminders": true}', 'Email notification preferences'),
('reputation_points', '{"question": 5, "answer": 10, "accepted_answer": 25, "upvote": 2, "downvote": -1}', 'Points awarded for Q&A activities'),
('feature_flags', '{"qa_enabled": true, "events_enabled": true, "messaging_enabled": true}', 'Feature toggles'),
('matching_settings', '{"min_similarity_score": 0.7, "max_suggestions": 10}', 'AI matching algorithm settings'),
('moderation_settings', '{"auto_flag_threshold": 5, "require_admin_approval_events": false}', 'Content moderation configuration')
ON CONFLICT (key) DO NOTHING;

-- Helper function to get setting value
CREATE OR REPLACE FUNCTION get_setting(setting_key TEXT)
RETURNS JSONB
LANGUAGE SQL STABLE
AS $$
  SELECT value FROM platform_settings WHERE key = setting_key;
$$;

-- =====================================================
-- 🎉 SUCCESS! ALL MIGRATIONS COMPLETE!
-- Database is ready for Bocconi Alumni Connect
-- =====================================================

-- Verify setup
SELECT
  'Users' as table_name, COUNT(*) as count FROM users
UNION ALL
SELECT 'Connections', COUNT(*) FROM connections
UNION ALL
SELECT 'Messages', COUNT(*) FROM messages
UNION ALL
SELECT 'Events', COUNT(*) FROM events
UNION ALL
SELECT 'Q&A Questions', COUNT(*) FROM qa_questions
UNION ALL
SELECT 'Notifications', COUNT(*) FROM notifications
UNION ALL
SELECT 'Settings', COUNT(*) FROM platform_settings;
