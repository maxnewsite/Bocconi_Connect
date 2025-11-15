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
 * GET /api/messages/conversations
 * Get list of conversations
 */
router.get(
  '/conversations',
  authenticate,
  asyncHandler(async (req, res) => {
    const userId = req.userId;

    // Get unique conversation partners
    const { data: messages, error } = await supabase
      .from('messages')
      .select('sender_id, recipient_id, created_at')
      .or(`sender_id.eq.${userId},recipient_id.eq.${userId}`)
      .order('created_at', { ascending: false });

    if (error) {
      throw new AppError('Failed to fetch conversations', 500);
    }

    // Extract unique user IDs
    const userIds = new Set();
    messages.forEach((msg) => {
      const otherId = msg.sender_id === userId ? msg.recipient_id : msg.sender_id;
      userIds.add(otherId);
    });

    if (userIds.size === 0) {
      return res.json({ success: true, data: [] });
    }

    // Get user details
    const { data: users } = await supabase
      .from('users')
      .select('id, full_name, profile_photo_url, current_role, current_company')
      .in('id', Array.from(userIds));

    // Get last message and unread count for each conversation
    const conversations = await Promise.all(
      users.map(async (user) => {
        const { data: lastMessage } = await supabase
          .from('messages')
          .select('*')
          .or(`and(sender_id.eq.${userId},recipient_id.eq.${user.id}),and(sender_id.eq.${user.id},recipient_id.eq.${userId})`)
          .order('created_at', { ascending: false })
          .limit(1)
          .single();

        const { count: unreadCount } = await supabase
          .from('messages')
          .select('*', { count: 'exact', head: true })
          .eq('sender_id', user.id)
          .eq('recipient_id', userId)
          .eq('is_read', false);

        return {
          user,
          lastMessage,
          unreadCount,
        };
      })
    );

    // Sort by last message time
    conversations.sort((a, b) => new Date(b.lastMessage.created_at) - new Date(a.lastMessage.created_at));

    res.json({
      success: true,
      data: conversations,
    });
  })
);

/**
 * GET /api/messages/:userId
 * Get messages with specific user
 */
router.get(
  '/:userId',
  authenticate,
  [query('limit').optional().isInt({ min: 1, max: 100 }).toInt(), query('before').optional().isISO8601(), validate],
  asyncHandler(async (req, res) => {
    const currentUserId = req.userId;
    const { userId } = req.params;
    const { limit = 50, before } = req.query;

    // Verify connection exists
    const { data: connection } = await supabase
      .from('connections')
      .select('*')
      .or(`and(requester_id.eq.${currentUserId},recipient_id.eq.${userId}),and(requester_id.eq.${userId},recipient_id.eq.${currentUserId})`)
      .eq('status', 'accepted')
      .single();

    if (!connection) {
      throw new AppError('Not connected with this user', 403);
    }

    let query = supabase
      .from('messages')
      .select('*')
      .or(`and(sender_id.eq.${currentUserId},recipient_id.eq.${userId}),and(sender_id.eq.${userId},recipient_id.eq.${currentUserId})`)
      .order('created_at', { ascending: false })
      .limit(limit);

    if (before) {
      query = query.lt('created_at', before);
    }

    const { data: messages, error } = await query;

    if (error) {
      throw new AppError('Failed to fetch messages', 500);
    }

    // Mark messages as read
    await supabase
      .from('messages')
      .update({ is_read: true, read_at: new Date().toISOString() })
      .eq('sender_id', userId)
      .eq('recipient_id', currentUserId)
      .eq('is_read', false);

    res.json({
      success: true,
      data: messages.reverse(), // Return in chronological order
    });
  })
);

/**
 * POST /api/messages/send
 * Send a message
 */
router.post(
  '/send',
  authenticate,
  [body('recipient_id').isUUID(), body('content').trim().notEmpty().isLength({ max: 5000 }), body('attachment_url').optional().isURL(), validate],
  asyncHandler(async (req, res) => {
    const senderId = req.userId;
    const { recipient_id, content, attachment_url } = req.body;

    // Verify connection
    const { data: connection } = await supabase
      .from('connections')
      .select('*')
      .or(`and(requester_id.eq.${senderId},recipient_id.eq.${recipient_id}),and(requester_id.eq.${recipient_id},recipient_id.eq.${senderId})`)
      .eq('status', 'accepted')
      .single();

    if (!connection) {
      throw new AppError('Not connected with this user', 403);
    }

    const { data: message, error } = await supabase
      .from('messages')
      .insert({
        sender_id: senderId,
        recipient_id,
        content,
        attachment_url,
      })
      .select()
      .single();

    if (error) {
      throw new AppError('Failed to send message', 500);
    }

    // Emit socket event for real-time delivery
    const io = req.app.get('io');
    io.to(recipient_id).emit('new_message', message);

    res.status(201).json({
      success: true,
      data: message,
    });
  })
);

/**
 * POST /api/messages/enhance
 * AI-enhance a message
 */
router.post(
  '/enhance',
  authenticate,
  aiLimiter,
  [body('message').trim().notEmpty(), body('context').optional().trim(), validate],
  asyncHandler(async (req, res) => {
    const { message, context } = req.body;

    const enhanced = await claudeService.enhanceMessage(message, context);

    res.json({
      success: true,
      data: { enhanced },
    });
  })
);

/**
 * PUT /api/messages/:id/read
 * Mark message as read
 */
router.put(
  '/:id/read',
  authenticate,
  asyncHandler(async (req, res) => {
    const { id } = req.params;
    const userId = req.userId;

    const { data: message, error } = await supabase
      .from('messages')
      .update({ is_read: true, read_at: new Date().toISOString() })
      .eq('id', id)
      .eq('recipient_id', userId)
      .select()
      .single();

    if (error) {
      throw new AppError('Message not found', 404);
    }

    res.json({
      success: true,
      data: message,
    });
  })
);

/**
 * GET /api/messages/unread/count
 * Get unread message count
 */
router.get(
  '/unread/count',
  authenticate,
  asyncHandler(async (req, res) => {
    const userId = req.userId;

    const { count } = await supabase
      .from('messages')
      .select('*', { count: 'exact', head: true })
      .eq('recipient_id', userId)
      .eq('is_read', false);

    res.json({
      success: true,
      data: { count },
    });
  })
);

export default router;
