"""NTRS (NASA Technical Reports Server) search + fetch helpers.

The API exposes:
  - search:  GET /api/citations/search?q=<query>&page.size=<n>
  - citation: GET /api/citations/<id>
  - fulltext: GET /api/citations/<id>/downloads/<id>.txt   (plain text, when available)
  - pdf:      GET /api/citations/<id>/downloads/<id>.pdf

Usage:
  python ntrs.py search "smoke and aerosol measurement experiment"
  python ntrs.py fetch 20090014827 68
"""
import json
import os
import re
import sys
import urllib.parse
import urllib.request

BASE = 'https://ntrs.nasa.gov'


def _get(url, timeout=120):
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    return urllib.request.urlopen(req, timeout=timeout).read()


def search(query, n=6):
    url = BASE + '/api/citations/search?' + urllib.parse.urlencode(
        {'q': query, 'page.size': n})
    data = json.loads(_get(url))
    results = data.get('results', [])
    print(f'"{query}" -> {data.get("stats", {}).get("total", len(results))} hits')
    for r in results:
        rid = r.get('id')
        title = r.get('title', '')
        year = str(rid)[:4] if rid else '?'
        sti = r.get('stiType', '?')
        dls = r.get('downloads', []) or []
        kinds = []
        for d in dls:
            link = d.get('links', {})
            if 'fulltext' in link:
                kinds.append('txt')
            if 'pdf' in link:
                kinds.append('pdf')
        abs_ = (r.get('abstract') or '').replace('\n', ' ')[:160]
        print(f'  {rid} | {year} | {sti} | {",".join(kinds) or "meta-only"} | {title}')
        if abs_:
            print(f'      {abs_}')
    print()


def _citation(rid):
    return json.loads(_get(f'{BASE}/api/citations/{rid}'))


def _download(url, dest):
    open(dest, 'wb').write(_get(url))


def fetch(rid, nn):
    c = _citation(rid)
    title = c.get('title', f'Untitled {rid}')
    year = str(rid)[:4]
    # sanitize title for a filename
    safe = re.sub(r'[\\/:*?"<>|\n\r\t]+', '', title)
    safe = re.sub(r'\s+', ' ', safe).strip()
    base = f'{nn} {safe} {year} {rid}'

    downloads = c.get('downloads', []) or []
    txt_link = pdf_link = None
    for d in downloads:
        links = d.get('links', {})
        if 'fulltext' in links:
            txt_link = BASE + links['fulltext']
        if 'pdf' in links:
            pdf_link = BASE + links['pdf']

    root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
    corpus_dir = os.path.join(root, 'corpus')
    lit_dir = os.path.join(root, 'literature')
    os.makedirs(corpus_dir, exist_ok=True)
    os.makedirs(lit_dir, exist_ok=True)

    corpus_path = os.path.join(corpus_dir, base + '.txt')
    print(f'[{nn}] {year} — {title}')
    print(f'    fulltext txt: {bool(txt_link)}   pdf: {bool(pdf_link)}')

    if pdf_link:
        pdf_path = os.path.join(lit_dir, base + '.pdf')
        _download(pdf_link, pdf_path)
        print(f'    -> {pdf_path}')
        try:
            import pymupdf
            doc = pymupdf.open(pdf_path)
            parts = []
            for i, page in enumerate(doc):
                parts.append(f'<<<PAGE {i + 1}>>>\n{page.get_text()}')
            open(corpus_path, 'w', encoding='utf-8').write('\n'.join(parts))
            words = sum(len(p.split()) for p in parts)
            print(f'    -> {corpus_path} ({len(doc)} pages, ~{words} words)')
        except Exception as e:
            print(f'    ! pdf text extraction failed: {e}')
            if txt_link:
                raw = _get(txt_link).decode('utf-8', errors='replace')
                open(corpus_path, 'w', encoding='utf-8').write(
                    f'<<<PAGE 1>>>\n{raw}')
                print(f'    -> fell back to fulltext txt ({len(raw.split())} words)')
    elif txt_link:
        raw = _get(txt_link).decode('utf-8', errors='replace')
        body = f'<<<PAGE 1>>>\n{raw}'
        open(corpus_path, 'w', encoding='utf-8').write(body)
        print(f'    -> {corpus_path} ({len(raw.split())} words)')
    else:
        print('    ! no fulltext or pdf available (metadata only)')


if __name__ == '__main__':
    if len(sys.argv) < 3:
        print(__doc__)
    elif sys.argv[1] == 'search':
        search(' '.join(sys.argv[2:]))
    elif sys.argv[1] == 'fetch':
        fetch(sys.argv[2], sys.argv[3])
    else:
        print(__doc__)
