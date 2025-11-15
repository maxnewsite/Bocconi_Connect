import express from 'express';
import { body } from 'express-validator';
import { supabase } from '../config/supabase.js';
import { AppError, asyncHandler } from '../middleware/errorHandler.js';
import { validate } from '../middleware/validation.js';
import { authLimiter } from '../middleware/rateLimiter.js';

const router = express.Router();

// Apply rate limiting to all auth routes
router.use(authLimiter);

/**
 * POST /api/auth/signup
 * Register new user with email
 */
router.post(
  '/signup',
  [
    body('email').isEmail().normalizeEmail(),
    body('password').isLength({ min: 8 }),
    body('full_name').trim().notEmpty(),
    body('graduation_year').isInt({ min: 1940, max: new Date().getFullYear() + 5 }),
    body('program').trim().notEmpty(),
    validate,
  ],
  asyncHandler(async (req, res) => {
    const { email, password, full_name, graduation_year, program } = req.body;

    // Create auth user
    const { data: authData, error: authError } = await supabase.auth.signUp({
      email,
      password,
    });

    if (authError) {
      throw new AppError(authError.message, 400);
    }

    // Create user profile
    const { data: user, error: userError } = await supabase
      .from('users')
      .insert({
        id: authData.user.id,
        email,
        full_name,
        graduation_year,
        program,
      })
      .select()
      .single();

    if (userError) {
      // Rollback auth user if profile creation fails
      await supabase.auth.admin.deleteUser(authData.user.id);
      throw new AppError('Failed to create user profile', 500);
    }

    res.status(201).json({
      success: true,
      data: {
        user,
        session: authData.session,
      },
    });
  })
);

/**
 * POST /api/auth/login
 * Login with email and password
 */
router.post(
  '/login',
  [
    body('email').isEmail().normalizeEmail(),
    body('password').notEmpty(),
    validate,
  ],
  asyncHandler(async (req, res) => {
    const { email, password } = req.body;

    const { data, error } = await supabase.auth.signInWithPassword({
      email,
      password,
    });

    if (error) {
      throw new AppError('Invalid credentials', 401);
    }

    // Fetch user profile
    const { data: user } = await supabase
      .from('users')
      .select('*')
      .eq('id', data.user.id)
      .single();

    res.json({
      success: true,
      data: {
        user,
        session: data.session,
      },
    });
  })
);

/**
 * POST /api/auth/logout
 * Logout current user
 */
router.post(
  '/logout',
  asyncHandler(async (req, res) => {
    const token = req.headers.authorization?.split(' ')[1];

    if (token) {
      await supabase.auth.signOut(token);
    }

    res.json({
      success: true,
      message: 'Logged out successfully',
    });
  })
);

/**
 * POST /api/auth/refresh
 * Refresh access token
 */
router.post(
  '/refresh',
  asyncHandler(async (req, res) => {
    const { refresh_token } = req.body;

    if (!refresh_token) {
      throw new AppError('Refresh token required', 400);
    }

    const { data, error } = await supabase.auth.refreshSession({
      refresh_token,
    });

    if (error) {
      throw new AppError('Invalid refresh token', 401);
    }

    res.json({
      success: true,
      data: {
        session: data.session,
      },
    });
  })
);

/**
 * POST /api/auth/reset-password
 * Request password reset email
 */
router.post(
  '/reset-password',
  [body('email').isEmail().normalizeEmail(), validate],
  asyncHandler(async (req, res) => {
    const { email } = req.body;

    const { error } = await supabase.auth.resetPasswordForEmail(email, {
      redirectTo: `${process.env.FRONTEND_URL}/reset-password`,
    });

    if (error) {
      throw new AppError(error.message, 400);
    }

    res.json({
      success: true,
      message: 'Password reset email sent',
    });
  })
);

/**
 * POST /api/auth/update-password
 * Update password with reset token
 */
router.post(
  '/update-password',
  [body('password').isLength({ min: 8 }), validate],
  asyncHandler(async (req, res) => {
    const { password } = req.body;
    const token = req.headers.authorization?.split(' ')[1];

    if (!token) {
      throw new AppError('Reset token required', 400);
    }

    const { error } = await supabase.auth.updateUser({
      password,
    });

    if (error) {
      throw new AppError(error.message, 400);
    }

    res.json({
      success: true,
      message: 'Password updated successfully',
    });
  })
);

/**
 * GET /api/auth/me
 * Get current user profile
 */
router.get(
  '/me',
  asyncHandler(async (req, res) => {
    const token = req.headers.authorization?.split(' ')[1];

    if (!token) {
      throw new AppError('Not authenticated', 401);
    }

    const { data: { user }, error } = await supabase.auth.getUser(token);

    if (error || !user) {
      throw new AppError('Invalid token', 401);
    }

    const { data: profile } = await supabase
      .from('users')
      .select('*')
      .eq('id', user.id)
      .single();

    res.json({
      success: true,
      data: profile,
    });
  })
);

export default router;
