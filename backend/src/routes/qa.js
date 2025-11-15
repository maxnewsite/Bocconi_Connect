import express from 'express';
import { body, query } from 'express-validator';
import { authenticate } from '../middleware/auth.js';
import { AppError, asyncHandler } from '../middleware/errorHandler.js';
import { validate } from '../middleware/validation.js';
import { aiLimiter } from '../middleware/rateLimiter.js';
import { supabase } from '../config/supabase.js';
import claudeService from '../services/claudeService.js';

const router = express.Router();

/**
 * GET /api/qa/questions
 * Get all questions
 */
router.get(
  '/questions',
  authenticate,
  [
    query('category').optional().trim(),
    query('filter').optional().isIn(['recent', 'unanswered', 'trending']),
    query('page').optional().isInt({ min: 1 }).toInt(),
    query('limit').optional().isInt({ min: 1, max: 50 }).toInt(),
    validate,
  ],
  asyncHandler(async (req, res) => {
    const { category, filter = 'recent', page = 1, limit = 20 } = req.query;

    let query = supabase
      .from('qa_questions')
      .select(`
        *,
        asker:users!asker_id(id, full_name, profile_photo_url),
        answers:qa_answers(count)
      `, { count: 'exact' });

    if (category) {
      query = query.eq('category', category);
    }

    if (filter === 'unanswered') {
      query = query.eq('has_accepted_answer', false);
    }

    const from = (page - 1) * limit;
    query = query.range(from, from + limit - 1);

    if (filter === 'trending') {
      query = query.order('upvotes', { ascending: false }).order('view_count', { ascending: false });
    } else {
      query = query.order('created_at', { ascending: false });
    }

    const { data: questions, error, count } = await query;

    if (error) {
      throw new AppError('Failed to fetch questions', 500);
    }

    res.json({
      success: true,
      data: {
        questions,
        pagination: {
          page,
          limit,
          total: count,
          pages: Math.ceil(count / limit),
        },
      },
    });
  })
);

/**
 * GET /api/qa/questions/:id
 * Get question with answers
 */
router.get(
  '/questions/:id',
  authenticate,
  asyncHandler(async (req, res) => {
    const { id } = req.params;

    const { data: question, error } = await supabase
      .from('qa_questions')
      .select(`
        *,
        asker:users!asker_id(id, full_name, profile_photo_url, current_role),
        answers:qa_answers(
          *,
          answerer:users!answerer_id(id, full_name, profile_photo_url, current_role)
        )
      `)
      .eq('id', id)
      .single();

    if (error || !question) {
      throw new AppError('Question not found', 404);
    }

    // Increment view count
    await supabase
      .from('qa_questions')
      .update({ view_count: question.view_count + 1 })
      .eq('id', id);

    res.json({
      success: true,
      data: question,
    });
  })
);

/**
 * POST /api/qa/questions
 * Ask a question
 */
router.post(
  '/questions',
  authenticate,
  [
    body('title').trim().isLength({ min: 10, max: 300 }),
    body('description').trim().isLength({ min: 20 }),
    body('category').trim().notEmpty(),
    body('tags').optional().isArray(),
    body('is_anonymous').optional().isBoolean(),
    validate,
  ],
  asyncHandler(async (req, res) => {
    const userId = req.userId;
    let { title, description, category, tags, is_anonymous } = req.body;

    // AI-suggest tags if not provided
    if (!tags || tags.length === 0) {
      try {
        tags = await claudeService.suggestTags(title, description);
      } catch (error) {
        tags = [];
      }
    }

    const { data: question, error } = await supabase
      .from('qa_questions')
      .insert({
        asker_id: userId,
        title,
        description,
        category,
        tags,
        is_anonymous,
      })
      .select()
      .single();

    if (error) {
      throw new AppError('Failed to create question', 500);
    }

    res.status(201).json({
      success: true,
      data: question,
    });
  })
);

/**
 * POST /api/qa/questions/:id/answers
 * Answer a question
 */
router.post(
  '/questions/:id/answers',
  authenticate,
  [body('content').trim().isLength({ min: 20 }), validate],
  asyncHandler(async (req, res) => {
    const { id: questionId } = req.params;
    const userId = req.userId;
    const { content } = req.body;

    const { data: answer, error } = await supabase
      .from('qa_answers')
      .insert({
        question_id: questionId,
        answerer_id: userId,
        content,
      })
      .select()
      .single();

    if (error) {
      throw new AppError('Failed to post answer', 500);
    }

    res.status(201).json({
      success: true,
      data: answer,
    });
  })
);

/**
 * POST /api/qa/answers/:id/accept
 * Accept an answer
 */
router.post(
  '/answers/:id/accept',
  authenticate,
  asyncHandler(async (req, res) => {
    const { id: answerId } = req.params;
    const userId = req.userId;

    // Verify user is the question asker
    const { data: answer } = await supabase
      .from('qa_answers')
      .select(`
        *,
        question:qa_questions(asker_id)
      `)
      .eq('id', answerId)
      .single();

    if (!answer || answer.question.asker_id !== userId) {
      throw new AppError('Unauthorized', 403);
    }

    const { data: updated, error } = await supabase
      .from('qa_answers')
      .update({ is_accepted: true })
      .eq('id', answerId)
      .select()
      .single();

    if (error) {
      throw new AppError('Failed to accept answer', 500);
    }

    res.json({
      success: true,
      data: updated,
    });
  })
);

/**
 * POST /api/qa/vote
 * Vote on question or answer
 */
router.post(
  '/vote',
  authenticate,
  [
    body('votable_type').isIn(['question', 'answer']),
    body('votable_id').isUUID(),
    body('vote_type').isIn(['upvote', 'downvote']),
    validate,
  ],
  asyncHandler(async (req, res) => {
    const userId = req.userId;
    const { votable_type, votable_id, vote_type } = req.body;

    const { data: vote, error } = await supabase
      .from('qa_votes')
      .upsert({
        user_id: userId,
        votable_type,
        votable_id,
        vote_type,
      }, {
        onConflict: 'user_id,votable_type,votable_id'
      })
      .select()
      .single();

    if (error) {
      throw new AppError('Failed to vote', 500);
    }

    res.json({
      success: true,
      data: vote,
    });
  })
);

/**
 * GET /api/qa/leaderboard
 * Get reputation leaderboard
 */
router.get(
  '/leaderboard',
  authenticate,
  [query('limit').optional().isInt({ min: 1, max: 100 }).toInt(), validate],
  asyncHandler(async (req, res) => {
    const { limit = 50 } = req.query;

    const { data: leaders, error } = await supabase
      .from('user_reputation')
      .select(`
        *,
        user:users(id, full_name, profile_photo_url, current_role)
      `)
      .order('total_points', { ascending: false })
      .limit(limit);

    if (error) {
      throw new AppError('Failed to fetch leaderboard', 500);
    }

    res.json({
      success: true,
      data: leaders,
    });
  })
);

export default router;
