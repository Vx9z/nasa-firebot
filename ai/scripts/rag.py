"""NASA fire-safety RAG — ingest + ask.

Usage:
    python rag.py ingest        # chunk + embed + save vectors + build image manifest
    python rag.py ask "..."     # answer a question, with citations + relevant figures
"""
import os
import sys
import json

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import numpy as np

import config
import chunk
import embed
import manifest

VEC_PATH = os.path.join(config.VECTORS_DIR, 'embeddings.npy')
CHUNKS_PATH = os.path.join(config.VECTORS_DIR, 'chunks.json')

# In-memory index cache: load vectors + chunks once and reuse on every query.
# (A long-lived server keeps this ~50 MB in RAM instead of re-reading it per ask.)
_index_cache = {'loaded': False, 'mat': None, 'chunks': None}


def _load_index():
    if _index_cache['loaded']:
        return _index_cache['mat'], _index_cache['chunks']
    _index_cache['loaded'] = True
    if os.path.exists(VEC_PATH) and os.path.exists(CHUNKS_PATH):
        try:
            _index_cache['mat'] = np.load(VEC_PATH)
            _index_cache['chunks'] = json.load(open(CHUNKS_PATH, encoding='utf-8'))
        except Exception:
            _index_cache['mat'] = None
            _index_cache['chunks'] = None
    return _index_cache['mat'], _index_cache['chunks']


def ingest():
    print('Chunking corpus...')
    chunks = chunk.load_chunks()
    print(f'  {len(chunks)} chunks')
    if not chunks:
        print('  no chunks found'); return

    os.makedirs(config.VECTORS_DIR, exist_ok=True)
    texts = [c['text'] for c in chunks]
    total = len(texts)

    # Checkpoint: resume a partially-completed ingest instead of restarting.
    partial_path = os.path.join(config.VECTORS_DIR, 'embeddings.partial.npy')
    done = []
    if os.path.exists(partial_path):
        try:
            done = np.load(partial_path).tolist()
            print(f'  resuming: {len(done)}/{total} chunks already embedded')
        except Exception:
            done = []

    remaining = texts[len(done):]

    def checkpoint(embs):
        # embs = cumulative embeddings produced so far in THIS run.
        np.save(partial_path, np.asarray(done + embs, dtype='float32'))

    print(f'  embedding {len(remaining)} chunks with Gemini (rate-limited)...')
    new_embs = embed.embed(remaining, on_batch=checkpoint)
    all_embs = done + new_embs

    mat = np.asarray(all_embs, dtype='float32')
    np.save(VEC_PATH, mat)
    json.dump(chunks, open(CHUNKS_PATH, 'w', encoding='utf-8'))
    if os.path.exists(partial_path):
        os.remove(partial_path)
    print(f'  saved {mat.shape} embeddings -> {VEC_PATH}')

    mf = manifest.build_manifest()
    print(f'  image manifest: {len(mf)} figures -> {config.IMAGES_DIR}/manifest.json')


def _cosine(a, b):
    return float(np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b) + 1e-9))


def query(question, verbosity='long'):
    """Run the full RAG query and return a structured dict for CLI or web.

    Falls back to a direct (non-grounded) Gemini answer when the vector index is
    missing or was built with a different embedder (dimension mismatch).
    """
    lengths = {
        'short': 'Answer in a short paragraph of three to five sentences.',
        'medium': 'Answer in a few detailed paragraphs.',
        'long': (
            'Answer as thoroughly and completely as possible. There is no length '
            'limit: include every relevant detail, explanation, and nuance.'
        ),
    }
    style = lengths.get(verbosity, lengths['long'])

    # Load the (cached) index only if present AND compatible with the embedder.
    mat, chunks = _load_index()
    q = None
    if mat is not None and chunks is not None:
        try:
            q = embed.embed([question])[0]
            if mat.shape[1] != len(q):
                mat = chunks = None  # stale (older embedder) — skip retrieval
        except Exception:
            mat = chunks = None

    if mat is None or chunks is None or len(chunks) == 0:
        prompt = (
            'You are a fire-safety research assistant for human space exploration. '
            f'{style} Answer from your knowledge of NASA microgravity combustion '
            'and spacecraft fire safety.\n\n'
            f'QUESTION: {question}\n\nAnswer:'
        )
        ans = embed.chat([{'role': 'user', 'content': prompt}])
        return {'question': question, 'answer': ans, 'sources': [], 'figures': []}

    mf = manifest.load_manifest()
    sims = [_cosine(q, mat[i]) for i in range(len(chunks))]
    top = sorted(range(len(chunks)), key=lambda i: -sims[i])[:config.TOP_K]

    context_blocks = []
    img_candidates = {}
    for idx in top:
        c = chunks[idx]
        context_blocks.append(f"[{c['nn']} {c['paper']} p{c['page']}]\n{c['text']}")
        for im in mf:
            if im['nn'] == c['nn'] and abs(int(im['page']) - int(c['page'])) <= config.PAGE_WINDOW:
                img_candidates[im['file']] = im

    context = '\n\n---\n\n'.join(context_blocks)
    top_images = {'short': 0, 'medium': 1, 'long': config.TOP_K_IMAGES}.get(
        verbosity, config.TOP_K_IMAGES)
    prompt = (
        "You are a fire-safety research assistant for human space exploration. "
        f"{style} Answer using ONLY the context below. Cite sources with their "
        "[NN paper] tag. If the context doesn't contain the answer, say so.\n\n"
        f"CONTEXT:\n{context}\n\n"
        f"QUESTION: {question}\n\n"
        "Answer:"
    )
    ans = embed.chat([{'role': 'user', 'content': prompt}])

    qwords = set(question.lower().split())

    def _score(im):
        return len(qwords & set(im['label'].lower().split()))

    figures = sorted(img_candidates.values(), key=_score, reverse=True)[:top_images]

    return {
        'question': question,
        'answer': ans,
        'sources': [
            {'nn': chunks[i]['nn'], 'paper': chunks[i]['paper'],
             'page': chunks[i]['page'], 'score': round(sims[i], 3)}
            for i in top
        ],
        'figures': [
            {'file': im['file'], 'nn': im['nn'], 'page': im['page'], 'label': im['label']}
            for im in figures
        ],
    }


def ask(question):
    """CLI: print the structured result."""
    r = query(question)
    if 'error' in r:
        print(r['error']); return
    print('\n' + '=' * 60 + '\nANSWER\n' + '=' * 60)
    print(r['answer'])
    print('\n' + '=' * 60 + '\nSOURCES\n' + '=' * 60)
    for s in r['sources']:
        print(f"  [{s['nn']}] {s['paper']}  (p{s['page']}, score {s['score']})")
    if r['figures']:
        print('\n' + '=' * 60 + '\nRELEVANT FIGURES\n' + '=' * 60)
        for im in r['figures']:
            print(f"  {im['file']}  (paper {im['nn']}, page {im['page']})")


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print('usage: python rag.py ingest | ask "question"')
    elif sys.argv[1] == 'ingest':
        ingest()
    elif sys.argv[1] == 'ask':
        ask(' '.join(sys.argv[2:]))
    else:
        print('unknown command:', sys.argv[1])
