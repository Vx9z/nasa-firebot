# 📘 Processes & Developer Handbook

> A readable map of how this app is built + tested, so you're never in the dark.
> Covers the core algorithm, the testing workflow, the structure, the libraries, and Flutter basics.

---

## 1. The graph physics algorithm (force-directed graph)

### The idea (from first principles)
We have notes (nodes) linked by `[[wikilinks]]` (edges). We want linked notes near each other,
readable and uncluttered. The classic trick: treat each node as a particle obeying a few
simple forces, simulate over time, and they **settle into a natural layout by themselves**.

### The forces
1. **Repulsion** — every pair pushes apart so nodes don't pile up:
   `F = repulsion / d²` (strong when close, weak when far)
2. **Springs ("threads")** — each edge pulls its two nodes toward a rest length:
   `F = elasticity × (d − restLength)` (pull in if stretched, push out if compressed)
3. **Boundary ("the box")** — soft walls push nodes back inside the view:
   `x < 0 → push right · x > width → push left · (same for y)`

### The motion (smooth accel/decel)
Every frame: sum forces → update velocity → damp it → move.
```
velocity = (velocity + force × dt) × damping
position = position + velocity × dt
```
`damping` (< 1) bleeds speed each frame → the graph **accelerates when shoved, then
decelerates into a calm settle** instead of jittering forever.

### The knobs (what the sliders control)
| Param | Meaning | Control |
|-------|---------|---------|
| `repulsion` | how hard nodes push apart | Repulsion slider |
| `elasticity` | how stiff the threads are | Elasticity slider |
| `restLength` | target thread length | (fixed) |
| `damping` | settle speed | (fixed) |

**Where it lives:** `app/lib/services/graph_physics.dart` (pure Dart, no UI) — tested in
`app/test/graph_physics_test.dart`.

---

## 2. How I test & deploy (the workflow)

Every change follows one loop:

1. **Write/edit** the Dart files.
2. **`flutter analyze`** — static check: typos, bad types, missing imports. → expect *"No issues found!"*
3. **`flutter test`** — runs unit + widget tests. → expect *"All tests passed!"*
4. **`flutter run -d <device>`** — live preview:
   ```
   flutter run -d edge                        # web (Edge)
   flutter run -d web-server --web-port 8081  # serve → open in Brave
   flutter run -d windows                     # native desktop (needs VS C++ workload)
   ```
5. **`flutter pub add <name>`** — add a new dependency.

**Why both analyze *and* test?** `analyze` = fast "does it compile?" sanity check. `test` =
proves the *logic* (does the physics settle? does the app render?). I run both after every
change before calling it done.

---

## 3. Project structure (MVC)

```
app/lib/
├── main.dart           entry point → FireSafetyApp
├── models/    (M)      data: Note, Lesson, Module, GraphNode, GraphEdge
├── services/           engines + data: VaultService (notes), GraphPhysics (physics)
├── controllers/ (C)    state: VaultController (tabs + navigation)
└── views/     (V)      UI: HomeView, RootView, NoteEditorView, GraphView
```

**Data flow:** `Note` (markdown) → `VaultService` holds them → `VaultController` manages
tabs/nav → `Views` render. The `Graph` is **derived** from notes (`VaultService.toGraph()`),
never stored separately — one graph, many views (directory / magnetic / constellation / atom).

---

## 4. Libraries

| Library | Purpose |
|---------|---------|
| `flutter_markdown` | renders markdown → widgets (note preview) |
| `flutter_test` | unit + widget tests |
| *(planned)* | `flutter_highlight` (code syntax) · `path_provider`/`file_selector` (file I/O) · `flutter_riverpod` (state) |

---

## 5. Flutter in a nutshell

- **Widget** — everything is a widget (button, text, screen). Compose them like LEGO.
- **StatelessWidget vs StatefulWidget** — stateless = no memory; stateful = holds state,
  rebuilds via `setState(() { … })`.
- **`setState`** — marks the widget dirty → Flutter re-runs `build()`. That's how UI updates.
- **`ChangeNotifier` + `ListenableBuilder`** — a controller notifies; the builder rebuilds.
  (Our tab bar / nav use this.)
- **`Ticker`** — a 60-fps per-frame callback. Drives the physics: each tick → `step()` → `setState()`.
- **`CustomPainter`** — low-level canvas drawing (the graph's circles + lines).

---

## 6. Cheat sheet

| Task | Command |
|------|---------|
| Add a package | `flutter pub add <name>` |
| Compile check | `flutter analyze` |
| Run tests | `flutter test` |
| Preview (web) | `flutter run -d edge` |
| Preview (native) | `flutter run -d windows` |
| List devices | `flutter devices` |
