import express from 'express';
import { body } from 'express-validator';
import { authenticate } from '../middleware/auth.js';
import { asyncHandler } from '../middleware/errorHandler.js';
import { validate } from '../middleware/validation.js';
import { aiLimiter } from '../middleware/rateLimiter.js';
import claudeService from '../services/claudeService.js';

const router = express.Router();

// Apply AI rate limiting to all routes
router.use(aiLimiter);

/**
 * POST /api/ai/quick-ask
 * Quick AI assistant for general queries
 */
router.post(
  '/quick-ask',
  authenticate,
  [body('question').trim().notEmpty(), validate],
  asyncHandler(async (req, res) => {
    const { question } = req.body;
    const userContext = {
      userId: req.userId,
      name: req.user.full_name,
    };

    const answer = await claudeService.quickAsk(question, userContext);

    res.json({
      success: true,
      data: { answer },
    });
  })
);

/**
 * POST /api/ai/suggest-tags
 * Get AI-suggested tags for Q&A
 */
router.post(
  '/suggest-tags',
  authenticate,
  [body('title').trim().notEmpty(), body('description').trim().notEmpty(), validate],
  asyncHandler(async (req, res) => {
    const { title, description } = req.body;

    const tags = await claudeService.suggestTags(title, description);

    res.json({
      success: true,
      data: { tags },
    });
  })
);

export default router;
