-- =====================================================
-- BOCCONI ALUMNI CONNECT - DATABASE SETUP PART 3
-- Run AFTER Part 2 completes successfully
-- =====================================================

-- =====================================================
-- MIGRATION 005: Q&A System
-- =====================================================

CREATE TABLE IF NOT EXISTS qa_questions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  asker_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  title TEXT NOT NULL CHECK (length(title) >= 10 AND length(title) <= 300),
  description TEXT NOT NULL CHECK (length(description) >= 20),
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
  content TEXT NOT NULL CHECK (length(content) >= 20),
  upvotes INTEGER DEFAULT 0,
  downvotes INTEGER DEFAULT 0,
  is_accepted BOOLEAN DEFAULT false,
  ai_quality_score INTEGER CHECK (ai_quality_score >= 0 AND ai_quality_score <= 100),
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
  badge_level TEXT DEFAULT 'bronze' CHECK (badge_level IN ('bronze', 'silver', 'gold', 'platinum')),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_questions_asker ON qa_questions(asker_id);
CREATE INDEX IF NOT EXISTS idx_questions_category ON qa_questions(category);
CREATE INDEX IF NOT EXISTS idx_questions_created ON qa_questions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_questions_tags ON qa_questions USING GIN(tags);
CREATE INDEX IF NOT EXISTS idx_questions_unanswered ON qa_questions(has_accepted_answer) WHERE has_accepted_answer = false;
CREATE INDEX IF NOT EXISTS idx_answers_question ON qa_answers(question_id);
CREATE INDEX IF NOT EXISTS idx_answers_answerer ON qa_answers(answerer_id);
CREATE INDEX IF NOT EXISTS idx_answers_accepted ON qa_answers(is_accepted) WHERE is_accepted = true;
CREATE INDEX IF NOT EXISTS idx_votes_user ON qa_votes(user_id);
CREATE INDEX IF NOT EXISTS idx_votes_votable ON qa_votes(votable_type, votable_id);
CREATE INDEX IF NOT EXISTS idx_reputation_points ON user_reputation(total_points DESC);

-- RLS
ALTER TABLE qa_questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE qa_answers ENABLE ROW LEVEL SECURITY;
ALTER TABLE qa_votes ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_reputation ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can view questions" ON qa_questions;
CREATE POLICY "Anyone can view questions" ON qa_questions FOR SELECT USING (true);

DROP POLICY IF EXISTS "Authenticated users can ask" ON qa_questions;
CREATE POLICY "Authenticated users can ask" ON qa_questions FOR INSERT
WITH CHECK (auth.uid() = asker_id);

DROP POLICY IF EXISTS "Askers can update own questions" ON qa_questions;
CREATE POLICY "Askers can update own questions" ON qa_questions FOR UPDATE
USING (auth.uid() = asker_id);

DROP POLICY IF EXISTS "Anyone can view answers" ON qa_answers;
CREATE POLICY "Anyone can view answers" ON qa_answers FOR SELECT USING (true);

DROP POLICY IF EXISTS "Authenticated users can answer" ON qa_answers;
CREATE POLICY "Authenticated users can answer" ON qa_answers FOR INSERT
WITH CHECK (auth.uid() = answerer_id);

DROP POLICY IF EXISTS "Answerers update own answers" ON qa_answers;
CREATE POLICY "Answerers update own answers" ON qa_answers FOR UPDATE
USING (auth.uid() = answerer_id);

DROP POLICY IF EXISTS "Question askers can accept answers" ON qa_answers;
CREATE POLICY "Question askers can accept answers" ON qa_answers FOR UPDATE
USING (
  auth.uid() = (SELECT asker_id FROM qa_questions WHERE id = question_id)
);

DROP POLICY IF EXISTS "Authenticated users can vote" ON qa_votes;
CREATE POLICY "Authenticated users can vote" ON qa_votes FOR INSERT
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can view all votes" ON qa_votes;
CREATE POLICY "Users can view all votes" ON qa_votes FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can delete own votes" ON qa_votes;
CREATE POLICY "Users can delete own votes" ON qa_votes FOR DELETE
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Anyone can view reputation" ON user_reputation;
CREATE POLICY "Anyone can view reputation" ON user_reputation FOR SELECT USING (true);

-- Triggers
DROP TRIGGER IF EXISTS update_questions_updated_at ON qa_questions;
CREATE TRIGGER update_questions_updated_at
BEFORE UPDATE ON qa_questions
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_answers_updated_at ON qa_answers;
CREATE TRIGGER update_answers_updated_at
BEFORE UPDATE ON qa_answers
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- Update vote counts function
CREATE OR REPLACE FUNCTION update_vote_counts()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.votable_type = 'question' THEN
      IF NEW.vote_type = 'upvote' THEN
        UPDATE qa_questions SET upvotes = upvotes + 1 WHERE id = NEW.votable_id;
      ELSE
        UPDATE qa_questions SET downvotes = downvotes + 1 WHERE id = NEW.votable_id;
      END IF;
    ELSIF NEW.votable_type = 'answer' THEN
      IF NEW.vote_type = 'upvote' THEN
        UPDATE qa_answers SET upvotes = upvotes + 1 WHERE id = NEW.votable_id;
      ELSE
        UPDATE qa_answers SET downvotes = downvotes + 1 WHERE id = NEW.votable_id;
      END IF;
    END IF;
  ELSIF TG_OP = 'DELETE' THEN
    IF OLD.votable_type = 'question' THEN
      IF OLD.vote_type = 'upvote' THEN
        UPDATE qa_questions SET upvotes = upvotes - 1 WHERE id = OLD.votable_id;
      ELSE
        UPDATE qa_questions SET downvotes = downvotes - 1 WHERE id = OLD.votable_id;
      END IF;
    ELSIF OLD.votable_type = 'answer' THEN
      IF OLD.vote_type = 'upvote' THEN
        UPDATE qa_answers SET upvotes = upvotes - 1 WHERE id = OLD.votable_id;
      ELSE
        UPDATE qa_answers SET downvotes = downvotes - 1 WHERE id = OLD.votable_id;
      END IF;
    END IF;
  END IF;

  RETURN NULL;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS update_vote_counts_trigger ON qa_votes;
CREATE TRIGGER update_vote_counts_trigger
AFTER INSERT OR DELETE ON qa_votes
FOR EACH ROW
EXECUTE FUNCTION update_vote_counts();

-- Update reputation function
CREATE OR REPLACE FUNCTION update_user_reputation()
RETURNS TRIGGER AS $$
BEGIN
  -- Create reputation record if not exists
  INSERT INTO user_reputation (user_id)
  VALUES (NEW.answerer_id)
  ON CONFLICT (user_id) DO NOTHING;

  IF TG_OP = 'INSERT' THEN
    IF TG_TABLE_NAME = 'qa_questions' THEN
      -- Create reputation for question asker
      INSERT INTO user_reputation (user_id)
      VALUES (NEW.asker_id)
      ON CONFLICT (user_id) DO NOTHING;

      UPDATE user_reputation
      SET questions_asked = questions_asked + 1,
          total_points = total_points + 5
      WHERE user_id = NEW.asker_id;
    ELSIF TG_TABLE_NAME = 'qa_answers' THEN
      UPDATE user_reputation
      SET answers_given = answers_given + 1,
          total_points = total_points + 10
      WHERE user_id = NEW.answerer_id;

      IF NEW.is_accepted THEN
        UPDATE user_reputation
        SET accepted_answers = accepted_answers + 1,
            total_points = total_points + 15
        WHERE user_id = NEW.answerer_id;
      END IF;
    END IF;
  ELSIF TG_OP = 'UPDATE' AND TG_TABLE_NAME = 'qa_answers' THEN
    IF NEW.is_accepted AND NOT OLD.is_accepted THEN
      UPDATE user_reputation
      SET accepted_answers = accepted_answers + 1,
          total_points = total_points + 25
      WHERE user_id = NEW.answerer_id;

      UPDATE qa_questions
      SET has_accepted_answer = true
      WHERE id = NEW.question_id;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS update_reputation_on_question ON qa_questions;
CREATE TRIGGER update_reputation_on_question
AFTER INSERT ON qa_questions
FOR EACH ROW
EXECUTE FUNCTION update_user_reputation();

DROP TRIGGER IF EXISTS update_reputation_on_answer ON qa_answers;
CREATE TRIGGER update_reputation_on_answer
AFTER INSERT OR UPDATE ON qa_answers
FOR EACH ROW
EXECUTE FUNCTION update_user_reputation();

-- =====================================================
-- SUCCESS! Migration 005 Complete
-- Continue with Part 4 (Final)
-- =====================================================
