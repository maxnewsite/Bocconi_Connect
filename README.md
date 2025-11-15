# 🎓 Bocconi GCC Alumni Connect

AI-powered alumni network platform for Bocconi graduates in the GCC region, enabling mentorship, networking, job opportunities, and knowledge sharing through conversational AI.

## 🌟 Key Features

- **AI-Powered Onboarding**: B_AI conversational agent for natural profile building
- **Smart Matching**: AI-driven connection suggestions based on interests and expertise
- **Member Directory**: Advanced search with filters and semantic search
- **Direct Messaging**: Real-time 1:1 chat with AI message assistance
- **Event Management**: Create, RSVP, and manage professional/social events
- **Q&A Platform**: Community-driven knowledge sharing with reputation system
- **Engagement Engine**: Proactive AI recommendations and notifications

## 🛠️ Tech Stack

### Frontend
- React 18 with Vite
- TailwindCSS for styling
- Zustand for state management
- React Query for data fetching
- Socket.io-client for real-time features

### Backend
- Node.js with Express
- Supabase (PostgreSQL) for database
- Anthropic Claude API for conversational AI
- OpenAI for embeddings and semantic search
- Stripe for payments
- Socket.io for WebSocket

### Infrastructure
- Supabase Auth for authentication
- Supabase Storage for files
- Supabase Realtime for subscriptions

## 📁 Project Structure

```
bocconi-alumni-connect/
├── frontend/          # React application
├── backend/           # Node.js API server
├── database/          # Supabase migrations & seeds
├── shared/            # Shared TypeScript types
└── docs/              # Documentation
```

## 🚀 Getting Started

### Prerequisites

- Node.js 18+ and npm
- Supabase account and project
- Anthropic API key
- OpenAI API key
- Stripe account (for paid events)

### Environment Setup

1. **Clone the repository**
```bash
git clone <repository-url>
cd Bocconi_Connect
```

2. **Install dependencies**
```bash
# Install backend dependencies
cd backend
npm install

# Install frontend dependencies
cd ../frontend
npm install
```

3. **Configure environment variables**

Create `.env` files in both `backend/` and `frontend/` directories (see `.env.example` files).

4. **Setup Supabase database**
```bash
cd database
# Run migrations (see database/README.md)
```

5. **Run the application**

```bash
# Terminal 1 - Backend
cd backend
npm run dev

# Terminal 2 - Frontend
cd frontend
npm run dev
```

## 📚 Documentation

- [API Documentation](./docs/API.md)
- [Database Schema](./docs/DATABASE.md)
- [Deployment Guide](./docs/DEPLOYMENT.md)
- [AI Integration Guide](./docs/AI_INTEGRATION.md)

## 🔐 Security

- Row Level Security (RLS) enabled on all Supabase tables
- API rate limiting
- Input validation and sanitization
- Secure file upload handling
- OWASP security best practices

## 📄 License

MIT License - see LICENSE file for details

## 🤝 Contributing

Contributions are welcome! Please read our contributing guidelines before submitting PRs.

## 📧 Support

For issues and questions, please create an issue in this repository.

---

Built with ❤️ for the Bocconi GCC Alumni Community
