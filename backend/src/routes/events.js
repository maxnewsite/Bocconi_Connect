import express from 'express';
import { body, query } from 'express-validator';
import { authenticate } from '../middleware/auth.js';
import { AppError, asyncHandler } from '../middleware/errorHandler.js';
import { validate } from '../middleware/validation.js';
import { supabase } from '../config/supabase.js';
import QRCode from 'qrcode';
import { v4 as uuidv4 } from 'uuid';

const router = express.Router();

/**
 * GET /api/events
 * Get all published events
 */
router.get(
  '/',
  authenticate,
  [
    query('type').optional().isIn(['professional', 'social', 'educational', 'investment']),
    query('upcoming').optional().isBoolean(),
    query('page').optional().isInt({ min: 1 }).toInt(),
    query('limit').optional().isInt({ min: 1, max: 50 }).toInt(),
    validate,
  ],
  asyncHandler(async (req, res) => {
    const { type, upcoming, page = 1, limit = 20 } = req.query;

    let query = supabase
      .from('events')
      .select(`
        *,
        organizer:users!organizer_id(id, full_name, profile_photo_url),
        rsvps:event_rsvps(count)
      `, { count: 'exact' })
      .eq('is_published', true);

    if (type) {
      query = query.eq('event_type', type);
    }

    if (upcoming === 'true') {
      query = query.gte('start_date', new Date().toISOString());
    }

    const from = (page - 1) * limit;
    query = query.range(from, from + limit - 1).order('start_date', { ascending: true });

    const { data: events, error, count } = await query;

    if (error) {
      throw new AppError('Failed to fetch events', 500);
    }

    res.json({
      success: true,
      data: {
        events,
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
 * GET /api/events/:id
 * Get event details
 */
router.get(
  '/:id',
  authenticate,
  asyncHandler(async (req, res) => {
    const { id } = req.params;

    const { data: event, error } = await supabase
      .from('events')
      .select(`
        *,
        organizer:users!organizer_id(id, full_name, profile_photo_url, current_role, current_company),
        rsvps:event_rsvps(
          *,
          user:users(id, full_name, profile_photo_url)
        )
      `)
      .eq('id', id)
      .single();

    if (error || !event) {
      throw new AppError('Event not found', 404);
    }

    res.json({
      success: true,
      data: event,
    });
  })
);

/**
 * POST /api/events
 * Create new event
 */
router.post(
  '/',
  authenticate,
  [
    body('title').trim().notEmpty(),
    body('description').optional().trim(),
    body('event_type').isIn(['professional', 'social', 'educational', 'investment']),
    body('start_date').isISO8601(),
    body('end_date').optional().isISO8601(),
    body('location_name').optional().trim(),
    body('location_address').optional().trim(),
    body('is_virtual').optional().isBoolean(),
    body('virtual_link').optional().isURL(),
    body('capacity').optional().isInt({ min: 1 }),
    body('is_paid').optional().isBoolean(),
    body('price_amount').optional().isDecimal(),
    validate,
  ],
  asyncHandler(async (req, res) => {
    const organizerId = req.userId;
    const eventData = req.body;

    const { data: event, error } = await supabase
      .from('events')
      .insert({
        ...eventData,
        organizer_id: organizerId,
      })
      .select()
      .single();

    if (error) {
      throw new AppError('Failed to create event', 500);
    }

    res.status(201).json({
      success: true,
      data: event,
    });
  })
);

/**
 * PUT /api/events/:id
 * Update event
 */
router.put(
  '/:id',
  authenticate,
  asyncHandler(async (req, res) => {
    const { id } = req.params;
    const userId = req.userId;
    const updates = req.body;

    const { data: event, error } = await supabase
      .from('events')
      .update(updates)
      .eq('id', id)
      .eq('organizer_id', userId)
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

/**
 * POST /api/events/:id/rsvp
 * RSVP to event
 */
router.post(
  '/:id/rsvp',
  authenticate,
  asyncHandler(async (req, res) => {
    const { id: eventId } = req.params;
    const userId = req.userId;

    // Check event exists and has capacity
    const { data: event } = await supabase
      .from('events')
      .select('*')
      .eq('id', eventId)
      .eq('is_published', true)
      .single();

    if (!event) {
      throw new AppError('Event not found', 404);
    }

    // Generate QR code
    const qrData = JSON.stringify({ eventId, userId, rsvpId: uuidv4() });
    const qrCode = await QRCode.toDataURL(qrData);

    const { data: rsvp, error } = await supabase
      .from('event_rsvps')
      .insert({
        event_id: eventId,
        user_id: userId,
        payment_status: event.is_paid ? 'pending' : 'free',
        qr_code: qrCode,
      })
      .select()
      .single();

    if (error) {
      if (error.code === '23505') { // Unique constraint violation
        throw new AppError('Already RSVP\'d to this event', 400);
      }
      throw new AppError('Failed to RSVP', 500);
    }

    res.status(201).json({
      success: true,
      data: rsvp,
    });
  })
);

/**
 * DELETE /api/events/:id/rsvp
 * Cancel RSVP
 */
router.delete(
  '/:id/rsvp',
  authenticate,
  asyncHandler(async (req, res) => {
    const { id: eventId } = req.params;
    const userId = req.userId;

    const { error } = await supabase
      .from('event_rsvps')
      .update({ status: 'cancelled' })
      .eq('event_id', eventId)
      .eq('user_id', userId);

    if (error) {
      throw new AppError('Failed to cancel RSVP', 500);
    }

    res.json({
      success: true,
      message: 'RSVP cancelled',
    });
  })
);

/**
 * GET /api/events/my/attending
 * Get user's attended events
 */
router.get(
  '/my/attending',
  authenticate,
  asyncHandler(async (req, res) => {
    const userId = req.userId;

    const { data: rsvps } = await supabase
      .from('event_rsvps')
      .select(`
        *,
        event:events(*)
      `)
      .eq('user_id', userId)
      .in('status', ['attending', 'waitlist']);

    res.json({
      success: true,
      data: rsvps,
    });
  })
);

export default router;
