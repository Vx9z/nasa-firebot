"""Layer 4 (top) — a sonar-style mouse pointer that pulses and radiates.

A smooth vector overlay (not ASCII). Renders a single small crop (fast), with a
soft phosphor glow, a slow pulse, and one close expanding ring. The pointer is
immune to the screen filters (no curvature/scanlines) so it costs almost nothing.
"""
import math

from PIL import Image, ImageDraw, ImageFilter


class Sonar:
    R = 24   # crop half-size (px)

    def __init__(self):
        self.x = -100
        self.y = -100
        self.on = False

    def move(self, x, y):
        self.x, self.y = x, y
        self.on = True

    def hide(self):
        self.on = False

    def draw(self, t, color):
        """Return a small RGBA crop with the sonar centred, or None if hidden."""
        if not self.on:
            return None
        c = (color[0], color[1], color[2], 255)
        cx = cy = self.R

        # Strong phosphor glow — a bright dot blurred wide behind the centre dot.
        pulse = 0.85 + 0.15 * math.sin(t * 1.8)
        r0 = 3.0 * pulse
        glow = Image.new("RGBA", (self.R * 2, self.R * 2), (0, 0, 0, 0))
        gd = ImageDraw.Draw(glow)
        gd.ellipse([cx - r0 - 1, cy - r0 - 1, cx + r0 + 1, cy + r0 + 1],
                   fill=(c[0], c[1], c[2], 255))
        img = glow.filter(ImageFilter.GaussianBlur(7))

        d = ImageDraw.Draw(img)
        # Bright centre dot.
        d.ellipse([cx - r0, cy - r0, cx + r0, cy + r0], fill=c)

        # One close expanding ring, slow, fading out (halved expansion).
        ph = (t / 3.2) % 1.0
        r = 4.0 + ph * 4.0
        a = int(220 * (1.0 - ph))
        if a > 4:
            d.ellipse([cx - r, cy - r, cx + r, cy + r],
                      outline=(c[0], c[1], c[2], a), width=1)

        return img
