"""ASCII render engine prototype — vector shapes → brightness → ASCII.

Mirrors the Reddit "ASCII solar systems" technique:
  1. A hidden MONOCHROME vector layer draws shapes (sun, orbiting planets,
     a rotating ship) into a grayscale buffer.
  2. The display is an ASCII grid; each cell samples the brightness underneath.
  3. Brightness is quantized to a character via a ramp (dense = bright).
  4. Rendered green-on-black (Fallout-style), also exported as PNG frames.

Run:  python render.py
"""
import math
import os

from PIL import Image, ImageDraw, ImageFont

# ---- config ----
W, H = 120, 40            # ASCII grid resolution (chars)
SS = 4                    # supersampling factor (anti-aliasing)
RAMP = " .:-=+*#%@"        # brightness → char (empty → dense)
GREEN = (0, 255, 0)
BG = (0, 0, 0)
FONT_SIZE = 16
CELL_W, CELL_H = 9, 16    # pixel size of each char cell in the PNG export


def new_buffer():
    return Image.new("L", (W * SS, H * SS), 0)


def draw_circle(buf, cx, cy, r, value):
    ImageDraw.Draw(buf).ellipse([cx - r, cy - r, cx + r, cy + r], fill=value)


def draw_poly(buf, pts, value):
    ImageDraw.Draw(buf).polygon(pts, fill=value)


def quantize(buf):
    """Downsample the supersampled buffer to the grid, then map brightness→char."""
    small = buf.resize((W, H), Image.BOX)  # area-average = brightness underneath
    px = small.load()
    rows = []
    for y in range(H):
        row = []
        for x in range(W):
            b = px[x, y]
            row.append(RAMP[b * (len(RAMP) - 1) // 255])
        rows.append("".join(row))
    return rows


def render_frame(t):
    buf = new_buffer()
    cx, cy = W * SS / 2, H * SS / 2

    # Sun (bright core)
    draw_circle(buf, cx, cy, 5 * SS, 210)

    # Orbiting planets (elliptical, flattened for a slight perspective)
    for radius, size, speed, phase in [
        (11 * SS, 2 * SS, 1.0, 0.0),
        (17 * SS, 3 * SS, 0.55, 2.0),
        (24 * SS, 2 * SS, 0.3, 4.0),
    ]:
        ang = t * speed + phase
        px = cx + radius * math.cos(ang)
        py = cy + radius * math.sin(ang) * 0.45
        draw_circle(buf, px, py, size, 150)

    # A rotating ship (triangle) near the center
    ship_r = 8 * SS
    pts = []
    for k in range(3):
        a = t * 1.4 + k * (2 * math.pi / 3)
        pts.append((cx + ship_r * math.cos(a), cy + ship_r * math.sin(a)))
    draw_poly(buf, pts, 255)

    return quantize(buf)


def load_font():
    for path in (
        "C:/Windows/Fonts/consola.ttf",
        "C:/Windows/Fonts/cour.ttf",
        "C:/Windows/Fonts/lucon.ttf",
    ):
        try:
            return ImageFont.truetype(path, FONT_SIZE)
        except OSError:
            continue
    return ImageFont.load_default()


def to_image(rows):
    img = Image.new("RGB", (W * CELL_W, H * CELL_H), BG)
    d = ImageDraw.Draw(img)
    font = load_font()
    for y, row in enumerate(rows):
        d.text((0, y * CELL_H), row, fill=GREEN, font=font)
    return img


if __name__ == "__main__":
    frames = [render_frame(t) for t in (0.0, 0.6, 1.2, 1.8, 2.4, 3.0)]

    # Print the first frame to the terminal (as plain ASCII).
    print("\n".join(frames[0]))

    # Export green-on-black PNG frames.
    os.makedirs("frames", exist_ok=True)
    for i, rows in enumerate(frames):
        to_image(rows).save(f"frames/frame_{i}.png")
    print(f"\nWrote {len(frames)} frames to frames/")
