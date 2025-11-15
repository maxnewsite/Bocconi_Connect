import express from 'express';
import { body } from 'express-validator';
import { authenticate } from '../middleware/auth.js';
import { AppError, asyncHandler } from '../middleware/errorHandler.js';
import { validate } from '../middleware/validation.js';
import { aiLimiter } from '../middleware/rateLimiter.js';
import { supabase } from '../config/supabase.js';
import claudeService from '../services/claudeService.js';

const router = express.Router();

/**
 * POST /api/connections/request
 * Send connection request
 */
router.post(
  '/request',
  authenticate,
  [body('recipient_id').isUUID(), body('introduction_message').optional().trim(), validate],
  asyncHandler(async (req, res) => {
    const requesterId = req.userId;
    const { recipient_id, introduction_message } = req.body;

    if (requesterId === recipient_id) {
      throw new AppError('Cannot connect with yourself', 400);
    }

    // Check if connection already exists
    const { data: existing } = await supabase
      .from('connections')
      .select('*')
      .or(`and(requester_id.eq.${requesterId},recipient_id.eq.${recipient_id}),and(requester_id.eq.${recipient_id},recipient_id.eq.${requesterId})`)
      .single();

    if (existing) {
      throw new AppError('Connection request already exists', 400);
    }

    // Get both profiles for AI matching
    const [requester, recipient] = await Promise.all([
      supabase.from('users').select('*').eq('id', requesterId).single(),
      supabase.from('users').select('*').eq('id', recipient_id).single(),
    ]);

    // Generate AI match reasons
    const matchReasons = await claudeService.generateMatchReasons(requester.data, recipient.data);
    const matchScore = Math.min(95, 70 + matchReasons.length * 5); // Simple scoring

    // Create connection request
    const { data: connection, error } = await supabase
      .from('connections')
      .insert({
        requester_id: requesterId,
        recipient_id,
        introduction_message,
        ai_match_score: matchScore,
        ai_match_reasons: matchReasons,
      })
      .select()
      .single();

    if (error) {
      throw new AppError('Failed to create connection request', 500);
    }

    res.status(201).json({
      success: true,
      data: connection,
    });
  })
);

/**
 * POST /api/connections/:id/accept
 * Accept connection request
 */
router.post(
  '/:id/accept',
  authenticate,
  asyncHandler(async (req, res) => {
    const { id } = req.params;
    const userId = req.userId;

    const { data: connection, error } = await supabase
      .from('connections')
      .update({ status: 'accepted' })
      .eq('id', id)
      .eq('recipient_id', userId)
      .eq('status', 'pending')
      .select()
      .single();

    if (error || !connection) {
      throw new AppError('Connection request not found', 404);
    }

    res.json({
      success: true,
      data: connection,
    });
  })
);

/**
 * POST /api/connections/:id/decline
 * Decline connection request
 */
router.post(
  '/:id/decline',
  authenticate,
  asyncHandler(async (req, res) => {
    const { id } = req.params;
    const userId = req.userId;

    const { data: connection, error } = await supabase
      .from('connections')
      .update({ status: 'declined' })
      .eq('id', id)
      .eq('recipient_id', userId)
      .eq('status', 'pending')
      .select()
      .single();

    if (error || !connection) {
      throw new AppError('Connection request not found', 404);
    }

    res.json({
      success: true,
      data: connection,
    });
  })
);

/**
 * GET /api/connections/pending
 * Get pending connection requests
 */
router.get(
  '/pending',
  authenticate,
  asyncHandler(async (req, res) => {
    const userId = req.userId;

    const { data: requests, error } = await supabase
      .from('connections')
      .select(`
        *,
        requester:users!requester_id(id, full_name, profile_photo_url, current_role, current_company, tagline)
      `)
      .eq('recipient_id', userId)
      .eq('status', 'pending')
      .order('created_at', { ascending: false });

    if (error) {
      throw new AppError('Failed to fetch pending requests', 500);
    }

    res.json({
      success: true,
      data: requests,
    });
  })
);

/**
 * GET /api/connections
 * Get all accepted connections
 */
router.get(
  '/',
  authenticate,
  asyncHandler(async (req, res) => {
    const userId = req.userId;

    const { data: connections, error } = await supabase
      .from('connections')
      .select(`
        *,
        requester:users!requester_id(*),
        recipient:users!recipient_id(*)
      `)
      .or(`requester_id.eq.${userId},recipient_id.eq.${userId}`)
      .eq('status', 'accepted')
      .order('accepted_at', { ascending: false });

    if (error) {
      throw new AppError('Failed to fetch connections', 500);
    }

    // Format to return the other person's data
    const formatted = connections.map((conn) => ({
      ...conn,
      user: conn.requester_id === userId ? conn.recipient : conn.requester,
    }));

    res.json({
      success: true,
      data: formatted,
    });
  })
);

/**
 * POST /api/connections/draft-message
 * AI-draft connection introduction message
 */
router.post(
  '/draft-message',
  authenticate,
  aiLimiter,
  [body('recipient_id').isUUID(), validate],
  asyncHandler(async (req, res) => {
    const senderId = req.userId;
    const { recipient_id } = req.body;

    const [sender, recipient] = await Promise.all([
      supabase.from('users').select('*').eq('id', senderId).single(),
      supabase.from('users').select('*').eq('id', recipient_id).single(),
    ]);

    const message = await claudeService.draftConnectionMessage(sender.data, recipient.data);

    res.json({
      success: true,
      data: { message },
    });
  })
);

/**
 * DELETE /api/connections/:id
 * Remove connection
 */
router.delete(
  '/:id',
  authenticate,
  asyncHandler(async (req, res) => {
    const { id } = req.params;
    const userId = req.userId;

    const { error } = await supabase
      .from('connections')
      .delete()
      .eq('id', id)
      .or(`requester_id.eq.${userId},recipient_id.eq.${userId}`);

    if (error) {
      throw new AppError('Failed to remove connection', 500);
    }

    res.json({
      success: true,
      message: 'Connection removed',
    });
  })
);

export default router;
