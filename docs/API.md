# 📡 API Documentation

Base URL: `https://api.yourdomain.com/api`

All endpoints require authentication unless stated otherwise.

**Authentication:** Bearer token in Authorization header
```
Authorization: Bearer <access_token>
```

---

## 🔐 Authentication

### POST /auth/signup
Register new user

**Body:**
```json
{
  "email": "user@example.com",
  "password": "password123",
  "full_name": "John Doe",
  "graduation_year": 2020,
  "program": "MBA"
}
```

**Response:** `201 Created`
```json
{
  "success": true,
  "data": {
    "user": { ... },
    "session": { ... }
  }
}
```

### POST /auth/login
Login with credentials

**Body:**
```json
{
  "email": "user@example.com",
  "password": "password123"
}
```

### GET /auth/me
Get current user profile (requires auth)

---

## 🎓 Onboarding

### POST /onboarding/start
Start AI onboarding conversation

**Response:**
```json
{
  "success": true,
  "data": {
    "message": "Welcome message from B_AI...",
    "conversationHistory": [...]
  }
}
```

### POST /onboarding/chat
Continue onboarding conversation

**Body:**
```json
{
  "message": "I graduated from MBA program in 2020"
}
```

### POST /onboarding/save-profile
Complete onboarding and save profile

**Body:**
```json
{
  "current_role": "Senior Consultant",
  "current_company": "McKinsey",
  "bio": "...",
  "expertise_tags": ["strategy", "finance"],
  "offerings": [...],
  "seeking": [...]
}
```

---

## 👥 Members

### GET /members
List all members

**Query Parameters:**
- `search` - Text search
- `location_city` - Filter by city
- `location_country` - Filter by country
- `industry` - Filter by industry
- `graduation_year` - Filter by year
- `page` - Page number (default: 1)
- `limit` - Results per page (default: 20)

**Response:**
```json
{
  "success": true,
  "data": {
    "members": [...],
    "pagination": {
      "page": 1,
      "limit": 20,
      "total": 150,
      "pages": 8
    }
  }
}
```

### GET /members/search/semantic
AI-powered semantic search

**Query Parameters:**
- `q` - Search query
- `limit` - Max results (default: 20)

### GET /members/suggestions
Get AI-matched connection suggestions

**Query Parameters:**
- `limit` - Number of suggestions (default: 10)

---

## 🤝 Connections

### POST /connections/request
Send connection request

**Body:**
```json
{
  "recipient_id": "uuid",
  "introduction_message": "Hi, I'd love to connect..."
}
```

### POST /connections/:id/accept
Accept connection request

### POST /connections/:id/decline
Decline connection request

### GET /connections/pending
Get pending connection requests

### GET /connections
Get all accepted connections

### POST /connections/draft-message
AI-draft connection message

**Body:**
```json
{
  "recipient_id": "uuid"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "message": "AI-generated introduction message..."
  }
}
```

---

## 💬 Messages

### GET /messages/conversations
Get list of conversations

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "user": { ... },
      "lastMessage": { ... },
      "unreadCount": 3
    }
  ]
}
```

### GET /messages/:userId
Get messages with specific user

**Query Parameters:**
- `limit` - Max messages (default: 50)
- `before` - ISO date for pagination

### POST /messages/send
Send message

**Body:**
```json
{
  "recipient_id": "uuid",
  "content": "Message text",
  "attachment_url": "optional-url"
}
```

### POST /messages/enhance
AI-enhance message

**Body:**
```json
{
  "message": "Original message text",
  "context": "Optional context"
}
```

---

## 📅 Events

### GET /events
List all events

**Query Parameters:**
- `type` - professional|social|educational|investment
- `upcoming` - true|false
- `page` - Page number
- `limit` - Results per page

### GET /events/:id
Get event details

### POST /events
Create event

**Body:**
```json
{
  "title": "Event title",
  "description": "Event description",
  "event_type": "professional",
  "start_date": "2024-12-01T19:00:00Z",
  "location_name": "Dubai Marina",
  "capacity": 50,
  "is_paid": false
}
```

### POST /events/:id/rsvp
RSVP to event

### GET /events/my/attending
Get user's events

---

## ❓ Q&A

### GET /qa/questions
List questions

**Query Parameters:**
- `category` - Filter by category
- `filter` - recent|unanswered|trending
- `page` - Page number
- `limit` - Results per page

### GET /qa/questions/:id
Get question details with answers

### POST /qa/questions
Ask question

**Body:**
```json
{
  "title": "Question title",
  "description": "Detailed description",
  "category": "Career",
  "tags": ["optional", "tags"],
  "is_anonymous": false
}
```

### POST /qa/questions/:id/answers
Answer question

**Body:**
```json
{
  "content": "Answer text"
}
```

### POST /qa/answers/:id/accept
Accept answer (question asker only)

### POST /qa/vote
Vote on question or answer

**Body:**
```json
{
  "votable_type": "question",
  "votable_id": "uuid",
  "vote_type": "upvote"
}
```

### GET /qa/leaderboard
Get reputation leaderboard

---

## 🔔 Notifications

### GET /notifications
Get user notifications

**Query Parameters:**
- `limit` - Max notifications (default: 50)
- `unread_only` - true|false

### PUT /notifications/:id/read
Mark notification as read

### PUT /notifications/read-all
Mark all as read

### GET /notifications/unread/count
Get unread count

---

## 🤖 AI Assistant

### POST /ai/quick-ask
Ask B_AI a question

**Body:**
```json
{
  "question": "How do I find mentors in renewable energy?"
}
```

### POST /ai/suggest-tags
Get AI tag suggestions

**Body:**
```json
{
  "title": "Question title",
  "description": "Question description"
}
```

---

## 🔧 Admin (Admin Only)

### GET /admin/users
List all users

### PUT /admin/users/:id/suspend
Suspend user

### PUT /admin/users/:id/activate
Activate user

### GET /admin/analytics
Get platform statistics

**Response:**
```json
{
  "success": true,
  "data": {
    "totalUsers": 500,
    "activeUsers": 450,
    "totalConnections": 1200,
    "totalEvents": 45,
    "totalQuestions": 230,
    "totalMessages": 5600
  }
}
```

---

## Error Responses

All errors follow this format:

```json
{
  "success": false,
  "error": {
    "message": "Error description"
  }
}
```

**Common Status Codes:**
- `400` - Bad Request
- `401` - Unauthorized
- `403` - Forbidden
- `404` - Not Found
- `429` - Too Many Requests
- `500` - Internal Server Error

---

## Rate Limiting

- General API: 100 requests per 15 minutes
- Auth endpoints: 5 requests per 15 minutes
- AI endpoints: 10 requests per minute
- Upload endpoints: 5 uploads per minute

Rate limit info in headers:
```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1640000000
```

---

## WebSocket Events

Connect to: `wss://api.yourdomain.com`

**Client → Server:**
```json
{
  "type": "authenticate",
  "token": "access_token"
}
```

**Server → Client:**
```json
{
  "type": "new_message",
  "data": { ... }
}

{
  "type": "notification",
  "data": { ... }
}
```

---

**Need help? Contact support@bocconialumni.com**
