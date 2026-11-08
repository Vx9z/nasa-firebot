# 📝 Research Log — Render Engine

> Running notes — we're **not done researching**. Add findings here as we pull more.

---

## 1. kciter.so — "Building an ASCII 3D Renderer" ⭐ (your favourite)
URL: https://kciter.so/posts/ascii-3d-renderer/en/

A **full 3D renderer** (TypeScript/JS, runs in browser) — not 2D tricks, a real
rendering pipeline:

1. **World transform** — rotate/translate/scale the model (4D homogeneous coords).
2. **View transform** — place the camera.
3. **Projection transform** — perspective projection → 2D.
4. **Rasterization** — triangles: bounding box + `isPointInTriangle` test.
5. **Fragment processing** — **depth buffer (z-buffer)** for occlusion + shading.

- Shading → brightness → character via a `Shade` ramp.
- Extended-ASCII ramp for higher contrast: `'·┼╬░▒▓█'` (block glyphs).
- Core mental model: **"think of ASCII characters as slightly large pixels."**

**Takeaways:** the matrix pipeline is directly portable to Dart; a **z-buffer**
is what makes occlusion correct; block chars give more shading levels than
plain ASCII.

---

## 2. areofyl/fetch — donut.c-inspired spinning logo ⭐⭐
URL: https://github.com/areofyl/fetch · deep dive: https://asdesai.com/blog/how-fetch-works/

A `neofetch`-style tool that spins your distro logo in 3D with **Blinn-Phong**
shading. Single-file C, no deps beyond libm. Pipeline:

1. **Heightmap** — each char gets a weight from visual density (`@` heavy, `.`
   light, `█` full, `░` thin) → becomes Z-height → flat logo → **3D relief**.
2. **Point cloud** — sample the heightmap into 3D points.
3. **Surface normals** — finite differences of the height gradient.
4. **Rotation + perspective projection + z-buffer**.
5. **Blinn-Phong** (diffuse + specular) → brightness → `.,-~:;=!*#$@` ramp.

**Shading modes (the clever part):**
| mode | resolution | glyphs |
|---|---|---|
| `ascii` | 1 char / cell | `.,-~:;=!*#$@` |
| `blocks` | 2×2 sub-cell coverage | `░▒▓█` |
| `sextants` | 2×3 sub-cell coverage | Symbols for Legacy Computing |

**Takeaways:** sub-cell **block shading doubles/triples effective resolution for
free**; heightmap-from-art is a neat "2D art → 3D object" trick; Blinn-Phong with
finite-difference normals is simple and looks solid.

---

## 3. VidASCII — video → ASCII
URL: https://github.com/lahirunim/VidASCII

OpenCV reads video frame-by-frame → grayscale → resize to a char grid →
brightness → ASCII char (dark=space, bright=`#`/`@`) → saved as one JS file →
browser plays it. Python + OpenCV.

**Takeaway:** concretely confirms the "**draw anything, even video**" idea — the
display is just a downsampled brightness grid, whatever feeds it.

---

## 4. orbit-cli/animation — ASCII animations (Python)
URL: https://github.com/Orbit-Nix/orbit-cli/tree/main/animation

Files: `orbit.py`, `mini-orbit.py` (spinning orbit), `heart.py`, `mini-heart.py`

---

## 6. ✅ Validated: cube engine + global illumination + CRT (this session)

`cube/` now runs the full pipeline and the shading + CRT read clearly.

**Lighting — global illumination, not one hardcoded direction:**
- `AMBIENT = 0.30` — GI floor so no face is pure black.
- **Point light** `LIGHT = (5,4,2)` (front-right-top, world space).
- **Distance falloff** `1/(1 + 0.05·d²)` — this is the "shade fall off" gradient.
- **Intensity** `×2.6`, clamped to 1 — pushes the bright faces up into the dense
  block glyphs (without it the top of the ramp never fires).

```
bright = AMBIENT + (1-AMBIENT) · min(1, diffuse · attenuation · INTENSITY)
```

**Ramp:** `" .:-=+*#░▒▓█"` (12 levels, ends in dense block glyphs — kciter's look).

**CRT overlay (subtle curvature + curved bezel — the "bent black bars"):**
- **Phosphor base** `+16` green — *key finding:* on a pure-black background the
  curvature/vignette/scanlines are invisible; a faint tube glow gives them
  something to act on.
- **Curvature `0.06`** — kept *subtle*. Higher bends the cube's straight edges
  (fish-eye) instead of reading as "convex". Content only hints at convexity.
- **Bezel** (superellipse `n=2.4`, `inset=0.03`) — the curved black frame. The
  convex tube's corners curve away; the bezel sells the CRT while content stays
  mostly flat.
- **Screen glow** (radial, `center 60` / `edge 30`) — global illumination so the
  screen stays lit green against the pure-black bezel. vignette `0.30` · scanlines
  `0.42`/3px · phosphor bloom `0.55`.

**Projection gotcha:** glyphs are 9×16 px (taller than wide), so a projection that
treats x/y symmetrically stretches cubes tall. Fix: scale y by `CELL_W/CELL_H`
(9/16) in `project()`. Cube now renders square (414×416 px).

Carry into the Dart port: this lighting formula, the y-aspect correction in
projection, the radial screen glow (vs the black bezel), the CRT order
(screen glow → subtle curvature → vignette → scanlines → bloom → bezel),
and the block ramp.

(spinning heart). Math-driven terminal animations (parametric shapes + rotation).

**Takeaway:** reference implementations for spinning parametric shapes in ~pure math.

---

## 5. Reddit — framer component (ASCII formatting)
URL: https://www.reddit.com/r/ASCII/comments/1u7lf6z/... — **fetch blocked (403)**,
only the title returned. TODO: pull later via a different route.

---

## Synthesis (what to adopt)

1. **Full 3D pipeline** (kciter) — world/view/projection matrices + triangle
   rasterization + **z-buffer**. Portable to Dart.
2. **Sub-cell block shading** (fetch) — `░▒▓█`/sextants give 2×/3× resolution per
   cell. Big fidelity win at our low grid resolution.
3. **Blinn-Phong + heightmap normals** (fetch) — solid, cheap lighting.
4. **Heightmap-from-art** (fetch) — turn 2D pixel art / logos into 3D relief.
5. **Buffer-as-truth** (VidASCII + our prototype) — anything (vector, video, 3D)
   feeds the brightness buffer; the display only samples it.

## Open questions

- Which ramp for the Fallout-green look? (`.,-~:;=!*#$@` vs block chars)
- Sub-cell shading in Flutter: block glyphs vs. a real 2×/3× sub-pixel grid?
- 3D pipeline now (full matrices) or 2D vector first?
