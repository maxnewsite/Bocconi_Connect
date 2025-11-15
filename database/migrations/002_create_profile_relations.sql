-- Profile offerings table
CREATE TABLE profile_offerings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  offering_type TEXT NOT NULL CHECK (offering_type IN ('mentorship', 'job_opportunities', 'investment', 'advice', 'connections')),
  description TEXT,
  time_commitment TEXT CHECK (time_commitment IN ('one-time', 'monthly', 'ongoing', 'project-based')),
  specific_domains TEXT[] DEFAULT ARRAY[]::TEXT[],
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Profile seeking table
CREATE TABLE profile_seeking (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  seeking_type TEXT NOT NULL CHECK (seeking_type IN ('mentorship', 'job_opportunities', 'investment', 'partnerships', 'learning')),
  description TEXT,
  time_commitment TEXT CHECK (time_commitment IN ('one-time', 'monthly', 'ongoing', 'project-based')),
  specific_domains TEXT[] DEFAULT ARRAY[]::TEXT[],
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Indexes
CREATE INDEX idx_offerings_user ON profile_offerings(user_id);
CREATE INDEX idx_offerings_type ON profile_offerings(offering_type);
CREATE INDEX idx_seeking_user ON profile_seeking(user_id);
CREATE INDEX idx_seeking_type ON profile_seeking(seeking_type);

-- Enable RLS
ALTER TABLE profile_offerings ENABLE ROW LEVEL SECURITY;
ALTER TABLE profile_seeking ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Anyone can view offerings"
ON profile_offerings FOR SELECT
USING (true);

CREATE POLICY "Users manage own offerings"
ON profile_offerings FOR ALL
USING (auth.uid() = user_id);

CREATE POLICY "Anyone can view seeking"
ON profile_seeking FOR SELECT
USING (true);

CREATE POLICY "Users manage own seeking"
ON profile_seeking FOR ALL
USING (auth.uid() = user_id);

-- Comments
COMMENT ON TABLE profile_offerings IS 'What users can offer to other alumni (mentorship, jobs, etc.)';
COMMENT ON TABLE profile_seeking IS 'What users are seeking from other alumni';
