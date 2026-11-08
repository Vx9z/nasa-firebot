"""CRT overlay — convex curvature, vignette, scanlines, phosphor glow.

Inspired by RetroArch's crt-geom: the flat image is warped onto a convex screen,
the corners darken, and the green phosphor glows. Implemented with numpy + Pillow.
"""
import numpy as np
from PIL import Image, ImageFilter

# Cached normalized coordinate grids per image size — reused every frame so the
# live tuner doesn't re-allocate ~11 MB of coordinate arrays per effect.
_grid_cache = {}


def _grids(h, w):
    key = (h, w)
    g = _grid_cache.get(key)
    if g is None:
        ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
        nx = xs / w * 2.0 - 1.0
        ny = ys / h * 2.0 - 1.0
        r2 = nx * nx + ny * ny
        g = (nx, ny, r2)
        _grid_cache[key] = g
    return g


_curv_cache = {}


def curvature(rgb, strength=0.06):
    """Gentle convex warp (barrel) — just enough to suggest the screen bulge.

    The warp index is cached per (size, strength) so re-rendering is a single
    gather, not a re-derivation of the coordinate map.
    """
    h, w = rgb.shape[:2]
    key = (h, w, round(strength, 4))
    idx = _curv_cache.get(key)
    if idx is None:
        nx, ny, r2 = _grids(h, w)
        k = 1.0 + strength * r2
        sx = ((nx / k + 1.0) * 0.5 * w).clip(0, w - 1).astype(np.int32)
        sy = ((ny / k + 1.0) * 0.5 * h).clip(0, h - 1).astype(np.int32)
        idx = sy * w + sx
        _curv_cache[key] = idx
    return rgb.reshape(-1, rgb.shape[-1])[idx]


_vignette_cache = {}


def vignette(rgb, strength=0.30):
    """Darken the corners (edges fall away on a curved screen)."""
    h, w = rgb.shape[:2]
    key = (h, w, round(strength, 3))
    factor = _vignette_cache.get(key)
    if factor is None:
        _, _, r2 = _grids(h, w)
        factor = (1.0 - strength * r2.clip(0.0, 1.0))[..., None].astype(np.float32)
        _vignette_cache[key] = factor
    return (rgb * factor).astype(np.uint8)


def scanlines(rgb, strength=0.42, every=3):
    """Darken every Nth scanline (the CRT raster)."""
    out = rgb.copy()
    out[::every] = (out[::every] * (1.0 - strength)).astype(np.uint8)
    return out


def glow(rgb, strength=0.55, radius=3):
    """Phosphor glow — blur the image and blend it back (works for any theme)."""
    img = Image.fromarray(rgb)
    blurred = img.filter(ImageFilter.GaussianBlur(radius))
    return np.asarray(Image.blend(img, blurred, strength))


_bezel_cache = {}


def bezel(rgb, n=2.4, inset=0.03, aspect=None):
    """Curved black frame around a screen of a chosen aspect ratio.

    A convex tube's corners curve away from the viewer, so head-on the screen
    ends in a curved black bezel — the "bent black bars". Pixels outside the
    superellipse  |x/ax|^n + |y/ay|^n <= 1  are forced to black.

      * n      : n=2 ellipse, n=4 squircle (rounded rectangle) — 2.4 is a nice bend
      * inset  : shrinks the screen region -> width of the visible black frame
      * aspect : screen width/height (None = match the image). Decoupled from `n`
                 and `inset`, so the screen ratio is flexible.
    """
    h, w = rgb.shape[:2]
    if aspect is None:
        aspect = w / h
    key = (h, w, round(n, 2), round(inset, 4), round(aspect, 3))
    inside = _bezel_cache.get(key)
    if inside is None:
        nx, ny, _ = _grids(h, w)
        ax = ay = 1.0 - inset
        if aspect * h > w:      # wider than the image -> cap the width
            ay = ax * w / (aspect * h)
        else:                   # taller than/equal -> cap the height
            ax = ay * aspect * h / w
        inside = (np.abs(nx) / ax) ** n + (np.abs(ny) / ay) ** n <= 1.0
        _bezel_cache[key] = inside
    return np.where(inside[..., None], rgb, 0).astype(np.uint8)


_glow_map_cache = {}


def screen_glow(rgb, center=60, edge=30, color=(0, 255, 0)):
    """Global illumination: a radial glow filling the whole screen.

    Bright near the center, fading to a still-visible glow at the edges, so the
    lit screen reads clearly against the pure-black bezel. The glow map is
    cached; `color` tints it to the active theme.
    """
    h, w = rgb.shape[:2]
    key = (h, w, center, edge)
    m = _glow_map_cache.get(key)
    if m is None:
        _, _, r2 = _grids(h, w)
        m = (edge + (center - edge) * (1.0 - r2.clip(0.0, 1.0))).astype(np.float32)
        _glow_map_cache[key] = m
    out = rgb.astype(np.float32)
    out += m[..., None] * (np.array(color, dtype=np.float32) / 255.0)
    return np.clip(out, 0, 255).astype(np.uint8)


def apply_crt(
    image,
    curvature_strength=0.06,
    vignette_strength=0.30,
    scanline_strength=0.42,
    glow_strength=0.55,
    bezel_n=2.4,
    bezel_inset=0.03,
    bezel_aspect=None,
    color=(0, 255, 0),
):
    """Apply the full CRT overlay.

    screen glow -> subtle convex curvature -> vignette -> scanlines ->
    phosphor bloom -> curved black bezel.

    The curvature is kept *subtle* (the content only looks gently convex); the
    curved black frame is what actually sells the CRT, and the radial glow keeps
    the screen distinct from that frame. `bezel_aspect` sets the screen's aspect
    ratio (None = match the image) independent of the bezel's corner roundness.
    `color` is the theme's phosphor tint.
    """
    rgb = np.asarray(image.convert("RGB")).copy()
    rgb = screen_glow(rgb, color=color)
    rgb = curvature(rgb, curvature_strength)
    rgb = vignette(rgb, vignette_strength)
    rgb = scanlines(rgb, scanline_strength)
    rgb = glow(rgb, glow_strength)
    rgb = bezel(rgb, bezel_n, bezel_inset, bezel_aspect)
    return Image.fromarray(rgb)


def apply_terminal(image, scanline_strength=0.15):
    """A *light* CRT pass for the top UI layer — keeps text legible and fast.

    No curvature/bezel (so the text isn't warped) and no phosphor glow (so the
    terminal stays responsive while typing) — just a whisper of scanlines.
    Alpha is preserved for compositing.
    """
    rgba = np.asarray(image.convert("RGBA")).copy()
    rgb = rgba[..., :3].copy()
    rgb = scanlines(rgb, scanline_strength, every=3)
    rgba[..., :3] = rgb
    return Image.fromarray(rgba, "RGBA")


def curvature_scale(x, y, w, h, strength):
    """Barrel scale factor at screen point (x, y) — content magnifies by this.

    Used by the mouse pointer: instead of a full-image warp (expensive and
    imperceptible on a tiny dot), the pointer simply scales by this factor so it
    still reads as sitting on the curved screen.
    """
    nx = x / (w * 0.5) - 1.0
    ny = y / (h * 0.5) - 1.0
    return 1.0 + strength * (nx * nx + ny * ny)
