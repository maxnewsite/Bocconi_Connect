-- Profile embeddings table (for AI matching)
CREATE TABLE profile_embeddings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE UNIQUE NOT NULL,
  embedding VECTOR(1536),
  embedding_text TEXT,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- AI interactions log
CREATE TABLE ai_interactions (
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

-- Notifications table
CREATE TABLE notifications (
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
CREATE INDEX idx_embeddings_user ON profile_embeddings(user_id);
CREATE INDEX idx_ai_interactions_user ON ai_interactions(user_id);
CREATE INDEX idx_ai_interactions_type ON ai_interactions(interaction_type);
CREATE INDEX idx_ai_interactions_created ON ai_interactions(created_at DESC);
CREATE INDEX idx_notifications_user ON notifications(user_id);
CREATE INDEX idx_notifications_unread ON notifications(user_id, is_read) WHERE is_read = false;
CREATE INDEX idx_notifications_created ON notifications(created_at DESC);

-- Vector similarity index (for fast embedding search)
CREATE INDEX idx_embeddings_vector ON profile_embeddings USING ivfflat (embedding vector_cosine_ops)
WITH (lists = 100);

-- Enable RLS
ALTER TABLE profile_embeddings ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_interactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Anyone can view embeddings"
ON profile_embeddings FOR SELECT
USING (true);

CREATE POLICY "System can manage embeddings"
ON profile_embeddings FOR ALL
USING (true);

CREATE POLICY "Users can view own AI interactions"
ON ai_interactions FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Admins can view all AI interactions"
ON ai_interactions FOR SELECT
USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true));

CREATE POLICY "Users see own notifications"
ON notifications FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users update own notifications"
ON notifications FOR UPDATE
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

-- Function to auto-mark notification as read when read_at is set
CREATE OR REPLACE FUNCTION mark_notification_read()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.read_at IS NOT NULL AND OLD.read_at IS NULL THEN
    NEW.is_read := true;
  END IF;
  RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER notification_read_trigger
BEFORE UPDATE ON notifications
FOR EACH ROW
EXECUTE FUNCTION mark_notification_read();

-- Function to create notification (helper for other triggers)
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

-- Trigger to notify on new connection request
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

CREATE TRIGGER connection_request_notification
AFTER INSERT ON connections
FOR EACH ROW
EXECUTE FUNCTION notify_connection_request();

-- Trigger to notify on connection accepted
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

CREATE TRIGGER connection_accepted_notification
AFTER UPDATE ON connections
FOR EACH ROW
EXECUTE FUNCTION notify_connection_accepted();

-- Trigger to notify on new message
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

CREATE TRIGGER new_message_notification
AFTER INSERT ON messages
FOR EACH ROW
EXECUTE FUNCTION notify_new_message();

-- Trigger to notify on answer to question
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

CREATE TRIGGER question_answer_notification
AFTER INSERT ON qa_answers
FOR EACH ROW
EXECUTE FUNCTION notify_question_answer();

-- Comments
COMMENT ON TABLE profile_embeddings IS 'Vector embeddings of user profiles for AI-powered matching';
COMMENT ON TABLE ai_interactions IS 'Log of all AI interactions for analytics and cost tracking';
COMMENT ON TABLE notifications IS 'User notifications for various platform activities';
COMMENT ON FUNCTION match_profiles IS 'Find similar user profiles using vector similarity search';
