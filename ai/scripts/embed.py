"""Thin Gemini client (embeddings + chat).

- embed: Gemini Embeddings via batchEmbedContents (rate-limited for free tier)
- chat:  Gemini generateContent (gemini-3.8-flash)
"""
import json
import random
import re
import time
import urllib.error
import urllib.request

from config import (
    GEMINI_API_KEY,
    GEMINI_CHAT_MODEL,
    GEMINI_EMBED_MODEL,
    GEMINI_URL,
)

MAX_BATCH = 100  # Gemini batchEmbedContents hard limit (requests per call)


def _retry_delay(body):
    """Parse Gemini's 'retry in Xs' hint; return None if absent."""
    m = re.search(r'retry in ([\d.]+)\s*s', body, re.IGNORECASE)
    return float(m.group(1)) + 1.0 if m else None


def _post(path, payload, timeout=600, retries=8):
    for attempt in range(retries):
        req = urllib.request.Request(
            GEMINI_URL + path + '?key=' + GEMINI_API_KEY,
            data=json.dumps(payload).encode('utf-8'),
            headers={'Content-Type': 'application/json'},
        )
        try:
            return json.loads(urllib.request.urlopen(req, timeout=timeout).read())
        except urllib.error.HTTPError as e:
            body = e.read().decode('utf-8', errors='replace')
            if e.code in (429, 500, 503) and attempt < retries - 1:
                wait = _retry_delay(body)
                if wait is None:
                    wait = (2 ** attempt) + random.random()
                print(f'    (HTTP {e.code}, retry {attempt + 1}/{retries - 1} in {wait:.0f}s)')
                time.sleep(wait)
                continue
            raise RuntimeError(
                f'Gemini HTTP {e.code} on {path}: {body[:600]}') from e


def _est_tokens(text):
    # Conservative: technical text tokenizes ~1.5-2.0 tokens per word.
    return max(1, int(len(text.split()) * 1.8))


def embed(texts, token_budget=12000, sleep_s=65.0, on_batch=None):
    """Embed texts, batching under the Gemini free-tier token/minute quota.

    Gemini free tier allows ~30k embedding tokens per minute. We accumulate
    texts into token-budgeted groups, flush a group, then sleep so the minute
    window resets before the next group.
    """
    out = []
    group = []
    group_tokens = 0

    def flush():
        nonlocal group_tokens
        if not group:
            return
        payload = {
            'requests': [
                {'model': 'models/' + GEMINI_EMBED_MODEL,
                 'content': {'parts': [{'text': t}]}}
                for t in group
            ]
        }
        r = _post(f'/models/{GEMINI_EMBED_MODEL}:batchEmbedContents', payload)
        for e in r.get('embeddings', []):
            out.append(e.get('values', []))
        print(f'    embedded {len(out)}/{len(texts)}')
        if on_batch:
            on_batch(out)  # out = cumulative embeddings produced so far this run
        group.clear()
        group_tokens = 0

    for t in texts:
        est = _est_tokens(t)
        if (group_tokens + est > token_budget or len(group) >= MAX_BATCH) and group:
            flush()
            print(f'    (rate-limit: sleeping {sleep_s:.0f}s)')
            time.sleep(sleep_s)
        group.append(t)
        group_tokens += est
    flush()
    return out


def chat(messages):
    """Chat completion. messages = [{'role','content'}, ...] -> str."""
    contents = []
    for m in messages:
        role = 'user' if m.get('role') == 'user' else 'model'
        contents.append({'role': role, 'parts': [{'text': m['content']}]})
    payload = {'contents': contents}
    r = _post(f'/models/{GEMINI_CHAT_MODEL}:generateContent', payload)
    try:
        return r['candidates'][0]['content']['parts'][0]['text']
    except (KeyError, IndexError, TypeError):
        raise RuntimeError('Unexpected Gemini response: ' + json.dumps(r)[:600])


def generate_json(prompt):
    """Generate and return a parsed JSON object (Gemini JSON mode)."""
    payload = {
        'contents': [{'role': 'user', 'parts': [{'text': prompt}]}],
        'generationConfig': {'response_mime_type': 'application/json'},
    }
    r = _post(f'/models/{GEMINI_CHAT_MODEL}:generateContent', payload)
    try:
        text = r['candidates'][0]['content']['parts'][0]['text']
    except (KeyError, IndexError, TypeError):
        raise RuntimeError('Unexpected Gemini response: ' + json.dumps(r)[:600])
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        m = re.search(r'\{.*\}', text, re.DOTALL)
        if m:
            return json.loads(m.group(0))
        raise RuntimeError('JSON parse failed: ' + text[:600])

