import express from 'express';
import { body } from 'express-validator';
import { authenticate } from '../middleware/auth.js';
import { AppError, asyncHandler } from '../middleware/errorHandler.js';
import { validate } from '../middleware/validation.js';
import { aiLimiter } from '../middleware/rateLimiter.js';
import claudeService from '../services/claudeService.js';
import embeddingService from '../services/embeddingService.js';
import { supabase } from '../config/supabase.js';

const router = express.Router();

/**
 * POST /api/onboarding/start
 * Start onboarding conversation
 */
router.post(
  '/start',
  authenticate,
  asyncHandler(async (req, res) => {
    const userId = req.userId;

    // Check if already completed onboarding
    const { data: user } = await supabase
      .from('users')
      .select('onboarding_completed')
      .eq('id', userId)
      .single();

    if (user?.onboarding_completed) {
      throw new AppError('Onboarding already completed', 400);
    }

    // Initial welcome message
    const welcomeMessage = `Welcome to Bocconi GCC Alumni Connect! 🎓

I'm B_AI, your personal assistant for this platform. I'm excited to help you create your profile through a friendly conversation.

This will take about 5-10 minutes. We'll talk about:
- Your Bocconi background
- Your current role and career journey
- What you're passionate about
- How you can help fellow alumni
- What you're looking for from the community

Ready to get started? Let's begin with your time at Bocconi. What program did you graduate from, and in which year?`;

    // Save initial conversation
    const conversationHistory = [
      { role: 'assistant', content: welcomeMessage },
    ];

    await supabase
      .from('users')
      .update({ onboarding_chat_history: conversationHistory })
      .eq('id', userId);

    res.json({
      success: true,
      data: {
        message: welcomeMessage,
        conversationHistory,
      },
    });
  })
);

/**
 * POST /api/onboarding/chat
 * Continue onboarding conversation
 */
router.post(
  '/chat',
  authenticate,
  aiLimiter,
  [body('message').trim().notEmpty(), validate],
  asyncHandler(async (req, res) => {
    const userId = req.userId;
    const { message } = req.body;

    // Get conversation history
    const { data: user } = await supabase
      .from('users')
      .select('onboarding_chat_history, onboarding_completed')
      .eq('id', userId)
      .single();

    if (user?.onboarding_completed) {
      throw new AppError('Onboarding already completed', 400);
    }

    const conversationHistory = user?.onboarding_chat_history || [];

    // Get AI response
    const { message: aiResponse, conversationHistory: updatedHistory } =
      await claudeService.handleOnboardingChat(
        userId,
        message,
        conversationHistory
      );

    // Save updated conversation
    await supabase
      .from('users')
      .update({ onboarding_chat_history: updatedHistory })
      .eq('id', userId);

    res.json({
      success: true,
      data: {
        message: aiResponse,
        conversationHistory: updatedHistory,
      },
    });
  })
);

/**
 * POST /api/onboarding/extract-profile
 * Extract structured profile data from conversation
 */
router.post(
  '/extract-profile',
  authenticate,
  aiLimiter,
  asyncHandler(async (req, res) => {
    const userId = req.userId;

    // Get conversation history
    const { data: user } = await supabase
      .from('users')
      .select('onboarding_chat_history')
      .eq('id', userId)
      .single();

    const conversationHistory = user?.onboarding_chat_history || [];

    if (conversationHistory.length < 10) {
      throw new AppError('Please complete more of the conversation first', 400);
    }

    // Extract profile data using AI
    const profileData = await claudeService.extractProfileData(conversationHistory);

    res.json({
      success: true,
      data: profileData,
    });
  })
);

/**
 * POST /api/onboarding/save-profile
 * Save final profile and complete onboarding
 */
router.post(
  '/save-profile',
  authenticate,
  [
    body('current_role').optional().trim(),
    body('current_company').optional().trim(),
    body('current_industry').optional().trim(),
    body('location_city').optional().trim(),
    body('location_country').optional().trim(),
    body('bio').optional().trim(),
    body('expertise_tags').optional().isArray(),
    body('passions').optional().isArray(),
    validate,
  ],
  asyncHandler(async (req, res) => {
    const userId = req.userId;
    const profileData = req.body;

    // Update user profile
    const { data: user, error: updateError } = await supabase
      .from('users')
      .update({
        ...profileData,
        onboarding_completed: true,
      })
      .eq('id', userId)
      .select()
      .single();

    if (updateError) {
      throw new AppError('Failed to save profile', 500);
    }

    // Save offerings if provided
    if (profileData.offerings && profileData.offerings.length > 0) {
      await supabase.from('profile_offerings').insert(
        profileData.offerings.map((offering) => ({
          user_id: userId,
          ...offering,
        }))
      );
    }

    // Save seeking if provided
    if (profileData.seeking && profileData.seeking.length > 0) {
      await supabase.from('profile_seeking').insert(
        profileData.seeking.map((seeking) => ({
          user_id: userId,
          ...seeking,
        }))
      );
    }

    // Generate profile embedding for AI matching
    try {
      await embeddingService.generateProfileEmbedding(userId);
    } catch (error) {
      // Non-critical error, log but don't fail
      console.error('Failed to generate embedding:', error);
    }

    // Get top 3 matches
    let topMatches = [];
    try {
      topMatches = await embeddingService.findSimilarProfiles(userId, 3);
    } catch (error) {
      console.error('Failed to find matches:', error);
    }

    res.json({
      success: true,
      data: {
        user,
        topMatches,
      },
      message: 'Onboarding completed successfully!',
    });
  })
);

/**
 * GET /api/onboarding/resume
 * Resume onboarding conversation
 */
router.get(
  '/resume',
  authenticate,
  asyncHandler(async (req, res) => {
    const userId = req.userId;

    const { data: user } = await supabase
      .from('users')
      .select('onboarding_chat_history, onboarding_completed')
      .eq('id', userId)
      .single();

    if (user?.onboarding_completed) {
      return res.json({
        success: true,
        data: {
          completed: true,
        },
      });
    }

    res.json({
      success: true,
      data: {
        completed: false,
        conversationHistory: user?.onboarding_chat_history || [],
      },
    });
  })
);

export default router;
