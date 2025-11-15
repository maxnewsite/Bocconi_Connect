import express from 'express';
import { query } from 'express-validator';
import { authenticate } from '../middleware/auth.js';
import { asyncHandler } from '../middleware/errorHandler.js';
import { validate } from '../middleware/validation.js';
import { supabase } from '../config/supabase.js';
import embeddingService from '../services/embeddingService.js';

const router = express.Router();

/**
 * GET /api/members
 * Get all members with filters
 */
router.get(
  '/',
  authenticate,
  [
    query('search').optional().trim(),
    query('location_city').optional().trim(),
    query('location_country').optional().trim(),
    query('industry').optional().trim(),
    query('graduation_year').optional().isInt(),
    query('offering_type').optional().trim(),
    query('seeking_type').optional().trim(),
    query('page').optional().isInt({ min: 1 }).toInt(),
    query('limit').optional().isInt({ min: 1, max: 100 }).toInt(),
    validate,
  ],
  asyncHandler(async (req, res) => {
    const {
      search,
      location_city,
      location_country,
      industry,
      graduation_year,
      offering_type,
      seeking_type,
      page = 1,
      limit = 20,
    } = req.query;

    let query = supabase
      .from('users')
      .select('*', { count: 'exact' })
      .eq('is_active', true)
      .eq('onboarding_completed', true);

    // Apply filters
    if (location_city) {
      query = query.eq('location_city', location_city);
    }
    if (location_country) {
      query = query.eq('location_country', location_country);
    }
    if (industry) {
      query = query.eq('current_industry', industry);
    }
    if (graduation_year) {
      query = query.eq('graduation_year', parseInt(graduation_year));
    }

    // Text search
    if (search) {
      query = query.or(
        `full_name.ilike.%${search}%,bio.ilike.%${search}%,current_role.ilike.%${search}%,current_company.ilike.%${search}%`
      );
    }

    // Pagination
    const from = (page - 1) * limit;
    query = query.range(from, from + limit - 1);

    // Order by last active
    query = query.order('last_active_at', { ascending: false });

    const { data: users, error, count } = await query;

    if (error) {
      throw new Error('Failed to fetch members');
    }

    // If offering/seeking type filter, filter in memory (more complex query)
    let filteredUsers = users;
    if (offering_type || seeking_type) {
      const userIds = users.map((u) => u.id);

      if (offering_type) {
        const { data: offerings } = await supabase
          .from('profile_offerings')
          .select('user_id')
          .in('user_id', userIds)
          .eq('offering_type', offering_type);

        const offeringUserIds = new Set(offerings.map((o) => o.user_id));
        filteredUsers = filteredUsers.filter((u) => offeringUserIds.has(u.id));
      }

      if (seeking_type) {
        const { data: seeking } = await supabase
          .from('profile_seeking')
          .select('user_id')
          .in('user_id', userIds)
          .eq('seeking_type', seeking_type);

        const seekingUserIds = new Set(seeking.map((s) => s.user_id));
        filteredUsers = filteredUsers.filter((u) => seekingUserIds.has(u.id));
      }
    }

    res.json({
      success: true,
      data: {
        members: filteredUsers,
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
 * GET /api/members/search/semantic
 * Semantic search using AI embeddings
 */
router.get(
  '/search/semantic',
  authenticate,
  [query('q').trim().notEmpty(), query('limit').optional().isInt({ min: 1, max: 50 }).toInt(), validate],
  asyncHandler(async (req, res) => {
    const { q, limit = 20 } = req.query;

    const results = await embeddingService.semanticSearch(q, limit);

    res.json({
      success: true,
      data: results,
    });
  })
);

/**
 * GET /api/members/suggestions
 * Get suggested connections based on AI matching
 */
router.get(
  '/suggestions',
  authenticate,
  [query('limit').optional().isInt({ min: 1, max: 20 }).toInt(), validate],
  asyncHandler(async (req, res) => {
    const userId = req.userId;
    const { limit = 10 } = req.query;

    const suggestions = await embeddingService.findSimilarProfiles(userId, limit);

    res.json({
      success: true,
      data: suggestions,
    });
  })
);

/**
 * GET /api/members/filters
 * Get available filter options
 */
router.get(
  '/filters',
  authenticate,
  asyncHandler(async (req, res) => {
    // Get unique values for filters
    const [cities, countries, industries, years] = await Promise.all([
      supabase
        .from('users')
        .select('location_city')
        .eq('is_active', true)
        .not('location_city', 'is', null),

      supabase
        .from('users')
        .select('location_country')
        .eq('is_active', true)
        .not('location_country', 'is', null),

      supabase
        .from('users')
        .select('current_industry')
        .eq('is_active', true)
        .not('current_industry', 'is', null),

      supabase
        .from('users')
        .select('graduation_year')
        .eq('is_active', true)
        .order('graduation_year', { ascending: false }),
    ]);

    res.json({
      success: true,
      data: {
        cities: [...new Set(cities.data.map((c) => c.location_city))].sort(),
        countries: [...new Set(countries.data.map((c) => c.location_country))].sort(),
        industries: [...new Set(industries.data.map((i) => i.current_industry))].sort(),
        graduationYears: [...new Set(years.data.map((y) => y.graduation_year))].sort((a, b) => b - a),
        offeringTypes: ['mentorship', 'job_opportunities', 'investment', 'advice', 'connections'],
        seekingTypes: ['mentorship', 'job_opportunities', 'investment', 'partnerships', 'learning'],
      },
    });
  })
);

export default router;
