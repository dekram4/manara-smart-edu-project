# Manara — Smart Education Platform

A feature-rich education platform (منارة) built with React + Vite. Includes AI-powered tutoring (Google Gemini), role-based dashboards for students, teachers, parents, and admins, quizzes, games, and optional Supabase cloud sync.

## Stack

- **Frontend**: React 19, TypeScript, Vite, Tailwind CSS
- **AI**: Google Gemini (`@google/genai`)
- **Backend/DB**: Supabase (optional — falls back to localStorage)
- **Mobile**: Capacitor (Android/iOS builds)
- **Extras**: Three.js, PixiJS, Phaser, Framer Motion, Lottie

## Running the app

```bash
cd smart-edu-project
npm run dev        # starts Vite dev server on port 5000
```

The configured workflow `Start application` runs this automatically.

## Environment variables

| Variable | Required | Description |
|---|---|---|
| `VITE_GEMINI_API_KEY` | Yes (for AI features) | Google Gemini API key — get one free at https://aistudio.google.com/apikey |
| `VITE_SUPABASE_URL` | No | Supabase project URL (app works offline without it) |
| `VITE_SUPABASE_ANON_KEY` | No | Supabase anon key |

## Notes

- Installed with `--legacy-peer-deps` due to `@dotlottie/react-player` requiring React ≤18 while the project uses React 19
- Default admin login: username `dekram`, password `123`
- Data persists in localStorage when Supabase is not configured

## User preferences
