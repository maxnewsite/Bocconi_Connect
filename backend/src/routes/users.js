import express from 'express';
import { body } from 'express-validator';
import { authenticate } from '../middleware/auth.js';
import { AppError, asyncHandler } from '../middleware/errorHandler.js';
import { validate } from '../middleware/validation.js';
import { supabase } from '../config/supabase.js';
import embeddingService from '../services/embeddingService.js';

const router = express.Router();

/**
 * GET /api/users/profile/:userId
 * Get user profile by ID
 */
router.get(
  '/profile/:userId',
  authenticate,
  asyncHandler(async (req, res) => {
    const { userId } = req.params;

    const { data: user, error } = await supabase
      .from('users')
      .select(`
        *,
        profile_offerings(*),
        profile_seeking(*)
      `)
      .eq('id', userId)
      .eq('is_active', true)
      .single();

    if (error || !user) {
      throw new AppError('User not found', 404);
    }

    res.json({
      success: true,
      data: user,
    });
  })
);

/**
 * PUT /api/users/profile
 * Update own profile
 */
router.put(
  '/profile',
  authenticate,
  [
    body('full_name').optional().trim(),
    body('tagline').optional().trim(),
    body('current_role').optional().trim(),
    body('current_company').optional().trim(),
    body('current_industry').optional().trim(),
    body('location_city').optional().trim(),
    body('location_country').optional().trim(),
    body('bio').optional().trim(),
    body('expertise_tags').optional().isArray(),
    body('passions').optional().isArray(),
    body('linkedin_url').optional().isURL(),
    body('phone').optional().trim(),
    validate,
  ],
  asyncHandler(async (req, res) => {
    const userId = req.userId;
    const updates = req.body;

    const { data: user, error } = await supabase
      .from('users')
      .update(updates)
      .eq('id', userId)
      .select()
      .single();

    if (error) {
      throw new AppError('Failed to update profile', 500);
    }

    // Regenerate embedding if significant changes
    if (updates.bio || updates.expertise_tags || updates.current_role) {
      try {
        await embeddingService.generateProfileEmbedding(userId);
      } catch (error) {
        console.error('Failed to update embedding:', error);
      }
    }

    res.json({
      success: true,
      data: user,
    });
  })
);

/**
 * POST /api/users/offerings
 * Add profile offering
 */
router.post(
  '/offerings',
  authenticate,
  [
    body('offering_type').isIn(['mentorship', 'job_opportunities', 'investment', 'advice', 'connections']),
    body('description').optional().trim(),
    body('time_commitment').optional().isIn(['one-time', 'monthly', 'ongoing', 'project-based']),
    body('specific_domains').optional().isArray(),
    validate,
  ],
  asyncHandler(async (req, res) => {
    const userId = req.userId;
    const offering = req.body;

    const { data, error } = await supabase
      .from('profile_offerings')
      .insert({
        user_id: userId,
        ...offering,
      })
      .select()
      .single();

    if (error) {
      throw new AppError('Failed to add offering', 500);
    }

    // Update embedding
    await embeddingService.generateProfileEmbedding(userId);

    res.status(201).json({
      success: true,
      data,
    });
  })
);

/**
 * DELETE /api/users/offerings/:id
 * Remove profile offering
 */
router.delete(
  '/offerings/:id',
  authenticate,
  asyncHandler(async (req, res) => {
    const { id } = req.params;
    const userId = req.userId;

    const { error } = await supabase
      .from('profile_offerings')
      .delete()
      .eq('id', id)
      .eq('user_id', userId);

    if (error) {
      throw new AppError('Failed to delete offering', 500);
    }

    res.json({
      success: true,
      message: 'Offering deleted',
    });
  })
);

/**
 * POST /api/users/seeking
 * Add profile seeking
 */
router.post(
  '/seeking',
  authenticate,
  [
    body('seeking_type').isIn(['mentorship', 'job_opportunities', 'investment', 'partnerships', 'learning']),
    body('description').optional().trim(),
    body('time_commitment').optional().isIn(['one-time', 'monthly', 'ongoing', 'project-based']),
    body('specific_domains').optional().isArray(),
    validate,
  ],
  asyncHandler(async (req, res) => {
    const userId = req.userId;
    const seeking = req.body;

    const { data, error } = await supabase
      .from('profile_seeking')
      .insert({
        user_id: userId,
        ...seeking,
      })
      .select()
      .single();

    if (error) {
      throw new AppError('Failed to add seeking', 500);
    }

    await embeddingService.generateProfileEmbedding(userId);

    res.status(201).json({
      success: true,
      data,
    });
  })
);

/**
 * DELETE /api/users/seeking/:id
 * Remove profile seeking
 */
router.delete(
  '/seeking/:id',
  authenticate,
  asyncHandler(async (req, res) => {
    const { id } = req.params;
    const userId = req.userId;

    const { error } = await supabase
      .from('profile_seeking')
      .delete()
      .eq('id', id)
      .eq('user_id', userId);

    if (error) {
      throw new AppError('Failed to delete seeking', 500);
    }

    res.json({
      success: true,
      message: 'Seeking deleted',
    });
  })
);

/**
 * GET /api/users/stats
 * Get user statistics
 */
router.get(
  '/stats',
  authenticate,
  asyncHandler(async (req, res) => {
    const userId = req.userId;

    // Get various counts
    const [connectionsCount, messagesCount, eventsCount, qaReputation] = await Promise.all([
      supabase
        .from('connections')
        .select('id', { count: 'exact', head: true })
        .or(`requester_id.eq.${userId},recipient_id.eq.${userId}`)
        .eq('status', 'accepted'),

      supabase
        .from('messages')
        .select('id', { count: 'exact', head: true })
        .or(`sender_id.eq.${userId},recipient_id.eq.${userId}`),

      supabase
        .from('event_rsvps')
        .select('id', { count: 'exact', head: true })
        .eq('user_id', userId)
        .eq('status', 'attending'),

      supabase
        .from('user_reputation')
        .select('*')
        .eq('user_id', userId)
        .single(),
    ]);

    res.json({
      success: true,
      data: {
        connections: connectionsCount.count || 0,
        messages: messagesCount.count || 0,
        eventsAttending: eventsCount.count || 0,
        reputation: qaReputation.data || {
          total_points: 0,
          questions_asked: 0,
          answers_given: 0,
          accepted_answers: 0,
          badge_level: 'bronze',
        },
      },
    });
  })
);

export default router;
