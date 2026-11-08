"""A cube — 8 vertices + 6 faces, each face with its outward normal."""

VERTS = [
    (-1, -1, -1), (1, -1, -1), (1, 1, -1), (-1, 1, -1),  # 0..3 back
    (-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1),      # 4..7 front
]

# (quad vertex indices, outward normal)
FACES = [
    ((4, 5, 6, 7), (0, 0, 1)),    # front
    ((0, 3, 2, 1), (0, 0, -1)),   # back
    ((2, 6, 7, 3), (0, 1, 0)),    # top
    ((0, 1, 5, 4), (0, -1, 0)),   # bottom
    ((0, 4, 7, 3), (-1, 0, 0)),   # left
    ((1, 2, 6, 5), (1, 0, 0)),    # right
]


def triangles():
    """Flatten faces into triangles, each carrying its face's outward normal."""
    out = []
    for quad, normal in FACES:
        a, b, c, d = quad
        out.append((a, b, c, normal))
        out.append((a, c, d, normal))
    return out
