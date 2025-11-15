import OpenAI from 'openai';
import { config } from '../config/env.js';
import { logger } from '../config/logger.js';
import { supabase } from '../config/supabase.js';

const openai = new OpenAI({
  apiKey: config.openai.apiKey,
});

const EMBEDDING_MODEL = 'text-embedding-3-small';
const EMBEDDING_DIMENSIONS = 1536;

class EmbeddingService {
  constructor() {
    this.vectorEnabled = true; // Will be set to false if pgvector not available
  }

  /**
   * Generate embedding for user profile
   */
  async generateProfileEmbedding(userId) {
    try {
      // Check if OpenAI key is configured
      if (!config.openai.apiKey || config.openai.apiKey === 'your-openai-api-key') {
        logger.warn('OpenAI API key not configured, skipping embedding generation');
        return null;
      }

      // Fetch user profile data
      const { data: user, error } = await supabase
        .from('users')
        .select(`
          *,
          profile_offerings(*),
          profile_seeking(*)
        `)
        .eq('id', userId)
        .single();

      if (error || !user) {
        throw new Error('User not found');
      }

      // Create comprehensive text representation
      const embeddingText = this.createEmbeddingText(user);

      // Generate embedding
      const embedding = await this.generateEmbedding(embeddingText);

      // Try to store embedding in database (will fail gracefully if table doesn't exist)
      try {
        await supabase
          .from('profile_embeddings')
          .upsert({
            user_id: userId,
            embedding: embedding,
            embedding_text: embeddingText,
            updated_at: new Date().toISOString(),
          });

        logger.info(`Generated embedding for user ${userId}`);
      } catch (dbError) {
        // Table doesn't exist (pgvector not installed)
        if (dbError.message.includes('relation "profile_embeddings" does not exist')) {
          logger.warn('profile_embeddings table not found - pgvector extension not installed');
          this.vectorEnabled = false;
        } else {
          throw dbError;
        }
      }

      return embedding;
    } catch (error) {
      logger.error(`Embedding generation error: ${error.message}`);
      // Don't throw - allow the app to continue without embeddings
      return null;
    }
  }

  /**
   * Create text representation of profile for embedding
   */
  createEmbeddingText(user) {
    const parts = [];

    // Basic info
    parts.push(`${user.full_name}`);
    parts.push(`Graduated ${user.graduation_year} from ${user.program}`);

    // Current role
    if (user.current_role && user.current_company) {
      parts.push(`Currently ${user.current_role} at ${user.current_company}`);
    }

    if (user.current_industry) {
      parts.push(`Industry: ${user.current_industry}`);
    }

    // Location
    if (user.location_city && user.location_country) {
      parts.push(`Based in ${user.location_city}, ${user.location_country}`);
    }

    // Bio
    if (user.bio) {
      parts.push(user.bio);
    }

    // Expertise
    if (user.expertise_tags && user.expertise_tags.length > 0) {
      parts.push(`Expertise: ${user.expertise_tags.join(', ')}`);
    }

    // Passions
    if (user.passions && Array.isArray(user.passions)) {
      parts.push(`Interests: ${user.passions.join(', ')}`);
    }

    // Offerings
    if (user.profile_offerings && user.profile_offerings.length > 0) {
      const offerings = user.profile_offerings
        .map((o) => `${o.offering_type}: ${o.description || ''}`)
        .join('. ');
      parts.push(`Offering: ${offerings}`);
    }

    // Seeking
    if (user.profile_seeking && user.profile_seeking.length > 0) {
      const seeking = user.profile_seeking
        .map((s) => `${s.seeking_type}: ${s.description || ''}`)
        .join('. ');
      parts.push(`Seeking: ${seeking}`);
    }

    return parts.filter(Boolean).join('. ');
  }

  /**
   * Generate embedding from text
   */
  async generateEmbedding(text) {
    try {
      const response = await openai.embeddings.create({
        model: EMBEDDING_MODEL,
        input: text,
        dimensions: EMBEDDING_DIMENSIONS,
      });

      return response.data[0].embedding;
    } catch (error) {
      logger.error(`OpenAI embedding error: ${error.message}`);
      throw new Error('Failed to generate embedding');
    }
  }

  /**
   * Find similar profiles using vector search
   * Falls back to basic matching if pgvector not available
   */
  async findSimilarProfiles(userId, limit = 10, threshold = 0.7) {
    try {
      // Check if vector search is available
      if (!this.vectorEnabled) {
        logger.info('Vector search disabled, using fallback matching');
        return this.findSimilarProfilesFallback(userId, limit);
      }

      // Get user's embedding
      const { data: userEmbedding, error: embError } = await supabase
        .from('profile_embeddings')
        .select('embedding')
        .eq('user_id', userId)
        .single();

      if (embError) {
        // Table doesn't exist, use fallback
        logger.warn('profile_embeddings table not available, using fallback');
        this.vectorEnabled = false;
        return this.findSimilarProfilesFallback(userId, limit);
      }

      if (!userEmbedding) {
        // Generate if not exists
        await this.generateProfileEmbedding(userId);
        return this.findSimilarProfiles(userId, limit, threshold);
      }

      // Use Supabase function for vector similarity search
      const { data: matches, error } = await supabase.rpc('match_profiles', {
        query_embedding: userEmbedding.embedding,
        match_threshold: threshold,
        match_count: limit + 1, // +1 because it includes self
      });

      if (error) {
        logger.error(`Vector search error: ${error.message}`);
        // Fall back to basic matching
        return this.findSimilarProfilesFallback(userId, limit);
      }

      // Filter out self and fetch full profiles
      const similarUserIds = matches
        .filter((m) => m.user_id !== userId)
        .slice(0, limit)
        .map((m) => m.user_id);

      if (similarUserIds.length === 0) {
        return [];
      }

      const { data: users } = await supabase
        .from('users')
        .select('*')
        .in('id', similarUserIds)
        .eq('is_active', true);

      return users || [];
    } catch (error) {
      logger.error(`Similar profiles search error: ${error.message}`);
      // Fall back to basic matching
      return this.findSimilarProfilesFallback(userId, limit);
    }
  }

  /**
   * Fallback matching without vector search
   * Matches based on industry, location, and graduation year
   */
  async findSimilarProfilesFallback(userId, limit = 10) {
    try {
      // Get current user
      const { data: currentUser } = await supabase
        .from('users')
        .select('current_industry, location_country, graduation_year')
        .eq('id', userId)
        .single();

      if (!currentUser) return [];

      // Find users with similar attributes
      let query = supabase
        .from('users')
        .select('*')
        .eq('is_active', true)
        .eq('onboarding_completed', true)
        .neq('id', userId)
        .limit(limit);

      // Prefer same industry
      if (currentUser.current_industry) {
        query = query.eq('current_industry', currentUser.current_industry);
      }

      const { data: users } = await query;

      return users || [];
    } catch (error) {
      logger.error(`Fallback matching error: ${error.message}`);
      return [];
    }
  }

  /**
   * Semantic search across all profiles
   * Falls back to text search if pgvector not available
   */
  async semanticSearch(searchQuery, limit = 20) {
    try {
      // If vector search not available, use text search
      if (!this.vectorEnabled) {
        logger.info('Using text search instead of semantic search');
        return this.textSearch(searchQuery, limit);
      }

      // Generate embedding for search query
      const queryEmbedding = await this.generateEmbedding(searchQuery);

      // Search using vector similarity
      const { data: matches, error } = await supabase.rpc('match_profiles', {
        query_embedding: queryEmbedding,
        match_threshold: 0.6,
        match_count: limit,
      });

      if (error) {
        logger.error(`Semantic search error: ${error.message}`);
        // Fall back to text search
        return this.textSearch(searchQuery, limit);
      }

      const userIds = matches.map((m) => m.user_id);

      if (userIds.length === 0) {
        return [];
      }

      const { data: users } = await supabase
        .from('users')
        .select('*')
        .in('id', userIds)
        .eq('is_active', true);

      return users || [];
    } catch (error) {
      logger.error(`Semantic search error: ${error.message}`);
      // Fall back to text search
      return this.textSearch(searchQuery, limit);
    }
  }

  /**
   * Text-based search fallback
   */
  async textSearch(searchQuery, limit = 20) {
    try {
      const { data: users } = await supabase
        .from('users')
        .select('*')
        .eq('is_active', true)
        .eq('onboarding_completed', true)
        .or(
          `full_name.ilike.%${searchQuery}%,bio.ilike.%${searchQuery}%,current_role.ilike.%${searchQuery}%,current_company.ilike.%${searchQuery}%,current_industry.ilike.%${searchQuery}%`
        )
        .limit(limit);

      return users || [];
    } catch (error) {
      logger.error(`Text search error: ${error.message}`);
      return [];
    }
  }

  /**
   * Batch update embeddings for all users
   */
  async updateAllEmbeddings() {
    try {
      const { data: users } = await supabase
        .from('users')
        .select('id')
        .eq('onboarding_completed', true)
        .eq('is_active', true);

      logger.info(`Updating embeddings for ${users.length} users...`);

      for (const user of users) {
        try {
          await this.generateProfileEmbedding(user.id);
          await new Promise((resolve) => setTimeout(resolve, 100)); // Rate limiting
        } catch (error) {
          logger.error(`Failed to update embedding for user ${user.id}`);
        }
      }

      logger.info('Embedding update complete');
    } catch (error) {
      logger.error(`Batch embedding update error: ${error.message}`);
    }
  }
}

export default new EmbeddingService();
