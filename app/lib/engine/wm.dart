import 'dart:ui';

import '../models/graph.dart';
import 'markdown_renderer.dart';

/// What kind of pseudo-terminal a tile is. Each type gets its own renderer,
/// model and command set later — kept separate for modularity.
enum TileType { shell, study, note, notes, chat, lesson, graph, investigations }

/// A clickable link region inside a tile (tile-local coordinates).
class LinkHit {
  final Rect rect;
  final String target; // note://<title>, http(s)://…, or lesson id
  const LinkHit(this.rect, this.target);
}

/// Verbosity levels for the FireBot chat tile (the CRT slider).
const List<String> kVerbosityLabels = ['SHORT', 'MED', 'LONG'];

/// Fraction of the tile width the verbosity slider's clickable track spans
/// (the right portion is the unclickable `[CTRL+L]` hint).
const double kSliderTrackFraction = 0.72;

/// A single tile in the tiling window manager.
class Tile {
  final int id;
  final TileType type;
  String title;
  final List<String> lines;
  final bool editable;
  String input = ''; // mutable draft (chat / note tiles)
  int verbosity = 2; // 0 = short, 1 = medium, 2 = long (chat tiles)
  String raw = ''; // raw markdown (note tiles)
  int mode = 0; // note tiles: 0 = view, 1 = edit; lesson tiles: 0 = browse, 1 = read
  int selection = 0; // notes/lesson browser tiles: highlighted list index
  int cursor = 0; // note edit tiles: character offset into `input`
  List<MdLine> mdLines = []; // rendered markdown (study / note view tiles)
  final Set<String> expanded = {}; // lesson browser: expanded module ids
  String lessonId = ''; // lesson tile: lesson being read ('' = browsing)
  final List<String> compareIds = []; // investigations: ids selected for comparison
  int scroll = 0; // markdown scroll: top-skip (lesson/investigations) or lines-up-from-bottom (chat)
  final List<String> figureUrls = []; // figure image URLs (long answers)
  final List<Image> figureImages = []; // decoded thumbnails
  Graph? graph; // graph tile: nodes + edges (positions mutate each frame)
  final Map<String, Image> images = {}; // decoded inline markdown images (url → image)
  final List<LinkHit> links = []; // link hit-rects, repopulated on each paint

  Tile({
    required this.id,
    required this.type,
    required this.title,
    required this.lines,
    this.editable = false,
  });

  void disposeFigures() {
    for (final img in figureImages) {
      img.dispose();
    }
    figureImages.clear();
    figureUrls.clear();
  }

  void disposeImages() {
    for (final img in images.values) {
      img.dispose();
    }
    images.clear();
  }
}

/// A tile that a command wants to open (id is assigned by the [WindowManager]).
class TileSpec {
  final TileType type;
  final String title;
  final List<String> lines;
  final bool editable;
  final String raw; // raw markdown (note tiles)

  const TileSpec({
    required this.type,
    required this.title,
    this.lines = const [],
    this.editable = false,
    this.raw = '',
  });
}

/// What a command produced: text echoed into the terminal, plus (optionally) a
/// tile to open/focus.
class CommandOutcome {
  final List<String> echo;
  final TileSpec? tile;

  const CommandOutcome(this.echo, {this.tile});
}

/// A tiny tiling window manager (dwm-style master-stack layout).
///
/// Tile 0 is the terminal (always present, the command surface); `/open`,
/// `/note` and `/ask` spawn content tiles beside it. The focused tile is the
/// master (left); the rest stack on the right.
class WindowManager {
  final List<Tile> tiles = [];
  int focused = -1;
  int _nextId = 1;

  /// Resizable layout state (drag the splitters to change these).
  double masterRatio = 0.58; // master (left) width fraction of the non-gap area
  List<double> stackFractions = []; // stack tile height fractions (sum = 1)

  WindowManager() {
    spawnTerminal();
  }

  Tile? get shell => findByType(TileType.shell);

  /// Spawn a fresh terminal (shell) tile — the command surface.
  Tile spawnTerminal() {
    final t = Tile(
      id: _nextId++,
      type: TileType.shell,
      title: 'TERMINAL',
      lines: const [],
      editable: true,
    );
    tiles.add(t);
    focused = t.id;
    return t;
  }

  Tile? get focusedTile {
    for (final t in tiles) {
      if (t.id == focused) return t;
    }
    return null;
  }

  Tile? findByType(TileType type) {
    for (final t in tiles) {
      if (t.type == type) return t;
    }
    return null;
  }

  Tile spawn(TileSpec spec) {
    final t = Tile(
      id: _nextId++,
      type: spec.type,
      title: spec.title,
      lines: List<String>.from(spec.lines), // growable copy — refresh methods mutate it
      editable: spec.editable,
    );
    t.raw = spec.raw;
    if (spec.raw.isNotEmpty) t.mdLines = renderMarkdown(spec.raw);
    tiles.add(t);
    focused = t.id;
    return t;
  }

  /// Focus an existing tile with the same title, or spawn a new one.
  Tile spawnOrFocus(TileSpec spec) {
    for (final t in tiles) {
      if (t.id != 0 && t.title == spec.title) {
        focused = t.id;
        return t;
      }
    }
    return spawn(spec);
  }

  void close(int id) {
    for (final t in tiles) {
      if (t.id == id) {
        t.disposeFigures();
        t.disposeImages();
      }
    }
    tiles.removeWhere((t) => t.id == id);
    if (focused == id) focused = tiles.isEmpty ? -1 : tiles.first.id;
  }

  void focus(int id) {
    if (tiles.any((t) => t.id == id)) focused = id;
  }

  /// Cycle focus to the next (dir=+1) or previous (dir=-1) tile.
  void focusNext(int dir) {
    if (tiles.isEmpty) return;
    final i = tiles.indexWhere((t) => t.id == focused);
    final n = i < 0 ? 0 : (i + dir + tiles.length) % tiles.length;
    focused = tiles[n].id;
  }

  void closeAll() {
    for (final t in tiles) {
      t.disposeFigures();
      t.disposeImages();
    }
    tiles.clear();
    focused = -1;
  }

  /// Master-stack layout: the focused tile is the master (left `masterRatio`),
  /// the rest stack vertically on the right. A margin pads the screen edge and
  /// a gap separates the tiles. Returns tile id → screen rect.
  Map<int, Rect> layout(Size size, {double? margin, double? gap}) {
    final out = <int, Rect>{};
    if (tiles.isEmpty) return out;
    final m = margin ?? size.shortestSide * 0.03;
    final g = gap ?? size.shortestSide * 0.012;
    final area = Rect.fromLTRB(m, m, size.width - m, size.height - m);
    if (tiles.length == 1) {
      out[tiles.first.id] = area;
      return out;
    }
    final master = focusedTile ?? tiles.first;
    final others = [for (final t in tiles) if (t.id != master.id) t];
    final ratio = masterRatio.clamp(0.2, 0.85).toDouble();
    final mw = (area.width - g) * ratio;
    final sw = area.width - mw - g;
    out[master.id] = Rect.fromLTWH(area.left, area.top, mw, area.height);
    final n = others.length;
    if (stackFractions.length != n) {
      stackFractions
        ..clear()
        ..addAll(List<double>.filled(n, 1.0 / n));
    }
    var y = area.top;
    for (var i = 0; i < n; i++) {
      final f = stackFractions[i].clamp(0.05, 1.0).toDouble();
      final sh = (area.height - g * (n - 1)) * f;
      out[others[i].id] = Rect.fromLTWH(area.left + mw + g, y, sw, sh);
      y += sh + g;
    }
    return out;
  }
}
