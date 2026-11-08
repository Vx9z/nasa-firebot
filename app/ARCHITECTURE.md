# 🏛️ App Architecture — Foundation Plan

> The app is **not** a list of screens. It's a **graph**: nodes (lessons, notes) connected by
> edges (prerequisites, links). One engine renders and animates *every* view — the curriculum
> constellations **and** the user's own note graph. This doc is the contract before we build.

---

## 1. Core abstraction — the Graph

Everything reduces to a graph. The curriculum's 7 modules / 35 lessons **are** a graph; the
user's Obsidian-style notes **are** a graph. One model, one engine.

```
Node   { id, title, content?, type, position(x,y), pinned(bool), meta }
Edge   { source, target, type }
Graph  { nodes, edges }
```

- `pinned = true` → fixed position (e.g. a real constellation star).
- `pinned = false` → floats via physics (user-created nodes).
- `type` distinguishes `lesson`, `note`, `module`, `concept`, etc.

The curriculum is just a **pre-seeded graph** (constellation stars pinned to their real shapes);
the note system is a **user-grown graph** (free physics).

### The three representation modes (separate, NOT blended)
One graph, three ways to view it — the user switches between modes:

- **Magnetic** — Obsidian-like, force-directed. Free nodes attract along edges and repel each
  other, settling into a living network (the "magnetic" pull/push feel).
- **Constellation** — fixed layout. Stars are *pinned* to their real constellation shapes
  (Phoenix, Ara, Boötes, …); little-to-no free motion (maybe a subtle "alive" jiggle).
  The curriculum's default view.
- **Atom / Molecule** — radial/orbital. A central note is the **nucleus**; linked notes revolve
  on successive rings like electrons. Best for "this note + everything linked to it."

The physics engine below drives all three: free physics (Magnetic), pinned (Constellation),
orbital/radial (Atom). One engine, three strategies.

## 2. Physics engine — force-directed graph ("gravity + strings + repulsion")

The heart. A classic spring-embedder, run every frame on a ticker:

```
for each edge (source→target):
    d = distance(source, target)
    F_spring = k * (d − restLength)      // "string" pulls connected nodes to rest length
    apply along the edge direction

for each node pair (a, b):
    d = distance(a, b)
    F_repel = −c / d²                    // nodes push each other apart
    apply along the a→b direction

optional center gravity:
    F_center = −g * position             // gentle pull toward origin

integrate (Verlet or semi-implicit Euler):
    velocity += force/mass * dt
    velocity *= damping                  // so it settles
    position += velocity * dt

pinned nodes: skip their own integration (position locked), but they still exert
forces on free nodes.
```

- Tuned constants: `k` (spring stiffness), `restLength`, `c` (repulsion), `g` (gravity), `damping`.
- This is exactly "nodes pulling from strings and repelling each other."
- Abstracted behind an interface so constellations (pinned) and free notes share it.

## 3. Rendering — one painter, many layers

`CustomPainter` + a single `Ticker` (60 fps), drawn back-to-front:

```
Layer 0  deep-space gradient (dark navy → near-black)   ← parallax (slowest)
Layer 1  starfield (procedural dots)                    ← parallax
Layer 2  nebula glow (soft radial gradients)            ← parallax
Layer 3  EDGES  (curved lines, glow on hover)
Layer 4  NODES  (circles; label on hover/tap)
Layer 5  overlay (toolbar, fire-level flame, HUD)       ← no parallax
```

- **Pan/zoom** via gesture handling (or `InteractiveViewer`), with layers 0–2 moving slower
  than 3–4 → depth illusion.
- **Fire-level** is a custom-painted animated flame in the overlay (color encodes progress:
  blue → yellow → white).

## 4. Note-taking & the user graph (Obsidian-like)

- Notes are **markdown (`.md`)** with proper formatting — headings, bold/italic, lists, code —
  plus `[[wikilinks]]`, where each link becomes an edge in the graph.
- The note **editor** must render markdown correctly (live formatting preview) while editing.
- The note graph renders with the **same** force-directed engine (free nodes).
- User can add nodes, link them, and watch the graph re-layout live.

## 5. Theming & design tokens

- **Dark space theme** (the app *is* fire in space).
- Central design tokens: palette, type scale, spacing, elevation — referenced everywhere
  (no hardcoded colors).
- Accent = the **fire scale** (blue → orange → white) reused by the flame animation and progress.

## 6. State & DI

- State management drives the graph + navigation + notes + progress.
- **Decision needed:** `riverpod` (modern, compile-safe, testable — more setup) vs
  `provider` + `ChangeNotifier` (simpler, less ceremony).

## 7. Persistence (the "state saver")

- Notes, links, progress (fire level), and graph layout must survive restarts.
- **Markdown + JSON index** (settled ✅): notes = `.md` files in a "vault" folder; a JSON file
  holds the graph index (links/edges), node positions, and progress.
- Mechanism: desktop → user-chosen vault folder (Obsidian-style, via `file_selector`);
  mobile → app documents dir (`path_provider`). Writes are plain `dart:io` file I/O.

## 8. AI service (abstracted)

- `AiService { ask(lesson, question) → answer }`
- `OllamaService` (desktop, `localhost:11434`) now; on-device impl for mobile later.
- The UI depends only on the interface, never the concrete service.

---

### The layer cake (bottom → top)

```
Graph model  →  Physics engine  →  Painter/layers  →  Views (constellation / notes / lesson / chat)
     ↑              ↑
  Persistence     State (riverpod/provider)        ←  theming tokens thread through everything
```

### Decisions (settled)
1. State management: **Riverpod** ✅
2. Persistence: **markdown + JSON index** ✅
3. Graph modes: **Magnetic · Constellation · Atom/Molecule** (separate, switchable) ✅
4. (Physics params are just tuning — iterate.)

### Build order (phases)
1. **Phase 1a — Note system (the DATA, build first):** note model + markdown editor (titles,
   bold, lists, code snippets with syntax highlighting) + `[[wikilinks]]` + persistence
   (markdown files + JSON index).
2. **Phase 1b — Graph (the VIEW):** graph model → physics engine → the three modes
   (Magnetic, Constellation, Atom) rendering the notes' links.
3. **Phase 2 — Cosmetics:** layered background (parallax) → theming → fire animation.
