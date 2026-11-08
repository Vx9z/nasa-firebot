# FireBot backend image (Flask + Gemini RAG).
# The vector index and figures are baked in so the server never re-ingests on boot.
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# ai/ holds scripts/, web/, vectors/ (the index) and images/ (figures).
COPY ai ./ai

ENV PORT=8000
EXPOSE 8000

# Single worker keeps one ~50 MB index copy in RAM; threads allow concurrent
# Gemini calls. Generous timeout for long/verbose answers.
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "1", "--threads", "4", "--timeout", "180", "--chdir", "ai/web", "app:app"]
