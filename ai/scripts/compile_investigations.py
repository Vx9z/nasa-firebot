"""Compile the investigations dashboard data from the corpus.

Groups the papers into fire-safety "investigations", extracts structured
attributes + a summary/interpretation from each via Gemini, applies a
deterministic relevance rubric, and writes app/assets/investigations.json.

Usage:
    python compile_investigations.py [--force] [--limit N]

Checkpointed: re-running skips investigations already present in the output
file (unless --force). The Flutter app reads the JSON as a bundled asset.
"""
import json
import os
import re
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import config
import embed

OUT = os.path.join(config.ASSETS_DIR, 'investigations.json')

PILLARS = ('prevention', 'detection', 'suppression')

# Curated grouping: paper NN -> investigation (primary focus). NN = the 2-digit
# corpus filename prefix. Every non-skipped corpus paper belongs to exactly one
# investigation below.
INVESTIGATIONS = [
    {"id": "skylab-m479", "name": "Skylab M-479 (Zero-Gravity Flammability)", "papers": ["01"]},
    {"id": "sibal", "name": "SIBAL (Solid Inflammability Boundary at Low Gravity)", "papers": ["15"]},
    {"id": "smoldering", "name": "Smoldering Combustion (USML-1)", "papers": ["16"]},
    {"id": "bass", "name": "BASS / BASS-II (Burning & Suppression of Solids)", "papers": ["31", "32"]},
    {"id": "flame-spread", "name": "Flame Spread & Flammability Limits (PMMA, FLARE, Silicone)", "papers": ["33", "34", "35", "36", "46", "50", "51"]},
    {"id": "spice", "name": "SPICE (Smoke Point In Co-flow Experiment)", "papers": ["75"]},
    {"id": "slice", "name": "SLICE (Structure & Liftoff In Combustion Experiment)", "papers": ["76"]},
    {"id": "bre", "name": "BRE (Burning Rate Emulator, ACME)", "papers": ["74"]},
    {"id": "efield", "name": "E-FIELD Flames (ACME)", "papers": ["77"]},
    {"id": "sofie", "name": "SoFIE (Solid Fuel Ignition & Extinction)", "papers": ["37", "65"]},
    {"id": "flex", "name": "FLEX / FLEX-2 (Flame Extinguishment Experiment)", "papers": ["18", "19", "20", "71"]},
    {"id": "cfi", "name": "CFI / CFI-G (Cool Flames Investigation)", "papers": ["72", "73"]},
    {"id": "same", "name": "SAME / SAME-R / SAME-2 (Smoke & Aerosol Measurement)", "papers": ["29", "68", "69", "70"]},
    {"id": "materials-toxicity", "name": "Materials Flammability & Toxic Products", "papers": ["38", "49", "52", "53", "55", "63"]},
    {"id": "saffire", "name": "Saffire I-VI (Spacecraft Fire Experiment)", "papers": ["39", "40", "41", "42", "43", "44", "47", "48", "57", "60"]},
    {"id": "modeling", "name": "Fire Modeling & Prediction", "papers": ["54", "56", "58", "59"]},
    {"id": "roadmap", "name": "Spacecraft Fire-Safety Roadmap & Needs", "papers": ["28", "30", "45", "61", "62", "64"]},
    {"id": "foundations", "name": "Microgravity Combustion Foundations & Diagnostics", "papers": ["02", "03", "04", "05", "06", "07", "14"]},
    {"id": "droplet-gas", "name": "Droplet & Gas-Phase Flame Physics", "papers": ["17", "21", "22", "25", "26", "66"]},
    {"id": "robotic-ff", "name": "Robotic Firefighting (Emerging)", "papers": ["67"]},
]

def load_paper(nn):
    """Return the cleaned text of corpus paper NN (page markers removed)."""
    for f in sorted(os.listdir(config.CORPUS_DIR)):
        if f.startswith(nn + ' ') and f.endswith('.txt'):
            raw = open(os.path.join(config.CORPUS_DIR, f), encoding='utf-8').read()
            raw = re.sub(r'<<<PAGE \d+>>>', ' ', raw)
            return re.sub(r'\s+', ' ', raw).strip()
    return ''


def load_inv_text(papers, per_paper=6000, total=45000):
    """Concatenate (capped) text of an investigation's papers."""
    parts = []
    budget = total
    for nn in papers:
        t = load_paper(nn)
        if not t:
            continue
        t = t[:per_paper]
        parts.append(f'[paper {nn}]\n{t}')
        budget -= len(t)
        if budget <= 0:
            break
    return '\n\n'.join(parts)


def rubric(inv):
    """Deterministic relevance score (0-100) + human-readable reasons."""
    score = 0
    reasons = []
    ps = set(inv.get('pillars') or []) & set(PILLARS)
    score += len(ps) * 10
    reasons.append('pillars: ' + (', '.join(sorted(ps)) if ps else 'none'))
    crew = inv.get('crew_relevance', 'medium')
    score += {'low': 8, 'medium': 16, 'high': 25}.get(crew, 16)
    reasons.append('crew-env relevance: ' + crew)
    data = inv.get('data_richness', 'medium')
    score += {'low': 8, 'medium': 16, 'high': 25}.get(data, 16)
    reasons.append('data richness: ' + data)
    direct = inv.get('directness', 'direct')
    score += {'direct': 20, 'adjacent': 8}.get(direct, 8)
    reasons.append('directness: ' + direct)
    return min(score, 100), reasons


def prompt_for(inv):
    papers = load_inv_text(inv['papers'])
    return (
        'You are a fire-safety research analyst for human space exploration. '
        'Given papers from investigation "' + inv['name'] + '", extract structured '
        'facts. Respond with ONLY a JSON object (no fences, no commentary) using '
        'exactly these keys:\n'
        '{\n'
        '  "objective": "one sentence: the goal",\n'
        '  "fuels": "fuels/materials studied, with sample shape/size",\n'
        '  "conditions": "test conditions: oxygen %, pressure, airflow, gravity",\n'
        '  "variables": "what varied between tests",\n'
        '  "sensors": "sensors / measurement types",\n'
        '  "hardware": "apparatus / facility used",\n'
        '  "pillars": ["prevention","detection","suppression"],\n'
        '  "crew_relevance": "low|medium|high",\n'
        '  "data_richness": "low|medium|high",\n'
        '  "directness": "direct|adjacent",\n'
        '  "summary": "2-3 sentence plain-English summary",\n'
        '  "insight": "1-2 sentence fire-safety interpretation",\n'
        '  "earth_application": "one sentence terrestrial spin-off, or empty string"\n'
        '}\n\nPAPERS:\n' + papers
    )


def extract(inv):
    """Ask Gemini for the structured extraction, with retries."""
    last = None
    for attempt in range(4):
        try:
            return embed.generate_json(prompt_for(inv))
        except Exception as e:
            last = e
            time.sleep(3 + attempt * 3)
    raise last


def normalize(inv, data):
    if not isinstance(data, dict):
        raise RuntimeError('non-dict: ' + repr(data)[:200])
    g = lambda k, d='': str(data.get(k, d))
    out = {'id': inv['id'], 'name': inv['name'], 'papers': inv['papers'],
           'objective': g('objective'), 'fuels': g('fuels'),
           'conditions': g('conditions'), 'variables': g('variables'),
           'sensors': g('sensors'), 'hardware': g('hardware'),
           'pillars': [p for p in (data.get('pillars') or []) if p in PILLARS],
           'crew_relevance': g('crew_relevance', 'medium'),
           'data_richness': g('data_richness', 'medium'),
           'directness': g('directness', 'direct'),
           'summary': g('summary'), 'insight': g('insight'),
           'earth_application': g('earth_application')}
    out['score'], out['reasons'] = rubric(out)
    return out


def load_existing():
    if not os.path.exists(OUT):
        return []
    try:
        return json.load(open(OUT, encoding='utf-8')).get('investigations', [])
    except Exception:
        return []


def main():
    force = '--force' in sys.argv
    limit = int(sys.argv[sys.argv.index('--limit') + 1]) if '--limit' in sys.argv else None
    done = {i['id']: i for i in load_existing() if i.get('summary') != 'extraction failed'}
    invs = INVESTIGATIONS[:limit] if limit else INVESTIGATIONS
    os.makedirs(config.ASSETS_DIR, exist_ok=True)
    results = []
    for idx, inv in enumerate(invs, 1):
        if not force and inv['id'] in done:
            print(f'[{idx}/{len(invs)}] {inv["name"]} - cached')
            results.append(done[inv['id']])
            continue
        print(f'[{idx}/{len(invs)}] {inv["name"]} ...')
        try:
            rec = normalize(inv, extract(inv))
        except Exception as e:
            print(f'  !! failed: {e}')
            rec = {'id': inv['id'], 'name': inv['name'], 'papers': inv['papers'],
                   'objective': '', 'fuels': '', 'conditions': '', 'variables': '',
                   'sensors': '', 'hardware': '', 'pillars': [],
                   'crew_relevance': 'medium', 'data_richness': 'medium',
                   'directness': 'direct', 'summary': 'extraction failed',
                   'insight': '', 'earth_application': '', 'score': 0, 'reasons': []}
        results.append(rec)
        json.dump({'generated': time.strftime('%Y-%m-%d %H:%M:%S'),
                   'investigations': results}, open(OUT, 'w', encoding='utf-8'),
                  ensure_ascii=False, indent=2)
        time.sleep(15)
    results.sort(key=lambda r: -r.get('score', 0))
    json.dump({'generated': time.strftime('%Y-%m-%d %H:%M:%S'),
               'investigations': results}, open(OUT, 'w', encoding='utf-8'),
              ensure_ascii=False, indent=2)
    print(f'\nWrote {len(results)} investigations -> {OUT}')


if __name__ == '__main__':
    main()
