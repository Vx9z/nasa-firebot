"""Layer 3 (top) — an 80s terminal: black box, green text, live input, cursor.

The startup script reveals instantly and is paced by explicit `(pause N)` markers
(N = milliseconds) instead of a fixed typing speed, so the terminal never feels
laggard. Rendered as a cropped RGBA box composited over the scene.
"""
import re

from PIL import Image, ImageDraw

BLACK = (0, 0, 0, 255)

SCRIPT = (
    "> INITIALIZING...\n"
    "(pause 350)\n"
    "> RENDER ENGINE v0.1\n"
    "> [OK] STARFIELD\n"
    "(pause 200)\n"
    "> [OK] CRT FILTERS\n"
    "> [OK] TERMINAL LAYER\n"
    "(pause 250)\n"
    "> ALL SYSTEMS NOMINAL\n"
)


def _parse(script):
    """Split 'text (pause N) text' into [[chunk, pause_seconds], ...].

    A pause marker may sit on its own line; its trailing newline is swallowed
    so the script doesn't gain a blank line.
    """
    segments = []
    pos = 0
    for m in re.finditer(r"\(pause\s+(\d+)\)", script):
        chunk = script[pos:m.start()]
        if chunk:
            segments.append([chunk, float(m.group(1)) / 1000.0])
        pos = m.end()
        if pos < len(script) and script[pos] == "\n":
            pos += 1
    tail = script[pos:]
    if tail:
        segments.append([tail, 0.0])
    return segments


class Terminal:
    def __init__(self, script, x=4, y=27, w=44, h=11):
        self.segments = _parse(script)
        self.x, self.y = x, y          # box position (in cells)
        self.w, self.h = w, h          # box size (in cells)
        self.elapsed = 0.0
        self.input = ""                # live user input
        self.history = []              # completed commands (echoed)

    def step(self, dt):
        self.elapsed += dt

    def key(self, ch):
        self.input += ch

    def backspace(self):
        self.input = self.input[:-1]

    def enter(self):
        if self.input.strip():
            self.history.append("> " + self.input)
        self.input = ""

    def delete_word(self):
        """Delete the last word (Ctrl+Backspace)."""
        s = self.input.rstrip()
        idx = s.rfind(" ")
        self.input = s[:idx] if idx != -1 else ""

    def clear_line(self):
        """Clear the whole line (Ctrl+U)."""
        self.input = ""

    def _revealed(self):
        """Text revealed so far — chunks appear instantly, pauses consume time."""
        acc = 0.0
        text = ""
        for chunk, pause in self.segments:
            if acc <= self.elapsed:
                text += chunk
            acc += pause
            if acc > self.elapsed:
                break
        return text

    def draw(self, t, cell_w, cell_h, font, color=(0, 255, 0)):
        """Return (image, x0, y0) — a cropped image of just the box, fast to
        composite over the background every frame."""
        rgba = (color[0], color[1], color[2], 255)
        w_px = self.w * cell_w
        h_px = self.h * cell_h
        x0 = int(self.x * cell_w)
        y0 = int(self.y * cell_h)

        img = Image.new("RGBA", (w_px, h_px), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        d.rectangle([0, 0, w_px - 1, h_px - 1], fill=BLACK, outline=rgba, width=1)

        lines = self._revealed().split("\n") + self.history + ["> " + self.input]
        max_lines = self.h - 2
        lines = lines[-max_lines:] if len(lines) > max_lines else lines

        ty = 6
        for line in lines:
            d.text((8, ty), line, fill=rgba, font=font)
            ty += cell_h

        # Blinking block cursor at the end of the prompt line, aligned to the
        # text's actual glyph box (not a hardcoded height).
        if int(t * 2.0) % 2 == 0:
            last = lines[-1]
            last_y = ty - cell_h
            bbox = d.textbbox((8, last_y), last, font=font)
            cx = bbox[2] + 1
            cy = bbox[1]
            ch = bbox[3] - bbox[1]
            d.rectangle([cx, cy, cx + cell_w - 2, cy + ch], fill=rgba)

        return img, x0, y0
