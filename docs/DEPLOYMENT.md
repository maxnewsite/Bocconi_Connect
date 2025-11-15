# 🚀 Deployment Guide

This guide covers deploying the Bocconi GCC Alumni Connect platform to production.

## Prerequisites

- Node.js 18+ installed
- Git installed
- Supabase account
- Anthropic API key
- OpenAI API key
- Stripe account (for payments)
- Domain name (optional)

---

## 1. Database Setup (Supabase)

### Step 1: Create Supabase Project

1. Go to [supabase.com](https://supabase.com)
2. Create new project
3. Note your project URL and keys

### Step 2: Run Migrations

**Option A: Via Supabase Dashboard**
1. Navigate to **SQL Editor** in your Supabase project
2. Run each migration file in order from `database/migrations/`:
   - `001_create_users.sql`
   - `002_create_profile_relations.sql`
   - `003_create_connections_messages.sql`
   - `004_create_events.sql`
   - `005_create_qa_system.sql`
   - `006_create_ai_notifications.sql`
   - `007_create_platform_settings.sql`

**Option B: Via Supabase CLI**
```bash
npm install -g supabase
supabase login
supabase link --project-ref YOUR_PROJECT_REF
supabase db push
```

### Step 3: Create Storage Buckets

In Supabase Dashboard → Storage, create these buckets:

1. **profile-photos** (Public)
2. **event-banners** (Public)
3. **message-attachments** (Private)
4. **event-photos** (Public)

Apply RLS policies for each bucket.

---

## 2. Backend Deployment

### Option 1: Railway

1. Create account at [railway.app](https://railway.app)
2. Click "New Project" → "Deploy from GitHub"
3. Select your repository
4. Configure:
   - **Root Directory**: `backend`
   - **Build Command**: `npm install`
   - **Start Command**: `npm start`

5. Add environment variables:
```env
NODE_ENV=production
PORT=3001
FRONTEND_URL=https://your-frontend-url.com

SUPABASE_URL=your-supabase-url
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_KEY=your-service-key

ANTHROPIC_API_KEY=your-anthropic-key
OPENAI_API_KEY=your-openai-key

STRIPE_SECRET_KEY=your-stripe-key
STRIPE_WEBHOOK_SECRET=your-stripe-webhook-secret

JWT_SECRET=generate-a-strong-secret-here

SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASS=your-app-password
EMAIL_FROM=noreply@yourdomain.com
```

6. Deploy and note your backend URL

### Option 2: Render

1. Go to [render.com](https://render.com)
2. "New" → "Web Service"
3. Connect your GitHub repo
4. Configure:
   - **Name**: bocconi-backend
   - **Root Directory**: `backend`
   - **Environment**: Node
   - **Build Command**: `npm install`
   - **Start Command**: `npm start`

5. Add environment variables (same as Railway)
6. Deploy

### Option 3: DigitalOcean App Platform

Similar process to Railway/Render.

---

## 3. Frontend Deployment

### Option 1: Vercel (Recommended)

1. Go to [vercel.com](https://vercel.com)
2. Click "New Project"
3. Import your GitHub repository
4. Configure:
   - **Framework Preset**: Vite
   - **Root Directory**: `frontend`
   - **Build Command**: `npm run build`
   - **Output Directory**: `dist`

5. Add environment variables:
```env
VITE_SUPABASE_URL=your-supabase-url
VITE_SUPABASE_ANON_KEY=your-anon-key
VITE_API_URL=https://your-backend-url.com
VITE_SOCKET_URL=https://your-backend-url.com
```

6. Deploy

### Option 2: Netlify

1. Go to [netlify.com](https://netlify.com)
2. "Add new site" → "Import an existing project"
3. Connect to GitHub
4. Configure:
   - **Base directory**: `frontend`
   - **Build command**: `npm run build`
   - **Publish directory**: `frontend/dist`

5. Add environment variables (same as Vercel)
6. Deploy

---

## 4. Domain Configuration

### Backend Domain

1. In your backend hosting (Railway/Render):
   - Go to Settings → Custom Domain
   - Add `api.yourdomain.com`

2. Update DNS records:
```
Type: CNAME
Name: api
Value: your-backend-host.railway.app
```

### Frontend Domain

1. In Vercel/Netlify:
   - Go to Settings → Domains
   - Add `yourdomain.com` and `www.yourdomain.com`

2. Update DNS records:
```
Type: A
Name: @
Value: 76.76.21.21 (Vercel) or 75.2.60.5 (Netlify)

Type: CNAME
Name: www
Value: cname.vercel-dns.com (or yoursite.netlify.app)
```

---

## 5. Stripe Webhook Setup

1. Go to Stripe Dashboard → Developers → Webhooks
2. Add endpoint: `https://api.yourdomain.com/webhooks/stripe`
3. Select events:
   - `payment_intent.succeeded`
   - `payment_intent.payment_failed`
4. Copy webhook signing secret
5. Add to backend env: `STRIPE_WEBHOOK_SECRET`

---

## 6. Email Configuration

### Option 1: Gmail SMTP

1. Enable 2FA on Gmail
2. Generate App Password
3. Use in SMTP settings

### Option 2: SendGrid

1. Create SendGrid account
2. Generate API key
3. Update backend config to use SendGrid

---

## 7. Monitoring & Analytics

### Sentry (Error Tracking)

**Backend:**
```bash
npm install @sentry/node
```

Add to `backend/src/index.js`:
```javascript
import * as Sentry from "@sentry/node";

Sentry.init({
  dsn: process.env.SENTRY_DSN,
  environment: process.env.NODE_ENV,
});
```

**Frontend:**
```bash
npm install @sentry/react
```

Add to `frontend/src/main.jsx`:
```javascript
import * as Sentry from "@sentry/react";

Sentry.init({
  dsn: import.meta.env.VITE_SENTRY_DSN,
  environment: import.meta.env.VITE_ENV,
});
```

### LogRocket (Session Replay)

```bash
npm install logrocket
```

---

## 8. CI/CD with GitHub Actions

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy

on:
  push:
    branches: [main]

jobs:
  backend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Deploy Backend
        run: |
          # Your deployment script

  frontend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Deploy Frontend
        run: |
          # Your deployment script
```

---

## 9. Security Checklist

- [ ] Environment variables secured (never committed)
- [ ] CORS configured for production domain only
- [ ] Rate limiting enabled
- [ ] RLS policies tested
- [ ] HTTPS enforced
- [ ] API keys rotated
- [ ] Webhook signatures verified
- [ ] Input validation on all endpoints
- [ ] SQL injection prevention verified
- [ ] XSS protection enabled

---

## 10. Performance Optimization

### Backend

1. **Enable Compression:**
```javascript
import compression from 'compression';
app.use(compression());
```

2. **Add Caching:**
```javascript
import redis from 'redis';
const client = redis.createClient();
```

### Frontend

1. **Code Splitting:**
Already configured in Vite

2. **Image Optimization:**
Use Cloudinary or similar

3. **CDN:**
Vercel/Netlify provide CDN automatically

---

## 11. Backup Strategy

### Database Backups

Supabase provides automatic daily backups on paid plans.

**Manual Backup:**
```bash
supabase db dump -f backup_$(date +%Y%m%d).sql
```

### File Storage Backups

Use Supabase Storage API to periodically backup files.

---

## 12. Scaling Considerations

### Database
- Monitor query performance in Supabase dashboard
- Add indexes as needed
- Consider upgrading Supabase plan

### Backend
- Enable auto-scaling on Railway/Render
- Use load balancer for multiple instances
- Implement Redis caching

### Frontend
- Already scaled via CDN
- Monitor Core Web Vitals

---

## 13. Post-Deployment

### Test Checklist
- [ ] User signup/login works
- [ ] AI onboarding completes
- [ ] Member search functions
- [ ] Connections can be made
- [ ] Messages send/receive
- [ ] Events can be created
- [ ] RSVP works
- [ ] Q&A posting works
- [ ] Admin panel accessible
- [ ] Notifications trigger
- [ ] Emails send

### Monitoring
- [ ] Setup uptime monitoring (UptimeRobot)
- [ ] Configure error alerts
- [ ] Monitor API usage
- [ ] Track AI costs (Anthropic/OpenAI)

---

## Support

For issues, check:
- Backend logs in Railway/Render dashboard
- Supabase logs in Supabase dashboard
- Frontend errors in browser console
- Sentry error reports

---

**🎉 Your platform is now live!**
