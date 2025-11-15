-- Platform settings table
CREATE TABLE platform_settings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  key TEXT UNIQUE NOT NULL,
  value JSONB NOT NULL,
  description TEXT,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Enable RLS
ALTER TABLE platform_settings ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Anyone can view settings"
ON platform_settings FOR SELECT
USING (true);

CREATE POLICY "Only admins can update settings"
ON platform_settings FOR ALL
USING (
  EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true)
);

-- Trigger
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
('moderation_settings', '{"auto_flag_threshold": 5, "require_admin_approval_events": false}', 'Content moderation configuration');

-- Comments
COMMENT ON TABLE platform_settings IS 'Configurable platform settings and feature flags';

-- Create helper function to get setting value
CREATE OR REPLACE FUNCTION get_setting(setting_key TEXT)
RETURNS JSONB
LANGUAGE SQL STABLE
AS $$
  SELECT value FROM platform_settings WHERE key = setting_key;
$$;

COMMENT ON FUNCTION get_setting IS 'Helper function to retrieve a platform setting value by key';
