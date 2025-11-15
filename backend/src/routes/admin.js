import express from 'express';
import { authenticate, requireAdmin } from '../middleware/auth.js';
import { AppError, asyncHandler } from '../middleware/errorHandler.js';
import { supabase } from '../config/supabase.js';

const router = express.Router();

// All admin routes require authentication and admin role
router.use(authenticate, requireAdmin);

/**
 * GET /api/admin/users
 * Get all users
 */
router.get(
  '/users',
  asyncHandler(async (req, res) => {
    const { page = 1, limit = 50, active_only } = req.query;

    let query = supabase
      .from('users')
      .select('*', { count: 'exact' });

    if (active_only === 'true') {
      query = query.eq('is_active', true);
    }

    const from = (page - 1) * limit;
    query = query.range(from, from + limit - 1).order('created_at', { ascending: false });

    const { data: users, error, count } = await query;

    if (error) {
      throw new AppError('Failed to fetch users', 500);
    }

    res.json({
      success: true,
      data: {
        users,
        pagination: {
          page: parseInt(page),
          limit: parseInt(limit),
          total: count,
          pages: Math.ceil(count / limit),
        },
      },
    });
  })
);

/**
 * PUT /api/admin/users/:id/suspend
 * Suspend user
 */
router.put(
  '/users/:id/suspend',
  asyncHandler(async (req, res) => {
    const { id } = req.params;

    const { data: user, error } = await supabase
      .from('users')
      .update({ is_active: false })
      .eq('id', id)
      .select()
      .single();

    if (error) {
      throw new AppError('Failed to suspend user', 500);
    }

    res.json({
      success: true,
      data: user,
      message: 'User suspended',
    });
  })
);

/**
 * PUT /api/admin/users/:id/activate
 * Activate user
 */
router.put(
  '/users/:id/activate',
  asyncHandler(async (req, res) => {
    const { id } = req.params;

    const { data: user, error } = await supabase
      .from('users')
      .update({ is_active: true })
      .eq('id', id)
      .select()
      .single();

    if (error) {
      throw new AppError('Failed to activate user', 500);
    }

    res.json({
      success: true,
      data: user,
      message: 'User activated',
    });
  })
);

/**
 * GET /api/admin/analytics
 * Get platform analytics
 */
router.get(
  '/analytics',
  asyncHandler(async (req, res) => {
    const [
      totalUsers,
      activeUsers,
      connections,
      events,
      questions,
      messages,
    ] = await Promise.all([
      supabase.from('users').select('id', { count: 'exact', head: true }),
      supabase.from('users').select('id', { count: 'exact', head: true }).eq('is_active', true),
      supabase.from('connections').select('id', { count: 'exact', head: true }).eq('status', 'accepted'),
      supabase.from('events').select('id', { count: 'exact', head: true }).eq('is_published', true),
      supabase.from('qa_questions').select('id', { count: 'exact', head: true }),
      supabase.from('messages').select('id', { count: 'exact', head: true }),
    ]);

    res.json({
      success: true,
      data: {
        totalUsers: totalUsers.count,
        activeUsers: activeUsers.count,
        totalConnections: connections.count,
        totalEvents: events.count,
        totalQuestions: questions.count,
        totalMessages: messages.count,
      },
    });
  })
);

/**
 * PUT /api/admin/events/:id/feature
 * Feature/unfeature event
 */
router.put(
  '/events/:id/feature',
  asyncHandler(async (req, res) => {
    const { id } = req.params;
    const { featured } = req.body;

    const { data: event, error } = await supabase
      .from('events')
      .update({ is_featured: featured })
      .eq('id', id)
      .select()
      .single();

    if (error) {
      throw new AppError('Failed to update event', 500);
    }

    res.json({
      success: true,
      data: event,
    });
  })
);

export default router;
