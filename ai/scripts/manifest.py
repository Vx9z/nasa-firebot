"""Build ai/images/manifest.json from the extracted figure filenames.

Each entry: {file, nn, page, label}. The label is a searchable text tag;
the manifest is a plain sidecar (regenerated on any re-label), NOT embedded
metadata in the image bytes.
"""
import os
import re
import json
from config import IMAGES_DIR

IMAGE_EXTS = ('.png', '.jpeg', '.jpg', '.gif', '.bmp', '.tif', '.tiff')


def build_manifest():
    manifest = []
    if not os.path.isdir(IMAGES_DIR):
        return manifest
    for f in sorted(os.listdir(IMAGES_DIR)):
        if not f.lower().endswith(IMAGE_EXTS):
            continue
        nn = f[:2]
        m = re.search(r'_p(\d+)_', f)
        page = int(m.group(1)) if m else 0
        label = re.sub(r'[._-]+', ' ', f[3:]).strip()
        manifest.append({'file': f, 'nn': nn, 'page': page, 'label': label})
    out = os.path.join(IMAGES_DIR, 'manifest.json')
    json.dump(manifest, open(out, 'w', encoding='utf-8'), indent=2)
    return manifest


def load_manifest():
    path = os.path.join(IMAGES_DIR, 'manifest.json')
    if not os.path.exists(path):
        return build_manifest()
    return json.load(open(path, encoding='utf-8'))
