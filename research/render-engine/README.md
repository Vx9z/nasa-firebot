# 🔬 Render Engine Research — Vector → ASCII

> A separate research area for the "ASCII solar systems" technique (Fallout-green UI).
> Goal: understand the render pipeline, then port it to our Dart `PixelBuffer` engine.

## The technique (two layers)

From the Reddit post ("ASCII solar systems / menus"):

1. **Hidden monochrome vector layer** — generates the geometry (solar system shapes,
   rotating spaceships) as *grayscale*, invisible to the user.
2. **Display layer = ASCII grid** — every character has a grid coordinate. The code walks
   each cell, samples the brightness of the hidden layer *underneath* it:
   - empty → render a **space**
   - occupied → render an ASCII char **chosen by brightness**.

> So "vector geometry → grayscale raster → per-cell brightness → ASCII character."

This is exactly the classic **ASCII-art-from-raster** pipeline (`libcaca`, `chafa`, `jp2a`,
`ffmpeg`/`video2ascii`). Because the display is just a downsampled brightness grid, you can
feed it **anything** — vector shapes, or a video frame — which is the "draw anything / video"
idea.

---

## The pipeline

```
vector geometry ──▶ grayscale buffer ──▶ sample per cell ──▶ quantize ──▶ ASCII char
  (lines/circles/     (fixed W×H,          (area-average      (brightness →   (monospace,
   polygons)           supersampled)        the area under      ramp index)     green-on-black)
                                            each char)
```

## 1. Rasterization (vector → buffer)

Draw primitives into a grayscale buffer (each "pixel" = brightness 0–255).

| Primitive | Algorithm | Notes |
|---|---|---|
| Line | **Bresenham** | integer-only, no float |
| Circle | **Midpoint circle** | integer-only |
| Polygon fill | **Scanline fill** (even-odd rule) | for ship/planet silhouettes |
| Anti-aliasing | **Supersampling** (render N×, area-average down) | smooths the ASCII edges |

Bresenham (sketch):
```
dx, dy = x2-x1, y2-y1
err = dx - dy
loop: plot(x,y); e2 = 2*err; if e2 > -dy { err -= dy; x += sx } if e2 < dx { err += dx; y += sy }
```

## 2. Sampling (per cell)

Each ASCII cell = one output pixel of the buffer. The correct "brightness underneath" is an
**area average** of the supersampled buffer under that cell (Pillow: `resize(..., BOX)`),
not a single point sample.

## 3. Quantization (brightness → char)

`index = brightness * (len(ramp)-1) / 255` → `ramp[index]`. Denser glyphs = brighter.

Classic ramps (dimmer → brighter):
- `" .,:;+=*#%@"` (short)
- `" .:-=+*#%@"`
- The 70-char ramp (Paul Bourke):
  `$@B%8&WM#*oahkbdpqwmZO0QLCJUYXzcvunxrjft/\|()1{}[]?-_+~<>i!lI;:,"^`'. `

## 4. Display (Fallout-green)

- Monospace font (VT323 / IBM VGA / Consolas), **green `#00FF00` on black**.
- Optional juice: scanlines, phosphor glow, slight chromatic aberration, dithering.

---

## Performance

The cost is `O(W×H)` cells per frame — **independent of the physical screen resolution**
(render into a fixed grid, scale up with nearest-neighbor). This is why the terminal demos
(`cmatrix`, the rotating donut, `pipes.sh`) are so light, and why our engine will be too.

---

## Mapping to our Dart engine

| Research concept | Dart equivalent |
|---|---|
| Grayscale buffer | `PixelBuffer` (`Uint8List`, fixed W×H) |
| Bresenham / circle / scanline | pure Dart functions |
| Brightness → ramp | palette-index lookup |
| Display | `CustomPainter`, nearest-neighbor upscale |

---

## References

- Reddit post: <https://www.reddit.com/r/IndieDev/comments/1vy6wno/ascii_solar_systems_menus/>
- aioobe's rotating ASCII donut (`donut.c`) — the canonical tiny 3D→ASCII example
- `libcaca` / `chafa` / `jp2a` — production ASCII renderers
- Paul Bourke's 70-character luminance ramp
- `video2ascii` / `ffmpeg -pix_fmt` — the "video" extension of the same idea
