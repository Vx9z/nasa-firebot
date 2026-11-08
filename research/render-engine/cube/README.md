# Cube — modular ASCII 3D render engine

A minimal, modular 3D → ASCII pipeline (kciter.so-style) for a rotating, lit cube,
with a CRT overlay. Each file has one job (separation of concerns for easy debugging):

| File | Job |
|---|---|
| `vec.py` | 3D math — rotation + perspective projection |
| `mesh.py` | the cube — vertices + faces + outward normals |
| `rasterizer.py` | transform → backface cull → Lambert shade → triangle rasterize → ASCII |
| `crt.py` | the CRT overlay — convex curvature, vignette, scanlines |
| `main.py` | the demo loop — rotates the cube, renders frames |

Run:  `python main.py`  →  prints one frame + writes green CRT PNG frames to `frames/`.
