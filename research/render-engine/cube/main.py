"""Rotating cube demo — render ASCII frames + green CRT-overlaid PNGs."""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

from crt import apply_crt
from rasterizer import render_frame

# Windows terminals default to cp1252; allow the dense ░▒▓█ block chars to print.
# Under pythonw (no console) sys.stdout is None, so guard the call.
if sys.stdout is not None:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

W, H = 120, 60
CELL_W, CELL_H = 9, 16
GREEN = (0, 255, 0)


_FONT = None


def load_font():
    """Load the monospace font once and cache it (a TTF load is ~50 ms).

    Prefers the bundled futuristic Share Tech Mono, then falls back to the
    system monospace fonts.
    """
    global _FONT
    if _FONT is not None:
        return _FONT
    here = os.path.dirname(os.path.abspath(__file__))
    for path in (
        os.path.join(here, "ShareTechMono-Regular.ttf"),
        "C:/Windows/Fonts/consola.ttf",
        "C:/Windows/Fonts/cour.ttf",
        "C:/Windows/Fonts/lucon.ttf",
    ):
        try:
            _FONT = ImageFont.truetype(path, CELL_H)
            return _FONT
        except OSError:
            continue
    _FONT = ImageFont.load_default()
    return _FONT


_glyph_masks = {}


def _glyph_mask(char, cell_w, cell_h, font):
    key = (char, cell_w, cell_h)
    m = _glyph_masks.get(key)
    if m is None:
        g = Image.new("L", (cell_w, cell_h), 0)
        d = ImageDraw.Draw(g)
        d.text((0, 0), char, fill=255, font=font)
        m = np.asarray(g, dtype=np.uint8)
        _glyph_masks[key] = m
    return m


def grid_to_image(rows, cell_w=CELL_W, cell_h=CELL_H, color=(0, 255, 0)):
    """Draw the ASCII grid as colored-on-black text via cached glyph masks.

    Each unique glyph is rasterized once (grayscale) and tinted with `color`.
    """
    w = len(rows[0]) if rows else 0
    h = len(rows)
    font = load_font()
    mask = np.zeros((h * cell_h, w * cell_w), dtype=np.uint8)
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch != " ":
                mask[y * cell_h:(y + 1) * cell_h,
                     x * cell_w:(x + 1) * cell_w] = _glyph_mask(ch, cell_w, cell_h, font)
    rgb = (mask[..., None].astype(np.uint16) * np.array(color, dtype=np.uint16) // 255).astype(np.uint8)
    return Image.fromarray(rgb)


if __name__ == "__main__":
    os.makedirs("frames", exist_ok=True)
    frames = 36
    for i in range(frames):
        t = i / frames * 2.0 * math.pi
        rows = render_frame(W, H, t)
        if i in (0, 9, 18):
            print(f"--- frame {i} (t={t:.2f}) ---")
            print("\n".join(rows))
        img = grid_to_image(rows)
        img = apply_crt(img)
        img.save(f"frames/frame_{i:02d}.png")
    print(f"\nWrote {frames} frames to frames/")
