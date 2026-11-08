"""Minimal 3D math — rotation + perspective projection."""
import math


def rotate_y(p, a):
    x, y, z = p
    c, s = math.cos(a), math.sin(a)
    return (x * c + z * s, y, -x * s + z * c)


def rotate_x(p, a):
    x, y, z = p
    c, s = math.cos(a), math.sin(a)
    return (x, y * c - z * s, y * s + z * c)


def project(p, focal, cx, cy, aspect=1.0):
    """Perspective-project a 3D point (camera looks down +Z) -> (sx, sy, depth).

    `aspect` is the pixel width/height of a cell (CELL_W / CELL_H). Because
    glyphs are taller than wide, the y coordinate is scaled by `aspect` so a
    square object stays square on screen (otherwise cubes look stretched tall).
    """
    x, y, z = p
    inv = focal / z
    return (cx + x * inv, cy - y * inv * aspect, z)
