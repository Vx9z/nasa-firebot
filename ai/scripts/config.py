"""Central configuration for the NASA fire-safety RAG (Gemini-backed).

The Gemini API key is loaded from the project root `.env` (gitignored) or the
GEMINI_API_KEY environment variable. Change model names here; everything else
reads from this file.
"""
import os

# Project root (two levels up from ai/scripts/)
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))

CORPUS_DIR = os.path.join(ROOT, 'corpus')
IMAGES_DIR = os.path.join(ROOT, 'ai', 'images')
VECTORS_DIR = os.path.join(ROOT, 'ai', 'vectors')
ASSETS_DIR = os.path.join(ROOT, 'app', 'assets')

GEMINI_URL = 'https://generativelanguage.googleapis.com/v1beta'
GEMINI_EMBED_MODEL = 'gemini-embedding-001'
GEMINI_CHAT_MODEL = 'gemini-3.5-flash-lite'


def _load_env():
    """Load a simple KEY=VALUE `.env` from the project root (if present)."""
    path = os.path.join(ROOT, '.env')
    if not os.path.exists(path):
        return
    for line in open(path, encoding='utf-8'):
        line = line.strip()
        if not line or line.startswith('#') or '=' not in line:
            continue
        k, v = line.split('=', 1)
        os.environ[k.strip()] = v.strip().strip('"').strip("'")


_load_env()

GEMINI_API_KEY = os.environ.get('GEMINI_API_KEY', '')

# Chunking
CHUNK_WORDS = 400      # ~500 tokens
OVERLAP_WORDS = 50

# Retrieval
TOP_K = 6              # text chunks to retrieve
TOP_K_IMAGES = 2       # figures to surface
PAGE_WINDOW = 1        # proximity: pages within +/- this of a cited chunk

# Papers to skip during ingest (scanned workshop volumes = noisy OCR + huge).
# Remove from this set to index the full corpus later.
SKIP_NN = {'08', '09', '10', '11', '12', '13'}

