"""Composite the layered scene.

    Layer 1 (bottom): starfield  -> full CRT pass
    Layer 2 (middle): planetary system — placeholder for now (the cube prototype)
    Layer 3 (top):    terminal   -> *light* CRT pass (text stays legible)

Layer 3 sits "right under the filters" but is swayed far less, so the UI text
stays sharp against the warped, glowing background.
"""
from PIL import Image

from crt import apply_crt, apply_terminal, curvature_scale
from main import CELL_W, CELL_H, grid_to_image, load_font
from pointer import Sonar
from stars import Starfield
from terminal import SCRIPT, Terminal
from themes import color_of


class Scene:
    def __init__(self, W, H):
        self.W = W
        self.H = H
        self.font = load_font()
        self.stars = Starfield()
        self.terminal = Terminal(SCRIPT, x=4, y=27, w=44, h=11)
        self.sonar = Sonar()
        self._bg = None          # cached background (stars + full CRT)
        self._bg_t = 0.0         # absolute time the background was last rendered

    def invalidate(self):
        """Force a background re-render (called when a dial changes)."""
        self._bg = None

    def render(self, t, dt, d):
        # Update tunables from the dials.
        self.stars.twinkle = d["star_twinkle"]
        self.terminal.step(dt)
        color = color_of(d["theme"])

        # The background is static except for the slow twinkle, so re-render it
        # occasionally. The terminal is drawn every frame, so typing stays
        # responsive.
        if self._bg is None or (t - self._bg_t) >= 0.2:
            self._bg_t = t
            self._bg = self._render_background(t, d, color)

        term, tx, ty = self._render_terminal(t, d, color)
        bg = self._bg.convert("RGBA")
        bg.paste(term, (tx, ty), term)
        ptr = self._render_pointer(t, d, color)
        if ptr is not None:
            crop, px, py = ptr
            bg.paste(crop, (px - crop.width // 2, py - crop.height // 2), crop)
        return bg.convert("RGB")

    def _render_background(self, t, d, color):
        cells = [[" "] * self.W for _ in range(self.H)]
        self.stars.draw(cells, t)
        rows = ["".join(r) for r in cells]
        return apply_crt(
            grid_to_image(rows, color=color),
            curvature_strength=d["curvature"],
            vignette_strength=d["vignette"],
            scanline_strength=d["scanlines"],
            glow_strength=d["glow"],
            bezel_n=d["bezel_n"],
            bezel_inset=d["bezel_inset"],
            bezel_aspect=d["aspect"],
            color=color,
        )

    def _render_terminal(self, t, d, color):
        img, x0, y0 = self.terminal.draw(t, CELL_W, CELL_H, self.font, color=color)
        return apply_terminal(img), x0, y0

    def _render_pointer(self, t, d, color):
        crop = self.sonar.draw(t, color)
        if crop is None:
            return None
        # Barrel curvature: the pointer magnifies and is pushed outward toward
        # the screen edges — matching how the background is warped, so it reads
        # as sitting on the curved tube (not a flat overlay).
        W = self.W * CELL_W
        H = self.H * CELL_H
        cx, cy = W / 2.0, H / 2.0
        k = curvature_scale(self.sonar.x, self.sonar.y, W, H, d["curvature"])
        s = max(1, int(crop.width * k))
        crop = crop.resize((s, s), Image.BILINEAR)
        px = int(cx + (self.sonar.x - cx) * k)
        py = int(cy + (self.sonar.y - cy) * k)
        return crop, px, py
