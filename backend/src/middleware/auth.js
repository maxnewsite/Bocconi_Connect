import { supabase } from '../config/supabase.js';
import { AppError } from './errorHandler.js';
import { asyncHandler } from './errorHandler.js';

export const authenticate = asyncHandler(async (req, res, next) => {
  // Get token from Authorization header
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    throw new AppError('No token provided', 401);
  }

  const token = authHeader.split(' ')[1];

  try {
    // Verify token with Supabase
    const { data: { user }, error } = await supabase.auth.getUser(token);

    if (error || !user) {
      throw new AppError('Invalid or expired token', 401);
    }

    // Fetch full user profile
    const { data: profile, error: profileError } = await supabase
      .from('users')
      .select('*')
      .eq('id', user.id)
      .single();

    if (profileError) {
      throw new AppError('User profile not found', 404);
    }

    if (!profile.is_active) {
      throw new AppError('Account is inactive', 403);
    }

    // Attach user to request
    req.user = profile;
    req.userId = user.id;

    // Update last active timestamp
    await supabase
      .from('users')
      .update({ last_active_at: new Date().toISOString() })
      .eq('id', user.id);

    next();
  } catch (error) {
    throw new AppError('Authentication failed', 401);
  }
});

export const requireAdmin = asyncHandler(async (req, res, next) => {
  if (!req.user || !req.user.is_admin) {
    throw new AppError('Admin access required', 403);
  }
  next();
});

export const requireOnboarding = asyncHandler(async (req, res, next) => {
  if (!req.user || !req.user.onboarding_completed) {
    throw new AppError('Please complete onboarding first', 403);
  }
  next();
});

// Optional auth - doesn't fail if no token
export const optionalAuth = asyncHandler(async (req, res, next) => {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return next();
  }

  const token = authHeader.split(' ')[1];

  try {
    const { data: { user } } = await supabase.auth.getUser(token);

    if (user) {
      const { data: profile } = await supabase
        .from('users')
        .select('*')
        .eq('id', user.id)
        .single();

      if (profile) {
        req.user = profile;
        req.userId = user.id;
      }
    }
  } catch (error) {
    // Silent fail for optional auth
  }

  next();
});
