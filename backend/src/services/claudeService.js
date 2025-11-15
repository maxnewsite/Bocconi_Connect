import Anthropic from '@anthropic-ai/sdk';
import { config } from '../config/env.js';
import { logger } from '../config/logger.js';
import { supabase } from '../config/supabase.js';

const client = new Anthropic({
  apiKey: config.anthropic.apiKey,
});

const MODEL = 'claude-sonnet-4-20250514';

class ClaudeService {
  /**
   * Onboarding conversation handler
   */
  async handleOnboardingChat(userId, userMessage, conversationHistory = []) {
    try {
      const systemPrompt = `You are B_AI, the friendly AI assistant for Bocconi GCC Alumni Connect platform.
Your role is to help alumni create their profile through natural conversation.

CONVERSATION FLOW:
1. Welcome + verify alumni status (graduation year, program)
2. Current location and role
3. Career journey (how they got to GCC)
4. Professional passions and expertise
5. Personal interests beyond work
6. What can you offer? (mentorship/jobs/advice/investment/connections)
7. What are you seeking? (same categories)
8. Profile summary + review

GUIDELINES:
- Be warm, conversational, and genuinely curious
- Ask ONE question at a time
- Remember previous answers and reference them
- Use follow-up questions to dig deeper
- Keep responses concise (2-3 sentences max)
- When you have enough info for a section, smoothly transition to the next topic
- At the end, provide a complete profile summary for review

CURRENT CONVERSATION STAGE: ${this.determineStage(conversationHistory)}

Extract information naturally and remember it for the final profile.`;

      const messages = [
        ...conversationHistory.map((msg) => ({
          role: msg.role,
          content: msg.content,
        })),
        {
          role: 'user',
          content: userMessage,
        },
      ];

      const response = await client.messages.create({
        model: MODEL,
        max_tokens: 1024,
        system: systemPrompt,
        messages: messages,
      });

      const assistantMessage = response.content[0].text;

      // Log AI interaction
      await this.logInteraction(userId, 'onboarding', userMessage, assistantMessage, response.usage);

      return {
        message: assistantMessage,
        conversationHistory: [
          ...conversationHistory,
          { role: 'user', content: userMessage },
          { role: 'assistant', content: assistantMessage },
        ],
      };
    } catch (error) {
      logger.error(`Claude API error: ${error.message}`);
      throw new Error('AI service unavailable');
    }
  }

  /**
   * Extract structured profile data from conversation
   */
  async extractProfileData(conversationHistory) {
    try {
      const conversationText = conversationHistory
        .map((msg) => `${msg.role}: ${msg.content}`)
        .join('\n\n');

      const extractionPrompt = `Analyze this onboarding conversation and extract structured profile data.

CONVERSATION:
${conversationText}

Extract the following fields in JSON format:
{
  "full_name": "string (if mentioned)",
  "graduation_year": "number",
  "program": "string (MBA, Master in Finance, etc.)",
  "current_role": "string",
  "current_company": "string",
  "current_industry": "string",
  "location_city": "string",
  "location_country": "string",
  "bio": "string (2-3 sentence summary)",
  "expertise_tags": ["array", "of", "skills"],
  "passions": ["personal", "interests"],
  "offering": {
    "mentorship": "boolean",
    "job_opportunities": "boolean",
    "investment": "boolean",
    "advice": "boolean",
    "connections": "boolean",
    "description": "string describing what they offer"
  },
  "seeking": {
    "mentorship": "boolean",
    "job_opportunities": "boolean",
    "investment": "boolean",
    "partnerships": "boolean",
    "learning": "boolean",
    "description": "string describing what they seek"
  }
}

Return ONLY the JSON object, no additional text.`;

      const response = await client.messages.create({
        model: MODEL,
        max_tokens: 2048,
        messages: [
          {
            role: 'user',
            content: extractionPrompt,
          },
        ],
      });

      const jsonText = response.content[0].text;
      const profileData = JSON.parse(jsonText);

      return profileData;
    } catch (error) {
      logger.error(`Profile extraction error: ${error.message}`);
      throw new Error('Failed to extract profile data');
    }
  }

  /**
   * Generate AI-powered match reasons
   */
  async generateMatchReasons(user1Profile, user2Profile) {
    try {
      const prompt = `Compare these two Bocconi alumni profiles and identify why they would be a good match for networking.

PROFILE 1:
- Name: ${user1Profile.full_name}
- Role: ${user1Profile.current_role} at ${user1Profile.current_company}
- Industry: ${user1Profile.current_industry}
- Expertise: ${user1Profile.expertise_tags?.join(', ')}
- Interests: ${JSON.stringify(user1Profile.passions)}
- Offering: ${JSON.stringify(user1Profile.offering_description)}
- Seeking: ${JSON.stringify(user1Profile.seeking_description)}

PROFILE 2:
- Name: ${user2Profile.full_name}
- Role: ${user2Profile.current_role} at ${user2Profile.current_company}
- Industry: ${user2Profile.current_industry}
- Expertise: ${user2Profile.expertise_tags?.join(', ')}
- Interests: ${JSON.stringify(user2Profile.passions)}
- Offering: ${JSON.stringify(user2Profile.offering_description)}
- Seeking: ${JSON.stringify(user2Profile.seeking_description)}

Provide 2-3 specific reasons why they should connect. Format as JSON array:
["reason 1", "reason 2", "reason 3"]

Return ONLY the JSON array.`;

      const response = await client.messages.create({
        model: MODEL,
        max_tokens: 512,
        messages: [{ role: 'user', content: prompt }],
      });

      const reasons = JSON.parse(response.content[0].text);
      return reasons;
    } catch (error) {
      logger.error(`Match generation error: ${error.message}`);
      return ['Shared Bocconi background', 'Similar professional interests'];
    }
  }

  /**
   * Draft personalized connection message
   */
  async draftConnectionMessage(senderProfile, recipientProfile) {
    try {
      const prompt = `Draft a warm, professional connection request message.

FROM: ${senderProfile.full_name} - ${senderProfile.current_role} at ${senderProfile.current_company}
TO: ${recipientProfile.full_name} - ${recipientProfile.current_role} at ${recipientProfile.current_company}

Context:
- Both are Bocconi alumni
- Sender's interests: ${senderProfile.expertise_tags?.slice(0, 3).join(', ')}
- Recipient's interests: ${recipientProfile.expertise_tags?.slice(0, 3).join(', ')}

Write a concise, friendly message (50-80 words) that:
1. Mentions the Bocconi connection
2. Highlights a specific common interest
3. Suggests a clear reason to connect

Return ONLY the message text, no quotes.`;

      const response = await client.messages.create({
        model: MODEL,
        max_tokens: 256,
        messages: [{ role: 'user', content: prompt }],
      });

      return response.content[0].text.trim();
    } catch (error) {
      logger.error(`Message drafting error: ${error.message}`);
      return `Hi ${recipientProfile.full_name}, I came across your profile on Bocconi Alumni Connect and would love to connect. I see we share an interest in ${recipientProfile.expertise_tags?.[0] || 'professional development'}. Looking forward to connecting!`;
    }
  }

  /**
   * Enhance user message (for messaging feature)
   */
  async enhanceMessage(originalMessage, context = '') {
    try {
      const prompt = `Improve this message to be more professional and engaging while maintaining the sender's intent:

Original: "${originalMessage}"
${context ? `Context: ${context}` : ''}

Provide an enhanced version that is:
- Professional but warm
- Clear and concise
- Grammatically perfect

Return ONLY the enhanced message, no quotes or explanations.`;

      const response = await client.messages.create({
        model: MODEL,
        max_tokens: 256,
        messages: [{ role: 'user', content: prompt }],
      });

      return response.content[0].text.trim();
    } catch (error) {
      logger.error(`Message enhancement error: ${error.message}`);
      return originalMessage;
    }
  }

  /**
   * Generate Q&A tag suggestions
   */
  async suggestTags(questionTitle, questionDescription) {
    try {
      const prompt = `Given this question, suggest 3-5 relevant tags.

Title: ${questionTitle}
Description: ${questionDescription}

Return tags as JSON array: ["tag1", "tag2", "tag3"]
Tags should be lowercase, single words or hyphenated phrases.`;

      const response = await client.messages.create({
        model: MODEL,
        max_tokens: 128,
        messages: [{ role: 'user', content: prompt }],
      });

      const tags = JSON.parse(response.content[0].text);
      return tags;
    } catch (error) {
      logger.error(`Tag suggestion error: ${error.message}`);
      return [];
    }
  }

  /**
   * Quick ask - general B_AI queries
   */
  async quickAsk(question, userContext = {}) {
    try {
      const systemPrompt = `You are B_AI, the helpful assistant for Bocconi GCC Alumni Connect platform.
Answer questions about the platform, help users find people, suggest events, or provide general assistance.
Be concise, friendly, and actionable.

User context: ${JSON.stringify(userContext)}`;

      const response = await client.messages.create({
        model: MODEL,
        max_tokens: 512,
        system: systemPrompt,
        messages: [{ role: 'user', content: question }],
      });

      return response.content[0].text;
    } catch (error) {
      logger.error(`Quick ask error: ${error.message}`);
      throw new Error('AI service unavailable');
    }
  }

  /**
   * Determine conversation stage based on history
   */
  determineStage(history) {
    const length = history.length;
    if (length === 0) return 'WELCOME';
    if (length < 4) return 'BASIC_INFO';
    if (length < 8) return 'PROFESSIONAL';
    if (length < 12) return 'INTERESTS';
    if (length < 16) return 'OFFERING_SEEKING';
    return 'SUMMARY';
  }

  /**
   * Log AI interaction for analytics
   */
  async logInteraction(userId, type, prompt, response, usage) {
    try {
      const cost = this.calculateCost(usage);

      await supabase.from('ai_interactions').insert({
        user_id: userId,
        interaction_type: type,
        prompt: prompt,
        response: response,
        model_used: MODEL,
        tokens_used: usage.input_tokens + usage.output_tokens,
        cost_usd: cost,
      });
    } catch (error) {
      logger.error(`Failed to log AI interaction: ${error.message}`);
    }
  }

  /**
   * Calculate approximate cost
   */
  calculateCost(usage) {
    // Claude pricing (as of 2024): $3/MTok input, $15/MTok output
    const inputCost = (usage.input_tokens / 1_000_000) * 3;
    const outputCost = (usage.output_tokens / 1_000_000) * 15;
    return inputCost + outputCost;
  }
}

export default new ClaudeService();
