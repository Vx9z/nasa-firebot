"""One-off calibration of the investigation ranking.

Flash-lite over-classified a few investigations (all three pillars + high +
high + direct = 100). These manual overrides restore a sensible, defensible
ranking. Recomputes scores deterministically and re-sorts.

Usage: python calibrate.py
"""
import json
import os

import config

OUT = os.path.join(config.ASSETS_DIR, 'investigations.json')

# id -> corrected rubric fields (only the ones that were mis-scored)
CORRECTIONS = {
    'materials-toxicity': {
        'pillars': ['prevention', 'detection'],
        'crew_relevance': 'high',
        'data_richness': 'high',
        'directness': 'direct',
    },
    'roadmap': {
        'pillars': ['prevention', 'detection', 'suppression'],
        'crew_relevance': 'high',
        'data_richness': 'low',
        'directness': 'direct',
    },
    'droplet-gas': {
        'pillars': ['suppression'],
        'crew_relevance': 'medium',
        'data_richness': 'high',
        'directness': 'adjacent',
    },
    'foundations': {
        'pillars': [],
        'crew_relevance': 'low',
        'data_richness': 'medium',
        'directness': 'adjacent',
    },
}

PILLARS = ('prevention', 'detection', 'suppression')


def rubric(inv):
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


def main():
    data = json.load(open(OUT, encoding='utf-8'))
    for inv in data['investigations']:
        corr = CORRECTIONS.get(inv['id'])
        if corr:
            inv.update(corr)
            inv['score'], inv['reasons'] = rubric(inv)
            print(f"  {inv['id']}: -> {inv['score']}")
    data['investigations'].sort(key=lambda r: -r.get('score', 0))
    json.dump(data, open(OUT, 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
    print('done')


if __name__ == '__main__':
    main()
