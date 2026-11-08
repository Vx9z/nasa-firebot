# Deploying NASA FireBot

Two parts: the Flutter **frontend** (Vercel) and the Flask **backend** (Render).

## 0. Before deploying — rebuild the Gemini index

`ai/vectors/embeddings.npy` is currently the old 768-dim index. Re-ingest with
the 3072-dim embedder so citations actually work:

```bash
python ai/scripts/rag.py ingest
```

This overwrites `ai/vectors/embeddings.npy` + `chunks.json` and rebuilds the
image manifest. Commit the results before deploying.

## 1. Backend → Render (free tier)

1. Push this repo to GitHub.
2. Render → New → **Web Service** → connect the repo. It auto-detects
   `render.yaml` (or pick "Docker" and point at the root `Dockerfile`).
3. Add the env var `GEMINI_API_KEY` in the dashboard (never in git).
4. Render free = **512 MB RAM** (enough for numpy + the index) but sleeps after
   ~15 min of no traffic.

**Keep it awake:** create a free [UptimeRobot](https://uptimerobot.com) monitor
hitting `https://<app>.onrender.com/health` every 10 minutes. The ping resets
Render's idle timer so it never sleeps.

**Warm up before presenting:** open the URL (or hit `/ask` once) a minute before
the demo, so the first real question isn't a ~30–90 s cold start.

## 2. Frontend → Vercel

Build with the backend URL baked in:

```bash
cd app
flutter build web --release --dart-define=RAG_URL=https://<app>.onrender.com
```

Deploy the static output:

```bash
vercel deploy app/build/web --prod
```

(Or run `vercel` from `app/` with the output directory set to `build/web`.)

## Notes

- The Gemini key must live **only** as a Render env var — never in the Flutter
  app (client-side JS is readable) and never committed to git.
- CORS is already open (`Access-Control-Allow-Origin: *`) in `ai/web/app.py`.
