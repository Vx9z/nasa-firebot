"""The render engine — transform -> global illumination -> rasterize -> ASCII.

kciter.so-style pipeline with global illumination (ambient + a point light with
distance falloff) so faces shade smoothly and nothing goes pure black.
"""
import math

import numpy as np

from mesh import VERTS, triangles
from vec import project, rotate_x, rotate_y

RAMP = " .:-=+*#░▒▓█"   # dense shading ramp (space -> full block)
_RAMP = np.array(list(RAMP))
SCALE = 2.0            # cube half-size in world units
CELL_ASPECT = 9.0 / 16.0  # char width/height in px (fixes the non-square glyph stretch)
FOCAL = 140.0          # perspective focal length (long = telephoto = cube-like)
DISTANCE = 14.0        # cube z-center (far enough that depth is small vs distance)
AMBIENT = 0.30         # global illumination floor (no pure-black faces)
LIGHT = (6.0, 5.0, 4.0)  # point light (world space: front-right-top)
FALLOFF = 0.01         # distance attenuation constant
INTENSITY = 2.6        # light power (so bright faces reach the dense block chars)


def render_frame(width, height, t, ambient=None, intensity=None, ss=3):
    """Render one frame of the rotating, lit cube -> list of ASCII rows.

    `ambient` / `intensity` override the module constants for live tuning.
    `ss` is the supersampling factor: each cell is sampled ss×ss times and the
    average brightness is used, so triangle edges get a coverage falloff instead
    of jagged stair-steps.
    """
    amb = AMBIENT if ambient is None else ambient
    inten = INTENSITY if intensity is None else intensity
    ss = max(1, int(ss))

    # 1) World transform: rotate, scale, push back along +Z.
    world = []
    for v in VERTS:
        r = rotate_y(v, t * 0.9)
        r = rotate_x(r, t * 0.6)
        world.append((r[0] * SCALE, r[1] * SCALE, r[2] * SCALE + DISTANCE))

    # 2) Project to screen space.
    screen = [project(v, FOCAL, width / 2.0, height / 2.0, CELL_ASPECT) for v in world]

    # 3) Supersampled rasterization with a depth buffer.
    sw, sh = width * ss, height * ss
    z_buffer = np.full((sh, sw), np.inf, dtype=np.float32)
    bright_buffer = np.zeros((sh, sw), dtype=np.float32)

    for a, b, c, normal in triangles():
        n = rotate_y(normal, t * 0.9)
        n = rotate_x(n, t * 0.6)

        # Backface culling: visible only if the normal points toward the camera (-Z).
        if n[2] >= 0:
            continue

        # Face center (world space) -> vector to the light + distance falloff.
        fcx = (world[a][0] + world[b][0] + world[c][0]) / 3.0
        fcy = (world[a][1] + world[b][1] + world[c][1]) / 3.0
        fcz = (world[a][2] + world[b][2] + world[c][2]) / 3.0
        lvx, lvy, lvz = LIGHT[0] - fcx, LIGHT[1] - fcy, LIGHT[2] - fcz
        dist2 = lvx * lvx + lvy * lvy + lvz * lvz
        dist = math.sqrt(dist2) or 1.0
        lx, ly, lz = lvx / dist, lvy / dist, lvz / dist
        attenuation = 1.0 / (1.0 + FALLOFF * dist2)

        diffuse = max(0.0, n[0] * lx + n[1] * ly + n[2] * lz)
        light = min(1.0, diffuse * attenuation * inten)
        bright = amb + (1.0 - amb) * light

        p1, p2, p3 = screen[a], screen[b], screen[c]
        minx = max(0, int(min(p1[0], p2[0], p3[0])))
        maxx = min(width - 1, int(max(p1[0], p2[0], p3[0])))
        miny = max(0, int(min(p1[1], p2[1], p3[1])))
        maxy = min(height - 1, int(max(p1[1], p2[1], p3[1])))
        if maxx < minx or maxy < miny:
            continue
        depth = (p1[2] + p2[2] + p3[2]) / 3.0

        # Sub-sample centers (char units) over the triangle's bounding box.
        xs = (np.arange(minx * ss, (maxx + 1) * ss, dtype=np.float32) + 0.5) / ss
        ys = (np.arange(miny * ss, (maxy + 1) * ss, dtype=np.float32) + 0.5) / ss
        xg, yg = np.meshgrid(xs, ys)

        ax, ay = p1[0], p1[1]
        bx, by = p2[0], p2[1]
        cx, cy = p3[0], p3[1]
        d1 = (xg - bx) * (ay - by) - (ax - bx) * (yg - by)
        d2 = (xg - cx) * (by - cy) - (bx - cx) * (yg - cy)
        d3 = (xg - ax) * (cy - ay) - (cx - ax) * (yg - ay)
        inside = ~(((d1 < 0) | (d2 < 0) | (d3 < 0)) & ((d1 > 0) | (d2 > 0) | (d3 > 0)))

        y0, y1 = miny * ss, (maxy + 1) * ss
        x0, x1 = minx * ss, (maxx + 1) * ss
        sub_z = z_buffer[y0:y1, x0:x1]
        sub_b = bright_buffer[y0:y1, x0:x1]
        mask = inside & (depth < sub_z)
        sub_z[mask] = depth
        sub_b[mask] = bright

    # 4) Downsample: average brightness over each ss×ss block -> ramp char.
    avg = bright_buffer.reshape(height, ss, width, ss).mean(axis=(1, 3))
    idx = np.clip((avg * (len(RAMP) - 1)).round().astype(np.int32), 0, len(RAMP) - 1)
    chars = _RAMP[idx]
    return ["".join(chars[y]) for y in range(height)]
