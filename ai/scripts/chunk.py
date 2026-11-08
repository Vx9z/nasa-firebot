"""Split the corpus into page-tagged chunks.

Each chunk carries: nn (paper number), paper (title string), page, text.
Page is the shared coordinate used to link chunks -> nearby figures.
"""
import os
import re
from config import CORPUS_DIR, CHUNK_WORDS, OVERLAP_WORDS, SKIP_NN

PAGE_RE = re.compile(r'<<<PAGE (\d+)>>>')


def _split_pages(text):
    """Split a file's text into [(page_num, body), ...]."""
    parts = PAGE_RE.split(text)
    pages = []
    i = 1
    while i < len(parts):
        num = int(parts[i])
        body = parts[i + 1] if i + 1 < len(parts) else ''
        pages.append((num, body))
        i += 2
    if not pages:
        pages = [(1, text)]
    return pages


def load_chunks():
    """Return a list of chunk dicts in reading order."""
    chunks = []
    step = max(CHUNK_WORDS - OVERLAP_WORDS, 1)
    for fname in sorted(os.listdir(CORPUS_DIR)):
        if not fname.endswith('.txt'):
            continue
        nn = fname[:2]
        if nn in SKIP_NN:
            continue
        paper = fname[3:-4]  # strip "NN " prefix and ".txt"
        raw = open(os.path.join(CORPUS_DIR, fname), encoding='utf-8').read()
        for page_num, body in _split_pages(raw):
            words = body.split()
            for i in range(0, len(words), step):
                seg = words[i:i + CHUNK_WORDS]
                if len(seg) < 30:
                    continue
                chunks.append({
                    'nn': nn,
                    'paper': paper,
                    'page': page_num,
                    'text': ' '.join(seg),
                })
    return chunks
