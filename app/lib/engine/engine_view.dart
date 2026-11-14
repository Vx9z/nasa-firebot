import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'accelerator.dart';
import 'markdown_renderer.dart';
import 'pointer.dart';
import 'scene_painter.dart';
import 'settings.dart';
import 'sonar_painter.dart';
import 'starfield.dart';
import 'terminal.dart';
import 'terminal_commands.dart';
import 'themes.dart';
import 'wm.dart';

import '../controllers/curriculum_controller.dart';
import '../controllers/investigations_controller.dart';
import '../controllers/vault_controller.dart';
import '../models/investigation.dart';
import '../models/lesson.dart';
import '../models/note.dart';
import '../services/ai_service.dart';
import '../services/graph_physics.dart';

/// The whole app: starfield + CRT + terminal text, with the sonar pointer.
class EngineView extends StatefulWidget {
  final int themeIndex;
  final Future<CommandOutcome> Function(String command)? onCommand;
  final void Function(int index)? onThemeChanged;

  const EngineView({
    super.key,
    this.themeIndex = 0,
    this.onCommand,
    this.onThemeChanged,
  });

  @override
  State<EngineView> createState() => _EngineViewState();
}

/// One row in the lesson browser: a module header or a lesson.
class _LessonEntry {
  final bool isModule;
  final String id;
  final String label;
  const _LessonEntry(this.isModule, this.id, this.label);
}

class _EngineViewState extends State<EngineView>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final EngineSettings settings = EngineSettings();
  final Starfield starfield = Starfield();
  final Terminal terminal = Terminal(startupScript);
  final Sonar sonar = Sonar();
  final WindowManager wm = WindowManager();
  final AiService _ai = AiService();
  double _verbHintUntil = 0; // verbosity slider stays visible until this time
  bool _verbHover = false; // mouse over the verbosity slider
  double _termHintUntil = 0; // "\\ for terminal" hint stays visible until this time
  String _selector = ''; // 'theme' | 'transparency' | '' (which selector is open)
  double _selectorUntil = 0; // selector stays visible until this time
  double _transparency = 0; // animated glass level (0 = clear, 1 = frosted)
  double _transparencyTarget = 0;
  final KeyAccelerator _accel = KeyAccelerator();
  final FocusNode _focus = FocusNode();
  // Mobile (touch) support: a hidden field that summons the soft keyboard, and
  // touch-drag scroll state. `_touch` flips true on the first touch pointer.
  final FocusNode _mobileFocus = FocusNode();
  final TextEditingController _mobileCtl = TextEditingController();
  bool _touch = false;
  int _scrollDragId = -1;
  double _scrollDragLastY = 0;
  double _scrollAccum = 0;
  GraphPhysics? _graphPhysics; // gravity-graph simulation (graph tile)
  int _dragMode = 0; // 0 none · 1 master splitter · 2.. = stack splitter index+2
  int _dragStack = -1; // stack splitter index being dragged
  double _dragTop = 0; // top of the two tiles' span being resized
  double _dragBottom = 0; // bottom of the two tiles' span
  double _dragFrac = 0; // sum of the two fractions being split
  String? _dragNodeId; // graph node being dragged (pinned while dragging)
  ui.FragmentShader? _shader;
  ui.Image? _starfieldImage;
  ui.FragmentShader? _glassShader; // Kawase blur for the tile glass
  ui.Image? _glassImage; // Kawase-blurred starfield backdrop
  bool _rendering = false;
  Size _size = Size.zero;
  double _t = 0;
  double _last = 0;
  double _lastRender = -1;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    _loadShader();
    _loadGlassShader();
  }

  Future<void> _loadShader() async {
    try {
      final program = await ui.FragmentProgram.fromAsset('shaders/crt.frag');
      if (mounted) {
        setState(() => _shader = program.fragmentShader());
        _lastRender = -1; // apply the CRT as soon as the shader compiles
        _renderStarfield();
      }
    } catch (_) {
      // Shader unavailable — the painter falls back to flat stars.
    }
  }

  Future<void> _loadGlassShader() async {
    try {
      final program = await ui.FragmentProgram.fromAsset('shaders/kawase.frag');
      if (mounted) setState(() => _glassShader = program.fragmentShader());
    } catch (_) {
      // Kawase unavailable — the glass falls back to a flat tint.
    }
  }

  void _onTick(Duration elapsed) {
    final us = elapsed.inMicroseconds.toDouble();
    final dt = _last == 0 ? 0.0 : (us - _last) / 1e6;
    _last = us;
    setState(() {
      _t += dt;
      terminal.step(dt);
      _stepGraph(dt);
      // Smoothly ease the transparency toward its target (exponential glide).
      final k = (dt * 12).clamp(0.0, 1.0);
      _transparency += (_transparencyTarget - _transparency) * k;
      if ((_transparencyTarget - _transparency).abs() < 0.001) {
        _transparency = _transparencyTarget;
      }
    });
    // The starfield only twinkles slowly, so re-render it at ~7 Hz.
    if (_t - _lastRender >= 0.15) {
      _lastRender = _t;
      _renderStarfield();
    }
  }

  Future<void> _renderStarfield() async {
    if (_rendering || _size.isEmpty) return;
    _rendering = true;
    try {
      final theme = themeByIndex(widget.themeIndex);
      final w = _size.width.toInt().clamp(1, 1 << 14);
      final h = _size.height.toInt().clamp(1, 1 << 14);
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      drawStarfieldChars(c, _size, starfield, theme, settings, _t);
      final img = await rec.endRecording().toImage(w, h);
      if (mounted) {
        setState(() {
          _starfieldImage?.dispose();
          _starfieldImage = img;
        });
        _renderGlass();
      }
    } catch (_) {
      // Offscreen render failed — keep the last frame.
    } finally {
      _rendering = false;
    }
  }

  Future<void> _renderGlass() async {
    final shader = _glassShader;
    final src = _starfieldImage;
    if (shader == null || src == null || _size.isEmpty) return;
    try {
      final w = _size.width.toInt().clamp(1, 1 << 14);
      final h = _size.height.toInt().clamp(1, 1 << 14);
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      shader.setImageSampler(0, src);
      shader.setFloat(0, _size.width);
      shader.setFloat(1, _size.height);
      shader.setFloat(2, 3.0); // Kawase radius (pixels)
      c.drawRect(
        Rect.fromLTWH(0, 0, _size.width, _size.height),
        Paint()..shader = shader,
      );
      final img = await rec.endRecording().toImage(w, h);
      if (mounted) {
        setState(() {
          _glassImage?.dispose();
          _glassImage = img;
        });
      }
    } catch (_) {
      // Kawase pass failed — the glass falls back to a flat tint.
    }
  }

  @override
  void didUpdateWidget(covariant EngineView old) {
    super.didUpdateWidget(old);
    if (old.themeIndex != widget.themeIndex) {
      _lastRender = -1; // force an immediate re-render with the new theme
      _renderStarfield();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _focus.dispose();
    _mobileCtl.dispose();
    _mobileFocus.dispose();
    _shader?.dispose();
    _starfieldImage?.dispose();
    _glassShader?.dispose();
    _glassImage?.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final ft = wm.focusedTile;
    // Esc closes the focused tile (or exits note edit / cancels note create).
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
      if (ft != null) {
        if (ft.type == TileType.note && ft.mode == 1) {
          // Esc while editing: save, then close the tile.
          setState(() {
            _saveNote(ft);
            wm.close(ft.id);
            if (wm.tiles.isEmpty) _termHintUntil = _t + 4;
          });
        } else if (ft.type == TileType.notes && ft.mode == 1) {
          setState(() => ft.mode = 0); // cancel note creation
        } else if (ft.type == TileType.lesson && ft.mode == 1) {
          // Esc while reading a lesson: back to the browser list.
          setState(() {
            ft.mode = 0;
            ft.scroll = 0;
            ft.title = 'LESSONS';
            _refreshLessonBrowser(ft);
          });
        } else if (ft.type == TileType.investigations && ft.mode != 0) {
          // Esc from detail / compare-select / compare view: back to the list.
          setState(() {
            ft.mode = 0;
            ft.scroll = 0;
            ft.compareIds.clear();
            ft.title = 'INVESTIGATIONS';
            _refreshInvestigationsList(ft);
          });
        } else {
          setState(() {
            wm.close(wm.focused);
            if (wm.tiles.isEmpty) _termHintUntil = _t + 4;
          });
        }
      }
      return KeyEventResult.handled;
    }
    // Focus switching: Ctrl+→ next tile, Ctrl+← previous (browser-safe hotkey).
    if (event is KeyDownEvent) {
      final key = event.logicalKey;
      if (HardwareKeyboard.instance.isControlPressed) {
        if (key == LogicalKeyboardKey.arrowRight) {
          setState(() => wm.focusNext(1));
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowLeft) {
          setState(() => wm.focusNext(-1));
          return KeyEventResult.handled;
        }
      }
    }
    if (ft == null) {
      return _emptyKey(event); // no tiles: `\` spawns a terminal
    }
    if (ft.type == TileType.chat) {
      return _chatKey(ft, event);
    }
    if (ft.type == TileType.note) {
      return _noteKey(ft, event);
    }
    if (ft.type == TileType.notes) {
      return _notesKey(ft, event);
    }
    if (ft.type == TileType.lesson) {
      return _lessonKey(ft, event);
    }
    if (ft.type == TileType.investigations) {
      return _investigationsKey(ft, event);
    }
    if (ft.type == TileType.shell) {
      return _terminalKey(event);
    }
    return KeyEventResult.handled; // study / graph: read-only
  }

  /// Keys for the shell terminal.
  KeyEventResult _terminalKey(KeyEvent event) {
    final c = event.character;
    final ctrl = HardwareKeyboard.instance.isControlPressed;
    final key = event.logicalKey;
    final isDown = event is KeyDownEvent;
    // Arrow keys drive the active selector (theme ←/→, glass ↑/↓) — avoids
    // browser-reserved Ctrl+L / Ctrl+K.
    if (_selector == 'theme' && _t < _selectorUntil && isDown) {
      if (key == LogicalKeyboardKey.arrowLeft) {
        _cycleTheme(-1);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowRight) {
        _cycleTheme(1);
        return KeyEventResult.handled;
      }
    }
    if (_selector == 'transparency' && _t < _selectorUntil) {
      if (key == LogicalKeyboardKey.arrowUp) {
        _nudgeTransparency(event, 1);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowDown) {
        _nudgeTransparency(event, -1);
        return KeyEventResult.handled;
      }
    }
    if (ctrl && key == LogicalKeyboardKey.keyL) {
      if (_selector == 'transparency' && _t < _selectorUntil) {
        _nudgeTransparency(event, 1); // repeats accelerate
      }
      return KeyEventResult.handled;
    }
    if (ctrl && key == LogicalKeyboardKey.keyK) {
      if (_selector == 'transparency' && _t < _selectorUntil) {
        _nudgeTransparency(event, -1);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.backspace) {
      setState(() {
        if (ctrl) {
          terminal.deleteWord();
        } else {
          terminal.backspace();
        }
      });
    } else if (key == LogicalKeyboardKey.enter && isDown) {
      final cmd = terminal.enter();
      setState(() {
        if (cmd != null) terminal.history.add('…');
      });
      if (cmd != null) _run(cmd);
    } else if (key == LogicalKeyboardKey.keyU && ctrl && isDown) {
      setState(terminal.clearLine);
    } else if (c != null && c.length == 1 && c.codeUnitAt(0) >= 32) {
      setState(() => terminal.key(c));
    }
    return KeyEventResult.handled;
  }

  /// Keys for the FireBot chat tile (its own text box + Ctrl+L/K verbosity).
  KeyEventResult _chatKey(Tile tile, KeyEvent event) {
    final c = event.character;
    final key = event.logicalKey;
    final ctrl = HardwareKeyboard.instance.isControlPressed;
    final isDown = event is KeyDownEvent;
    if (key == LogicalKeyboardKey.keyL && ctrl && isDown) {
      setState(() {
        tile.verbosity = (tile.verbosity + 1) % 3;
        _verbHintUntil = _t + 4; // reveal the updated slider
      });
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyK && ctrl && isDown) {
      setState(() {
        tile.verbosity = (tile.verbosity + 2) % 3; // previous
        _verbHintUntil = _t + 4;
      });
      return KeyEventResult.handled;
    }
    // Scroll the reply history (tile.scroll = lines scrolled up from bottom).
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      if (key == LogicalKeyboardKey.arrowUp) {
        setState(() {
          if (tile.scroll < tile.mdLines.length) tile.scroll++;
        });
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowDown) {
        setState(() {
          if (tile.scroll > 0) tile.scroll--;
        });
        return KeyEventResult.handled;
      }
    }
    if (key == LogicalKeyboardKey.enter && isDown) {
      final msg = tile.input.trim();
      setState(() => tile.input = '');
      if (msg.isNotEmpty) _sendChat(tile, msg);
    } else if (key == LogicalKeyboardKey.backspace) {
      setState(() {
        if (tile.input.isNotEmpty) {
          tile.input = tile.input.substring(0, tile.input.length - 1);
        }
      });
    } else if (c != null && c.length == 1 && c.codeUnitAt(0) >= 32) {
      setState(() => tile.input += c);
    }
    return KeyEventResult.handled;
  }

  /// Mouse-wheel scroll for scrollable tiles (chat + reading views).
  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final pos = event.localPosition;
    final rects = wm.layout(_size);
    for (final e in rects.entries) {
      if (!e.value.contains(pos)) continue;
      final tile = wm.tiles.firstWhere((t) => t.id == e.key);
      _wheelScroll(tile, event.scrollDelta.dy);
      break;
    }
  }

  void _wheelScroll(Tile tile, double dy) {
    final down = dy > 0;
    if (tile.type == TileType.chat) {
      setState(() {
        if (down) {
          if (tile.scroll > 0) tile.scroll--;
        } else if (tile.scroll < tile.mdLines.length) {
          tile.scroll++;
        }
      });
    } else if ((tile.type == TileType.lesson || tile.type == TileType.investigations) &&
        tile.mode == 1) {
      setState(() {
        if (down) {
          final max = tile.mdLines.length > 1 ? tile.mdLines.length - 1 : 0;
          if (tile.scroll < max) tile.scroll++;
        } else if (tile.scroll > 0) {
          tile.scroll--;
        }
      });
    }
  }

  /// Keys for a note tile: F2 toggles view/edit; edit mode is a mini editor.
  KeyEventResult _noteKey(Tile tile, KeyEvent event) {
    final c = event.character;
    final key = event.logicalKey;
    final isDown = event is KeyDownEvent;
    if (key == LogicalKeyboardKey.f2 && isDown) {
      setState(() {
        if (tile.mode == 1) {
          _saveNote(tile); // auto-save on exit
        } else {
          tile.input = tile.raw; // enter edit mode with the raw markdown
          tile.cursor = tile.input.length;
        }
        tile.mode = (tile.mode + 1) % 2;
      });
      return KeyEventResult.handled;
    }
    if (tile.mode != 1) return KeyEventResult.handled; // view mode: read-only

    setState(() {
      if (key == LogicalKeyboardKey.arrowLeft) {
        if (tile.cursor > 0) tile.cursor--;
      } else if (key == LogicalKeyboardKey.arrowRight) {
        if (tile.cursor < tile.input.length) tile.cursor++;
      } else if (key == LogicalKeyboardKey.arrowUp) {
        tile.cursor = _cursorUp(tile.input, tile.cursor);
      } else if (key == LogicalKeyboardKey.arrowDown) {
        tile.cursor = _cursorDown(tile.input, tile.cursor);
      } else if (key == LogicalKeyboardKey.home) {
        tile.cursor = _lineStart(tile.input, tile.cursor);
      } else if (key == LogicalKeyboardKey.end) {
        tile.cursor = _lineEnd(tile.input, tile.cursor);
      } else if (key == LogicalKeyboardKey.enter && isDown) {
        tile.input =
            '${tile.input.substring(0, tile.cursor)}\n${tile.input.substring(tile.cursor)}';
        tile.cursor++;
      } else if (key == LogicalKeyboardKey.backspace) {
        if (tile.cursor > 0) {
          tile.input =
              '${tile.input.substring(0, tile.cursor - 1)}${tile.input.substring(tile.cursor)}';
          tile.cursor--;
        }
      } else if (key == LogicalKeyboardKey.delete) {
        if (tile.cursor < tile.input.length) {
          tile.input =
              '${tile.input.substring(0, tile.cursor)}${tile.input.substring(tile.cursor + 1)}';
        }
      } else if (c != null && c.length == 1 && c.codeUnitAt(0) >= 32) {
        tile.input =
            '${tile.input.substring(0, tile.cursor)}$c${tile.input.substring(tile.cursor)}';
        tile.cursor++;
      }
    });
    return KeyEventResult.handled;
  }

  int _lineStart(String s, int c) {
    final i = s.lastIndexOf('\n', c - 1);
    return i < 0 ? 0 : i + 1;
  }

  int _lineEnd(String s, int c) {
    final i = s.indexOf('\n', c);
    return i < 0 ? s.length : i;
  }

  int _cursorUp(String s, int c) {
    final ls = _lineStart(s, c);
    final col = c - ls;
    if (ls == 0) return 0;
    final prevStart = _lineStart(s, ls - 1);
    final prevEnd = ls - 1;
    final target = prevStart + col;
    return target > prevEnd ? prevEnd : target;
  }

  int _cursorDown(String s, int c) {
    final ls = _lineStart(s, c);
    final col = c - ls;
    final le = _lineEnd(s, c);
    if (le >= s.length) return s.length;
    final nextStart = le + 1;
    final nextEnd = _lineEnd(s, nextStart);
    final target = nextStart + col;
    return target > nextEnd ? nextEnd : target;
  }

  /// Persist the note's edited markdown and refresh its rendered lines.
  void _saveNote(Tile tile) {
    final title = tile.title.replaceFirst('NOTE · ', '');
    tile.raw = tile.input;
    VaultController.instance.saveNote(title, tile.input);
    final note = VaultController.instance.vault.get(title);
    setState(() {
      tile.lines
        ..clear()
        ..addAll(note == null
            ? const <String>[]
            : TerminalCommands.markdownToLines(note.content));
      tile.mdLines = renderMarkdown(tile.input);
    });
    _loadMarkdownImages(tile);
  }

  /// Open (or focus) the notes browser and refresh its list from the vault.
  void _openNotes() {
    final tile = wm.findByType(TileType.notes) ??
        wm.spawn(TileSpec(type: TileType.notes, title: 'NOTES', lines: const []));
    _refreshNotesList(tile);
    wm.focus(tile.id);
    setState(() {});
  }

  void _refreshNotesList(Tile tile) {
    final titles = VaultController.instance.vault.allTitles;
    tile.lines
      ..clear()
      ..addAll(
          titles.isEmpty ? const ['(no notes — /note <title> to create)'] : titles);
    if (tile.selection >= tile.lines.length) tile.selection = 0;
  }

  /// Refresh the notes-browser tile (if open) after any note is created/edited.
  void _refreshNotesTile() {
    final t = wm.findByType(TileType.notes);
    if (t != null) _refreshNotesList(t);
  }

  /// Open (or focus) a note tile for the given title.
  void _openNote(String title) {
    Tile? existing;
    for (final t in wm.tiles) {
      if (t.type == TileType.note && t.title == 'NOTE · $title') {
        existing = t;
        break;
      }
    }
    if (existing != null) {
      wm.focus(existing.id);
    } else {
      final note = VaultController.instance.vault.get(title);
      final content = note?.content ?? '';
      final t = wm.spawn(TileSpec(
        type: TileType.note,
        title: 'NOTE · $title',
        lines: TerminalCommands.markdownToLines(content),
        editable: true,
        raw: content,
      ));
      _loadMarkdownImages(t);
    }
    setState(() {});
  }

  /// Keys for the notes browser: arrow keys select, Enter opens, N creates.
  KeyEventResult _notesKey(Tile tile, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.handled;
    final key = event.logicalKey;
    final c = event.character;

    // Create mode: type a title, Enter creates (Esc cancels, handled above).
    if (tile.mode == 1) {
      if (key == LogicalKeyboardKey.enter) {
        final title = tile.input.trim();
        setState(() {
          tile.input = '';
          tile.mode = 0;
        });
        _createNote(title);
        _refreshNotesList(tile);
      } else if (key == LogicalKeyboardKey.backspace) {
        setState(() {
          if (tile.input.isNotEmpty) {
            tile.input = tile.input.substring(0, tile.input.length - 1);
          }
        });
      } else if (c != null && c.length == 1 && c.codeUnitAt(0) >= 32) {
        setState(() => tile.input += c);
      }
      return KeyEventResult.handled;
    }

    final titles = VaultController.instance.vault.allTitles;
    if (titles.isEmpty) {
      if (key == LogicalKeyboardKey.keyN || key == LogicalKeyboardKey.enter) {
        setState(() {
          tile.mode = 1;
          tile.input = '';
        });
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      setState(() {
        if (tile.selection > 0) tile.selection--;
      });
    } else if (key == LogicalKeyboardKey.arrowDown) {
      setState(() {
        if (tile.selection < titles.length - 1) tile.selection++;
      });
    } else if (key == LogicalKeyboardKey.enter) {
      _openNote(titles[tile.selection]);
    } else if (key == LogicalKeyboardKey.keyN) {
      setState(() {
        tile.mode = 1;
        tile.input = '';
      });
    }
    return KeyEventResult.handled;
  }

  /// Create a new note (if missing) and open it.
  void _createNote(String title) {
    if (title.isEmpty) return;
    if (!VaultController.instance.vault.has(title)) {
      VaultController.instance.vault.addNote(Note(title: title, content: ''));
    }
    _openNote(title);
    _refreshNotesTile();
  }

  // ---- Lesson browser / reader (TileType.lesson) ----

  List<_LessonEntry> _lessonEntries(Tile tile) {
    final entries = <_LessonEntry>[];
    for (final m in CurriculumController.instance.modules) {
      final open = tile.expanded.contains(m.id);
      entries.add(_LessonEntry(
        true,
        m.id,
        '${open ? '▾' : '▸'} ${m.id} · ${m.title}',
      ));
      if (open) {
        for (final l in m.lessons) {
          entries.add(_LessonEntry(false, l.id, '   ${l.id}  ${l.title}'));
        }
      }
    }
    return entries;
  }

  void _refreshLessonBrowser(Tile tile) {
    final entries = _lessonEntries(tile);
    tile.lines
      ..clear()
      ..addAll(entries.map((e) => e.label));
    if (tile.selection >= tile.lines.length) tile.selection = 0;
  }

  Future<void> _openLessonBrowser() async {
    await CurriculumController.instance.load();
    final tile = wm.findByType(TileType.lesson) ??
        wm.spawn(TileSpec(type: TileType.lesson, title: 'LESSONS', lines: const []));
    tile.mode = 0;
    tile.scroll = 0;
    tile.title = 'LESSONS';
    _refreshLessonBrowser(tile);
    wm.focus(tile.id);
    setState(() {});
  }

  Future<void> _openLessonIn(Tile tile, String lessonId) async {
    Lesson? lesson;
    for (final m in CurriculumController.instance.modules) {
      for (final l in m.lessons) {
        if (l.id == lessonId) {
          lesson = l;
          break;
        }
      }
    }
    if (lesson == null) return;
    try {
      final md = await CurriculumController.instance.curriculum.loadContent(lesson);
      if (!mounted) return;
      setState(() {
        tile.lessonId = lessonId;
        tile.mode = 1;
        tile.scroll = 0;
        tile.title = 'LESSON · ${lesson!.title}';
        tile.mdLines = renderMarkdown(md);
        tile.raw = md;
      });
      _loadMarkdownImages(tile);
    } catch (_) {
      // lesson content unavailable
    }
  }

  void _lessonStep(Tile tile, int dir) {
    final all = CurriculumController.instance.allLessons;
    final idx = all.indexWhere((l) => l.id == tile.lessonId);
    if (idx < 0) return;
    final n = idx + dir;
    if (n < 0 || n >= all.length) return;
    _openLessonIn(tile, all[n].id);
  }

  String? _parentModuleId(String lessonId) {
    for (final l in CurriculumController.instance.allLessons) {
      if (l.id == lessonId) return l.moduleId;
    }
    return null;
  }

  KeyEventResult _lessonKey(Tile tile, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.handled;
    }
    final key = event.logicalKey;

    if (tile.mode == 1) {
      // Reading a lesson.
      if (key == LogicalKeyboardKey.arrowUp) {
        setState(() {
          if (tile.scroll > 0) tile.scroll--;
        });
      } else if (key == LogicalKeyboardKey.arrowDown) {
        setState(() {
          final max = tile.mdLines.length > 1 ? tile.mdLines.length - 1 : 0;
          if (tile.scroll < max) tile.scroll++;
        });
      } else if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.pageUp) {
        _lessonStep(tile, -1);
      } else if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.pageDown) {
        _lessonStep(tile, 1);
      } else if (key == LogicalKeyboardKey.home) {
        setState(() => tile.scroll = 0);
      }
      return KeyEventResult.handled;
    }

    // Browse mode.
    final entries = _lessonEntries(tile);
    if (entries.isEmpty) return KeyEventResult.handled;
    if (tile.selection >= entries.length) tile.selection = 0;
    if (key == LogicalKeyboardKey.arrowUp) {
      setState(() {
        if (tile.selection > 0) tile.selection--;
      });
    } else if (key == LogicalKeyboardKey.arrowDown) {
      setState(() {
        if (tile.selection < entries.length - 1) tile.selection++;
      });
    } else if (key == LogicalKeyboardKey.arrowRight) {
      final e = entries[tile.selection];
      if (e.isModule) {
        setState(() {
          tile.expanded.add(e.id);
          _refreshLessonBrowser(tile);
        });
      } else {
        _openLessonIn(tile, e.id);
      }
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      final e = entries[tile.selection];
      if (e.isModule && tile.expanded.contains(e.id)) {
        setState(() {
          tile.expanded.remove(e.id);
          _refreshLessonBrowser(tile);
        });
      } else if (!e.isModule) {
        final parent = _parentModuleId(e.id);
        if (parent != null) {
          setState(() {
            tile.expanded.remove(parent);
            _refreshLessonBrowser(tile);
            final idx = entries.indexWhere((x) => x.isModule && x.id == parent);
            if (idx >= 0) tile.selection = idx;
          });
        }
      }
    } else if (key == LogicalKeyboardKey.enter) {
      final e = entries[tile.selection];
      if (e.isModule) {
        // Enter a module directly = open its first lesson.
        for (final m in CurriculumController.instance.modules) {
          if (m.id == e.id && m.lessons.isNotEmpty) {
            _openLessonIn(tile, m.lessons.first.id);
            break;
          }
        }
      } else {
        _openLessonIn(tile, e.id);
      }
    }
    return KeyEventResult.handled;
  }

  // ---- Investigations dashboard (TileType.investigations) ----

  Future<void> _openInvestigations() async {
    await InvestigationsController.instance.load();
    final tile = wm.findByType(TileType.investigations) ??
        wm.spawn(TileSpec(
            type: TileType.investigations,
            title: 'INVESTIGATIONS',
            lines: const []));
    tile.mode = 0;
    tile.scroll = 0;
    tile.compareIds.clear();
    tile.title = 'INVESTIGATIONS';
    _refreshInvestigationsList(tile);
    wm.focus(tile.id);
    setState(() {});
  }

  /// Open the investigations tile straight into "compare" selection mode.
  Future<void> _openCompare() async {
    await InvestigationsController.instance.load();
    final tile = wm.findByType(TileType.investigations) ??
        wm.spawn(TileSpec(
            type: TileType.investigations,
            title: 'INVESTIGATIONS',
            lines: const []));
    tile.selection = 0;
    _enterCompareSelect(tile);
    wm.focus(tile.id);
  }

  void _refreshInvestigationsList(Tile tile) {
    final invs = InvestigationsController.instance.investigations;
    tile.lines
      ..clear()
      ..addAll([
        for (final i in invs) '${i.score.toString().padLeft(3)}  ${i.name}'
      ]);
    if (tile.selection >= tile.lines.length) tile.selection = 0;
  }

  void _openInvestigationDetail(Tile tile, int idx) {
    final invs = InvestigationsController.instance.investigations;
    if (idx < 0 || idx >= invs.length) return;
    final inv = invs[idx];
    setState(() {
      tile.lessonId = inv.id;
      tile.mode = 1;
      tile.scroll = 0;
      tile.title = 'INVESTIGATION · ${inv.name}';
      tile.mdLines = renderMarkdown(inv.toMarkdown());
    });
  }

  /// Enter "compare" mode on the investigations tile: pick two to contrast.
  void _enterCompareSelect(Tile tile) {
    setState(() {
      tile.mode = 2;
      tile.scroll = 0;
      tile.compareIds.clear();
      tile.title = 'COMPARE · select 2';
      _refreshCompareList(tile);
    });
  }

  /// Toggle an investigation's selection while choosing the comparison pair.
  void _toggleCompare(Tile tile, int idx) {
    final invs = InvestigationsController.instance.investigations;
    if (idx < 0 || idx >= invs.length) return;
    final id = invs[idx].id;
    setState(() {
      if (tile.compareIds.contains(id)) {
        tile.compareIds.remove(id);
      } else if (tile.compareIds.length < 2) {
        tile.compareIds.add(id);
      } else {
        tile.compareIds.removeAt(0); // replace the oldest pick
        tile.compareIds.add(id);
      }
      _refreshCompareList(tile);
    });
  }

  /// Build + open the side-by-side comparison of the two selected investigations.
  void _openComparison(Tile tile) {
    final invs = InvestigationsController.instance.investigations;
    if (tile.compareIds.length != 2) return;
    final picked = [for (final i in invs) if (tile.compareIds.contains(i.id)) i];
    if (picked.length != 2) return;
    final a = picked[0];
    final b = picked[1];
    setState(() {
      tile.mode = 3;
      tile.scroll = 0;
      tile.title = 'COMPARE · ${a.name}';
      tile.mdLines = renderMarkdown(Investigation.compareMarkdown(a, b));
    });
  }

  /// Rebuild the investigations list with comparison checkboxes.
  void _refreshCompareList(Tile tile) {
    final invs = InvestigationsController.instance.investigations;
    tile.lines
      ..clear()
      ..addAll([
        for (final i in invs)
          '${tile.compareIds.contains(i.id) ? '[x]' : '[ ]'}  ${i.score.toString().padLeft(3)}  ${i.name}'
      ]);
    if (tile.selection >= tile.lines.length) tile.selection = 0;
  }

  KeyEventResult _investigationsKey(Tile tile, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.handled;
    }
    final key = event.logicalKey;
    final invs = InvestigationsController.instance.investigations;

    // Comparison view (mode 3): scrollable markdown, esc back to the list.
    if (tile.mode == 3) {
      if (key == LogicalKeyboardKey.arrowUp) {
        setState(() {
          if (tile.scroll > 0) tile.scroll--;
        });
      } else if (key == LogicalKeyboardKey.arrowDown) {
        setState(() {
          final max = tile.mdLines.length > 1 ? tile.mdLines.length - 1 : 0;
          if (tile.scroll < max) tile.scroll++;
        });
      } else if (key == LogicalKeyboardKey.home) {
        setState(() => tile.scroll = 0);
      }
      return KeyEventResult.handled;
    }

    // Compare-select mode (2): pick two investigations.
    if (tile.mode == 2) {
      if (invs.isEmpty) return KeyEventResult.handled;
      if (key == LogicalKeyboardKey.arrowUp) {
        setState(() {
          if (tile.selection > 0) tile.selection--;
        });
      } else if (key == LogicalKeyboardKey.arrowDown) {
        setState(() {
          if (tile.selection < invs.length - 1) tile.selection++;
        });
      } else if (event is KeyDownEvent && key == LogicalKeyboardKey.space) {
        _toggleCompare(tile, tile.selection);
      } else if (event is KeyDownEvent && key == LogicalKeyboardKey.enter) {
        _openComparison(tile);
      }
      return KeyEventResult.handled;
    }

    // Detail view (mode 1).
    if (tile.mode == 1) {
      if (key == LogicalKeyboardKey.arrowUp) {
        setState(() {
          if (tile.scroll > 0) tile.scroll--;
        });
      } else if (key == LogicalKeyboardKey.arrowDown) {
        setState(() {
          final max = tile.mdLines.length > 1 ? tile.mdLines.length - 1 : 0;
          if (tile.scroll < max) tile.scroll++;
        });
      } else if (key == LogicalKeyboardKey.arrowLeft ||
          key == LogicalKeyboardKey.pageUp) {
        final idx = invs.indexWhere((i) => i.id == tile.lessonId);
        if (idx > 0) _openInvestigationDetail(tile, idx - 1);
      } else if (key == LogicalKeyboardKey.arrowRight ||
          key == LogicalKeyboardKey.pageDown) {
        final idx = invs.indexWhere((i) => i.id == tile.lessonId);
        if (idx >= 0 && idx < invs.length - 1) {
          _openInvestigationDetail(tile, idx + 1);
        }
      } else if (key == LogicalKeyboardKey.home) {
        setState(() => tile.scroll = 0);
      }
      return KeyEventResult.handled;
    }

    // Browse the ranked list (mode 0).
    if (invs.isEmpty) return KeyEventResult.handled;
    if (tile.selection >= invs.length) tile.selection = 0;
    if (key == LogicalKeyboardKey.arrowUp) {
      setState(() {
        if (tile.selection > 0) tile.selection--;
      });
    } else if (key == LogicalKeyboardKey.arrowDown) {
      setState(() {
        if (tile.selection < invs.length - 1) tile.selection++;
      });
    } else if (event is KeyDownEvent && key == LogicalKeyboardKey.enter) {
      _openInvestigationDetail(tile, tile.selection);
    } else if (event is KeyDownEvent && key == LogicalKeyboardKey.keyC) {
      _enterCompareSelect(tile);
    }
    return KeyEventResult.handled;
  }

  // ---- Graph tile, inline images, link navigation, resize ----

  void _stepGraph(double dt) {
    final p = _graphPhysics;
    if (p == null) return;
    final tile = wm.findByType(TileType.graph);
    if (tile == null) return;
    final rect = wm.layout(_size)[tile.id];
    if (rect == null) return;
    final cellH = _size.height / 40;
    final pad = cellH * 0.6;
    p.width = rect.width - pad * 2;
    p.height = rect.height - cellH * 3.5;
    if (p.width > 0 && p.height > 0) p.step(dt.clamp(0.0, 0.05));
  }

  void _openGraph() {
    final graph = VaultController.instance.vault.toGraph();
    for (final n in graph.nodes) {
      n.x = 40 + math.Random().nextDouble() * 300;
      n.y = 40 + math.Random().nextDouble() * 300;
    }
    final tile = wm.findByType(TileType.graph) ??
        wm.spawn(TileSpec(type: TileType.graph, title: 'GRAPH', lines: const []));
    tile.graph = graph;
    _graphPhysics = GraphPhysics(graph: graph);
    wm.focus(tile.id);
    setState(() {});
  }

  void _followLink(String target) {
    if (target.startsWith('note://')) {
      final title = Uri.decodeComponent(target.substring('note://'.length));
      if (!VaultController.instance.vault.has(title)) {
        // Obsidian-style: clicking a [[missing page]] creates it.
        VaultController.instance.vault.addNote(Note(title: title, content: ''));
      }
      _openNote(title);
      _refreshNotesTile();
    }
  }

  Future<void> _loadMarkdownImages(Tile tile) async {
    for (final line in tile.mdLines) {
      if (line.block != MdBlock.image) continue;
      final url = line.imageUrl;
      if (url == null || url.isEmpty || tile.images.containsKey(url)) continue;
      final resolved = _resolveImageUrl(url);
      if (resolved == null) continue;
      try {
        final bytes = await http.get(Uri.parse(resolved)).then((r) => r.bodyBytes);
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        if (!mounted) {
          frame.image.dispose();
          return;
        }
        if (!tile.images.containsKey(url)) {
          setState(() => tile.images[url] = frame.image);
        } else {
          frame.image.dispose();
        }
      } catch (_) {
        // image unavailable — the painter shows a placeholder
      }
    }
  }

  String? _resolveImageUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('note://')) return null;
    return '${AiService.ragUrl}/figures/${Uri.encodeComponent(url)}';
  }

  /// Which splitter the pointer is over: 0 none, 1 master, 2.. = stack i+2.
  int _hitSplitter(Offset pos) {
    final rects = wm.layout(_size);
    if (rects.length < 2) return 0;
    final cellH = _size.height / 40;
    final band = cellH * 0.5;
    final g = _size.shortestSide * 0.012;
    final master = wm.focusedTile ?? wm.tiles.first;
    final others = [for (final t in wm.tiles) if (t.id != master.id) t];
    final masterRect = rects[master.id];
    if (masterRect == null) return 0;
    final sx = masterRect.right + g / 2;
    if (pos.dx >= sx - band && pos.dx <= sx + band &&
        pos.dy >= masterRect.top && pos.dy <= masterRect.bottom) {
      return 1;
    }
    for (var i = 0; i < others.length - 1; i++) {
      final a = rects[others[i].id];
      final b = rects[others[i + 1].id];
      if (a == null || b == null) continue;
      final sy = a.bottom + g / 2;
      if (pos.dx >= a.left && pos.dx <= a.right &&
          pos.dy >= sy - band && pos.dy <= sy + band) {
        return 2 + i;
      }
    }
    return 0;
  }

  /// Which graph node (if any) is under the pointer.
  String? _hitGraphNode(Offset pos) {
    final tile = wm.findByType(TileType.graph);
    if (tile == null || tile.graph == null) return null;
    final rect = wm.layout(_size)[tile.id];
    if (rect == null || !rect.contains(pos)) return null;
    final local = pos - rect.topLeft;
    final cellH = _size.height / 40;
    final pad = cellH * 0.6;
    final gy = cellH * 3.5;
    for (final n in tile.graph!.nodes) {
      final dx = local.dx - (pad + n.x);
      final dy = local.dy - (gy + n.y);
      final r = n.radius + 6;
      if (dx * dx + dy * dy <= r * r) return n.id;
    }
    return null;
  }

  /// Keys when there are no tiles: `\` spawns a terminal; any other printable
  /// character re-arms the "\\ for terminal" hint.
  KeyEventResult _emptyKey(KeyEvent event) {
    final c = event.character;
    if ((c == '\\' || c == '/') && event is KeyDownEvent) {
      setState(() {
        wm.spawnTerminal();
        _termHintUntil = 0;
      });
      return KeyEventResult.handled;
    }
    if (c != null && c.length == 1 && c.codeUnitAt(0) >= 32) {
      setState(() => _termHintUntil = _t + 4);
    }
    return KeyEventResult.handled;
  }

  /// Cycle the theme (dir = +1 next, -1 previous).
  void _cycleTheme(int dir) {
    final themes = engineThemes;
    final n = themes.length;
    var idx = (widget.themeIndex + dir) % n;
    if (idx < 0) idx += n;
    setState(() {
      _selector = 'theme';
      _selectorUntil = _t + 5;
    });
    widget.onThemeChanged?.call(idx);
  }

  /// Nudge the glass level: a tap micro-steps, holding accelerates.
  void _nudgeTransparency(KeyEvent event, int dir) {
    final step = _accel.step(event, 0.02, growth: 1.35, maxStep: 0.2);
    setState(() {
      _transparencyTarget = (_transparencyTarget + dir * step).clamp(0.0, 1.0);
      _selector = 'transparency';
      _selectorUntil = _t + 5;
    });
  }

  Future<void> _run(String cmd) async {
    // Window-manager + chat controls are handled here.
    final parts = cmd.trim().split(RegExp(r'\s+'));
    final verb = parts.isEmpty ? '' : parts.first.toLowerCase();
    final rest = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    if (verb == 'ask') {
      await _bootFirebot(rest.isEmpty ? null : rest);
      return;
    }
    if (verb == 'theme' && rest.isEmpty) {
      setState(() {
        _selector = 'theme';
        _selectorUntil = _t + 5;
      });
      return;
    }
    if (verb == 'transparency') {
      setState(() {
        _selector = 'transparency';
        _selectorUntil = _t + 5;
      });
      return;
    }
    if (verb == 'notes') {
      _openNotes();
      return;
    }
    if (verb == 'lesson' || verb == 'lessons') {
      await _openLessonBrowser();
      return;
    }
    if (verb == 'graph') {
      _openGraph();
      return;
    }
    if (verb == 'investigate' || verb == 'investigations') {
      await _openInvestigations();
      return;
    }
    if (verb == 'compare') {
      await _openCompare();
      return;
    }
    if (verb == 'close') {
      setState(() {
        wm.close(wm.focused);
        if (wm.tiles.isEmpty) _termHintUntil = _t + 4;
      });
      return;
    }
    if (verb == 'windows') {
      setState(() {
        wm.closeAll();
        _termHintUntil = _t + 4;
      });
      return;
    }
    if (verb == 'clear') {
      setState(() {
        terminal.history.clear();
        terminal.clearLine();
      });
      return;
    }

    CommandOutcome outcome;
    try {
      outcome = widget.onCommand != null
          ? await widget.onCommand!(cmd)
          : const CommandOutcome(['(no command handler wired)']);
    } catch (_) {
      outcome = const CommandOutcome(['⚠️ command failed']);
    }
    if (!mounted) return;
    Tile? t;
    setState(() {
      if (terminal.history.isNotEmpty) terminal.history.removeLast();
      terminal.history.addAll(outcome.echo);
      if (outcome.tile != null) {
        t = wm.spawnOrFocus(outcome.tile!);
      }
    });
    if (t != null) _loadMarkdownImages(t!);
  }

  /// Rebuild the chat tile's rendered markdown from its conversation lines.
  /// User messages become bold `**you:**` paragraphs; replies keep their raw
  /// markdown so `*`, `#`, lists etc. render like the note preview.
  void _refreshChatMarkdown(Tile tile) {
    final buf = StringBuffer();
    for (final line in tile.lines) {
      if (line.startsWith('you: ')) {
        buf.writeln('**you:** ${line.substring(5)}');
      } else if (line.startsWith('firebot: ')) {
        buf.writeln('**firebot:**');
        buf.writeln();
        buf.writeln(line.substring(9).trim());
      } else {
        buf.writeln(line.trim());
      }
      buf.writeln();
    }
    tile.mdLines = renderMarkdown(buf.toString());
  }

  /// Boot (or focus) the FireBot chat tile; optionally send a first message.
  Future<void> _bootFirebot(String? firstMessage) async {
    final tile = wm.findByType(TileType.chat) ??
        wm.spawn(TileSpec(
          type: TileType.chat,
          title: 'FIREBOT',
          lines: ['firebot: online — ask me anything.'],
        ));
    wm.focus(tile.id);
    _refreshChatMarkdown(tile);
    setState(() => _verbHintUntil = _t + 4);
    if (firstMessage != null && firstMessage.isNotEmpty) {
      await _sendChat(tile, firstMessage);
    }
  }

  /// Send a message to FireBot inside its tile (multi-turn conversation).
  /// Verbosity: 0 = short, 1 = medium, 2 = long (all Gemini via RAG backend).
  Future<void> _sendChat(Tile tile, String message) async {
    final history = tile.lines.length > 20
        ? tile.lines.sublist(tile.lines.length - 20)
        : List<String>.from(tile.lines);
    tile.lines.add('you: $message');
    tile.lines.add('firebot: …');
    _refreshChatMarkdown(tile);
    setState(() {});

    String answer = '';
    List<String> sources = const [];
    List<String> figures = const [];
    try {
      if (tile.verbosity == 0) {
        answer = await _ai.askConcise(message, history: history);
      } else {
        final res = await _ai.askDetailed(
          message,
          verbosity: tile.verbosity == 1 ? 'medium' : 'long',
        );
        answer = res.text;
        sources = res.sources;
        figures = res.figureUrls;
      }
    } catch (_) {
      // leave empty
    }
    if (!mounted) return;
    setState(() {
      tile.lines.removeLast(); // drop the "…" placeholder
      final reply = answer.isEmpty ? '(no response — FireBot backend offline?)' : answer;
      tile.lines.add('firebot: $reply');
      for (final s in sources) {
        tile.lines.add('  • $s');
      }
      _refreshChatMarkdown(tile);
      tile.scroll = 0; // show the latest reply
    });
    if (figures.isNotEmpty) {
      await _loadFigures(tile, figures);
    }
  }

  /// Fetch + decode figure images (long RAG answers) into the tile.
  Future<void> _loadFigures(Tile tile, List<String> urls) async {
    tile.disposeFigures();
    tile.figureUrls.addAll(urls);
    for (final url in urls) {
      try {
        final bytes = await http.get(Uri.parse(url)).then((r) => r.bodyBytes);
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        if (mounted) {
          setState(() => tile.figureImages.add(frame.image));
        } else {
          frame.image.dispose();
        }
      } catch (_) {
        // skip figure on error
      }
    }
  }

  // ---- Mobile (touch) support --------------------------------------------

  bool _tileTakesText(Tile t) =>
      t.type == TileType.chat ||
      t.type == TileType.shell ||
      (t.type == TileType.note && t.mode == 1) ||
      (t.type == TileType.notes && t.mode == 1);

  String _focusedInputText() {
    final ft = wm.focusedTile;
    if (ft == null) return '';
    if (ft.type == TileType.chat) return ft.input;
    if (ft.type == TileType.shell) return terminal.input;
    if (ft.type == TileType.note && ft.mode == 1) return ft.input;
    if (ft.type == TileType.notes && ft.mode == 1) return ft.input;
    return '';
  }

  /// Whether the soft-keyboard field should be multi-line (note editing).
  bool get _mobileMultiline {
    final ft = wm.focusedTile;
    return ft != null && ft.type == TileType.note && ft.mode == 1;
  }

  /// Point the hidden soft-keyboard field at the focused tile's text.
  void _syncMobileInput() {
    final ft = wm.focusedTile;
    if (ft == null || !_tileTakesText(ft)) {
      _mobileFocus.unfocus();
      return;
    }
    final text = _focusedInputText();
    _mobileCtl.text = text;
    _mobileCtl.selection = TextSelection.collapsed(offset: text.length);
    _mobileFocus.requestFocus();
  }

  void _onMobileChanged(String v) {
    final ft = wm.focusedTile;
    if (ft == null) return;
    setState(() {
      if (ft.type == TileType.chat) {
        ft.input = v;
      } else if (ft.type == TileType.shell) {
        terminal.input = v;
      } else if (ft.type == TileType.note && ft.mode == 1) {
        ft.input = v;
        ft.cursor = v.length;
      } else if (ft.type == TileType.notes && ft.mode == 1) {
        ft.input = v;
      }
    });
  }

  void _onMobileSubmitted(String v) {
    final ft = wm.focusedTile;
    if (ft == null) return;
    if (ft.type == TileType.chat) {
      final msg = v.trim();
      setState(() => ft.input = '');
      _mobileCtl.clear();
      if (msg.isNotEmpty) _sendChat(ft, msg);
    } else if (ft.type == TileType.shell) {
      terminal.input = v;
      final cmd = terminal.enter();
      setState(() {
        if (cmd != null) terminal.history.add('…');
      });
      _mobileCtl.text = terminal.input;
      _mobileCtl.selection =
          TextSelection.collapsed(offset: terminal.input.length);
      if (cmd != null) _run(cmd);
    } else if (ft.type == TileType.notes && ft.mode == 1) {
      // Create a note from the submitted title.
      final title = v.trim();
      setState(() {
        ft.input = '';
        ft.mode = 0;
      });
      _mobileCtl.clear();
      if (title.isNotEmpty) {
        _createNote(title);
        _refreshNotesList(ft);
      }
      _syncMobileInput();
    }
  }

  /// Which scrollable tile is under `pos` (chat / reading views), else -1.
  int _hitScrollable(Offset pos) {
    final rects = wm.layout(_size);
    for (final e in rects.entries) {
      if (!e.value.contains(pos)) continue;
      final t = wm.tiles.firstWhere((x) => x.id == e.key);
      if (t.type == TileType.chat ||
          (t.type == TileType.lesson && t.mode == 1) ||
          (t.type == TileType.investigations && t.mode == 1)) {
        return t.id;
      }
    }
    return -1;
  }

  /// Apply whole-line touch-scroll steps (positive = scroll down).
  void _touchScrollSteps(Tile tile, int steps) {
    if (steps == 0) return;
    setState(() {
      if (tile.type == TileType.chat) {
        tile.scroll =
            math.max(0, math.min(tile.scroll - steps, tile.mdLines.length));
      } else if (tile.type == TileType.lesson ||
          tile.type == TileType.investigations) {
        final max = tile.mdLines.length > 1 ? tile.mdLines.length - 1 : 0;
        tile.scroll = math.max(0, math.min(tile.scroll + steps, max));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = themeByIndex(widget.themeIndex);
    return LayoutBuilder(builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      if (size != _size && size.width > 0 && size.height > 0) {
        _size = size;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _renderStarfield();
        });
      }
      final cellH = size.height / 40;
      final layout = wm.layout(size);
      final showVerb = _verbHover || _t < _verbHintUntil;
      final termAlpha = wm.tiles.isEmpty ? _fadeAlpha(_termHintUntil) : 0.0;
      final showTheme = _selector == 'theme' && _t < _selectorUntil;
      final showTransparency =
          _selector == 'transparency' && _t < _selectorUntil;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) {
          final pos = details.localPosition;
          final rects = wm.layout(_size);
          if (rects.isEmpty) {
            // No tiles open: a tap summons the terminal (and, on touch, the
            // soft keyboard) — the touch equivalent of the desktop `\\` key.
            if (_touch) {
              setState(() {
                wm.spawnTerminal();
                _termHintUntil = 0;
              });
              _syncMobileInput();
            }
            return;
          }
          for (final e in rects.entries) {
            final rect = e.value;
            if (rect.contains(pos)) {
              final tile = wm.tiles.firstWhere((t) => t.id == e.key);
              final cellH = _size.height / 40;
              // FireBot verbosity slider.
              if (tile.type == TileType.chat && _hitSlider(rect, pos)) {
                setState(() {
                  tile.verbosity = _sliderIndex(rect, pos);
                  _verbHintUntil = _t + 4;
                });
                break;
              }
              // Shell selectors (theme / transparency).
              if (tile.type == TileType.shell) {
                final showThemeNow = _selector == 'theme' && _t < _selectorUntil;
                final showTransparencyNow =
                    _selector == 'transparency' && _t < _selectorUntil;
                if (showThemeNow &&
                    pos.dy >= rect.top + 2 * cellH &&
                    pos.dy <= rect.top + 3 * cellH) {
                  final idx = _themeIndexAt(rect, pos);
                  setState(() => _selectorUntil = _t + 5);
                  widget.onThemeChanged?.call(idx);
                  break;
                }
                if (showTransparencyNow) {
                  final yBase = rect.top + (showThemeNow ? 3 : 2) * cellH;
                  if (pos.dy >= yBase && pos.dy <= yBase + cellH) {
                    setState(() {
                      _transparencyTarget = _transparencyAt(rect, pos);
                      _selectorUntil = _t + 5;
                    });
                    break;
                  }
                }
              }
              // Lesson browser: tap a module to expand it, a lesson to open it.
              if (tile.type == TileType.lesson && tile.mode == 0) {
                final entries = _lessonEntries(tile);
                if (entries.isNotEmpty) {
                  final contentLines =
                      ((rect.height - 3.5 * cellH) / cellH).floor();
                  var start = tile.selection - (contentLines ~/ 2);
                  if (start < 0) start = 0;
                  if (start + contentLines > entries.length) {
                    start = entries.length - contentLines;
                  }
                  if (start < 0) start = 0;
                  final lineIdx =
                      ((pos.dy - rect.top - 3.5 * cellH) / cellH).floor();
                  final idx = start + lineIdx;
                  if (idx >= 0 && idx < entries.length) {
                    final entry = entries[idx];
                    if (entry.isModule) {
                      setState(() {
                        tile.selection = idx;
                        tile.expanded.add(entry.id);
                        _refreshLessonBrowser(tile);
                      });
                    } else {
                      tile.selection = idx;
                      _openLessonIn(tile, entry.id);
                    }
                    break;
                  }
                }
              }
              // Notes browser: click a title to open it.
              if (tile.type == TileType.notes) {
                final titles = VaultController.instance.vault.allTitles;
                if (titles.isNotEmpty) {
                  final cellH = _size.height / 40;
                  final contentLines = ((rect.height - 3.5 * cellH) / cellH).floor();
                  var start = tile.selection - (contentLines ~/ 2);
                  if (start < 0) start = 0;
                  if (start + contentLines > titles.length) {
                    start = titles.length - contentLines;
                  }
                  if (start < 0) start = 0;
                  final lineIdx = ((pos.dy - rect.top - 3.5 * cellH) / cellH).floor();
                  final noteIdx = start + lineIdx;
                  if (noteIdx >= 0 && noteIdx < titles.length) {
                    _openNote(titles[noteIdx]);
                    break;
                  }
                }
              }
              // Investigations: click a row to open detail (browse) or toggle
              // it for comparison (compare-select mode).
              if (tile.type == TileType.investigations &&
                  (tile.mode == 0 || tile.mode == 2)) {
                final invs = InvestigationsController.instance.investigations;
                if (invs.isNotEmpty) {
                  final cellH = _size.height / 40;
                  final contentLines = ((rect.height - 3.5 * cellH) / cellH).floor();
                  var start = tile.selection - (contentLines ~/ 2);
                  if (start < 0) start = 0;
                  if (start + contentLines > invs.length) {
                    start = invs.length - contentLines;
                  }
                  if (start < 0) start = 0;
                  final lineIdx = ((pos.dy - rect.top - 3.5 * cellH) / cellH).floor();
                  final invIdx = start + lineIdx;
                  if (invIdx >= 0 && invIdx < invs.length) {
                    if (tile.mode == 2) {
                      _toggleCompare(tile, invIdx);
                    } else {
                      _openInvestigationDetail(tile, invIdx);
                    }
                    break;
                  }
                }
              }
              // Graph node: click to open its note.
              if (tile.type == TileType.graph && tile.graph != null) {
                final local = pos - rect.topLeft;
                final pad = cellH * 0.6;
                final gy = cellH * 3.5;
                for (final n in tile.graph!.nodes) {
                  final dx = local.dx - (pad + n.x);
                  final dy = local.dy - (gy + n.y);
                  final r = n.radius + 4;
                  if (dx * dx + dy * dy <= r * r) {
                    _openNote(n.id);
                    return;
                  }
                }
              }
              // Markdown links: click to open.
              if (tile.type == TileType.note ||
                  tile.type == TileType.lesson ||
                  tile.type == TileType.study) {
                final local = pos - rect.topLeft;
                for (final l in tile.links) {
                  if (l.rect.contains(local)) {
                    _followLink(l.target);
                    return;
                  }
                }
              }
              // Lesson reader: tap the title bar to go back to the browser;
              // tap the left/right edges for the previous/next lesson.
              if (tile.type == TileType.lesson && tile.mode == 1) {
                final local = pos - rect.topLeft;
                if (local.dy < cellH * 2) {
                  setState(() {
                    tile.mode = 0;
                    tile.scroll = 0;
                    tile.title = 'LESSONS';
                    _refreshLessonBrowser(tile);
                  });
                  return;
                }
                final frac = local.dx / rect.width;
                if (frac < 0.18) {
                  _lessonStep(tile, -1);
                } else if (frac > 0.82) {
                  _lessonStep(tile, 1);
                }
                return;
              }
              // Investigation detail / comparison: tap the title bar to go back
              // to the ranked list.
              if (tile.type == TileType.investigations &&
                  (tile.mode == 1 || tile.mode == 3)) {
                final local = pos - rect.topLeft;
                if (local.dy < cellH * 2) {
                  setState(() {
                    tile.mode = 0;
                    tile.scroll = 0;
                    tile.compareIds.clear();
                    tile.title = 'INVESTIGATIONS';
                    _refreshInvestigationsList(tile);
                  });
                  return;
                }
              }
              // Note tile: tap the body to edit it; while editing, tap the
              // title bar to save and return to view (links handled above).
              if (tile.type == TileType.note) {
                final local = pos - rect.topLeft;
                final inHeader = local.dy < cellH * 2;
                if (tile.mode == 1) {
                  if (inHeader) {
                    _saveNote(tile);
                    setState(() => tile.mode = 0);
                    if (_touch) _mobileFocus.unfocus();
                  }
                  return;
                }
                if (!inHeader) {
                  setState(() {
                    tile.input = tile.raw;
                    tile.cursor = tile.input.length;
                    tile.mode = 1;
                  });
                  if (_touch) _syncMobileInput();
                  return;
                }
              }
              // Fallback: focus.
              setState(() {
                wm.focus(e.key);
                if (tile.type == TileType.chat) _verbHintUntil = _t + 4;
              });
              // On touch: summon/hide the soft keyboard for text-input tiles.
              if (_touch) {
                if (_tileTakesText(tile)) {
                  _syncMobileInput();
                } else {
                  _mobileFocus.unfocus();
                }
              }
              break;
            }
          }
        },
        onPanStart: (details) {
          final nodeId = _hitGraphNode(details.localPosition);
          if (nodeId != null) {
            _dragNodeId = nodeId;
            final g = wm.findByType(TileType.graph)?.graph;
            if (g != null) {
              for (final n in g.nodes) {
                if (n.id == nodeId) n.pinned = true;
              }
            }
            return;
          }
          final mode = _hitSplitter(details.localPosition);
          _dragMode = mode;
          _dragStack = -1;
          _scrollDragId = -1;
          if (mode == 0 && _touch) {
            _scrollDragId = _hitScrollable(details.localPosition);
            _scrollDragLastY = details.localPosition.dy;
            _scrollAccum = 0;
          }
          if (mode >= 2) {
            final rects = wm.layout(_size);
            final master = wm.focusedTile ?? wm.tiles.first;
            final others = [for (final t in wm.tiles) if (t.id != master.id) t];
            final i = mode - 2;
            final a = rects[others[i].id];
            final b = rects[others[i + 1].id];
            if (a != null && b != null) {
              _dragStack = i;
              _dragTop = a.top;
              _dragBottom = b.bottom;
              _dragFrac = wm.stackFractions[i] + wm.stackFractions[i + 1];
            }
          }
        },
        onPanUpdate: (details) {
          final nodeId = _dragNodeId;
          if (nodeId != null) {
            final tile = wm.findByType(TileType.graph);
            final rect = tile == null ? null : wm.layout(_size)[tile.id];
            if (tile != null && rect != null && tile.graph != null) {
              final local = details.localPosition - rect.topLeft;
              final cellH = _size.height / 40;
              final pad = cellH * 0.6;
              final gy = cellH * 3.5;
              for (final n in tile.graph!.nodes) {
                if (n.id == nodeId) {
                  setState(() {
                    n.x = (local.dx - pad).clamp(0.0, rect.width - pad * 2).toDouble();
                    n.y = (local.dy - gy).clamp(0.0, rect.height - gy - cellH).toDouble();
                  });
                }
              }
            }
            return;
          }
          final pos = details.localPosition;
          if (_dragMode == 1) {
            final g = _size.shortestSide * 0.012;
            final m = _size.shortestSide * 0.03;
            final areaW = _size.width - 2 * m;
            final ratio =
                ((pos.dx - m - g / 2) / (areaW - g)).clamp(0.2, 0.85).toDouble();
            setState(() => wm.masterRatio = ratio);
          } else if (_dragMode >= 2 &&
              _dragStack >= 0 &&
              _dragStack + 1 < wm.stackFractions.length) {
            final span = _dragBottom - _dragTop;
            if (span > 0 && _dragFrac > 0.1) {
              final frac = ((pos.dy - _dragTop) / span * _dragFrac)
                  .clamp(0.05, _dragFrac - 0.05)
                  .toDouble();
              setState(() {
                wm.stackFractions[_dragStack] = frac;
                wm.stackFractions[_dragStack + 1] = _dragFrac - frac;
              });
            }
          }
          if (_scrollDragId >= 0) {
            Tile? tile;
            for (final t in wm.tiles) {
              if (t.id == _scrollDragId) {
                tile = t;
                break;
              }
            }
            if (tile != null) {
              final dy = details.localPosition.dy - _scrollDragLastY;
              _scrollDragLastY = details.localPosition.dy;
              _scrollAccum += dy;
              final cellH = _size.height / 40;
              final steps = (-_scrollAccum / cellH).truncate();
              if (steps != 0) {
                _scrollAccum += steps * cellH;
                _touchScrollSteps(tile, steps);
              }
            }
          }
        },
        onPanEnd: (_) {
          if (_dragNodeId != null) {
            final g = wm.findByType(TileType.graph)?.graph;
            if (g != null) {
              for (final n in g.nodes) {
                if (n.id == _dragNodeId) n.pinned = false;
              }
            }
            _dragNodeId = null;
          }
          _dragMode = 0;
          _dragStack = -1;
          _scrollDragId = -1;
        },
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (e) {
            if (e.kind == PointerDeviceKind.touch) _touch = true;
          },
          onPointerSignal: _onPointerSignal,
          child: MouseRegion(
            cursor: SystemMouseCursors.none,
          onHover: (e) {
            final pos = e.localPosition;
            setState(() {
              sonar.move(pos.dx, pos.dy);
              _verbHover = false;
              final rects = wm.layout(_size);
              for (final t in wm.tiles) {
                if (t.type != TileType.chat) continue;
                final rect = rects[t.id];
                if (rect != null && _hitSlider(rect, pos)) {
                  _verbHover = true;
                  _verbHintUntil = _t + 4;
                  break;
                }
              }
            });
          },
          onExit: (_) => setState(sonar.hide),
          child: Focus(
            focusNode: _focus,
            autofocus: true,
            onKeyEvent: _onKey,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: BackgroundPainter(
                      theme: theme,
                      settings: settings,
                      starfield: starfield,
                      t: _t,
                      shader: _shader,
                      starfieldImage: _starfieldImage,
                      hintText: termAlpha > 0 ? '\\ for terminal' : null,
                      hintAlpha: termAlpha,
                    ),
                  ),
                ),
                for (final tile in wm.tiles)
                  _buildTile(
                    theme,
                    tile,
                    layout[tile.id]!,
                    cellH,
                    showVerb,
                    _transparency,
                    showTheme,
                    showTransparency,
                    widget.themeIndex,
                  ),
                Positioned.fill(
                  child: CustomPaint(painter: SonarPainter(sonar, _t, theme.color)),
                ),
                // Hidden field that summons the soft keyboard on touch devices.
                Positioned(
                  left: 0,
                  top: 0,
                  width: 1,
                  height: 1,
                  child: Opacity(
                    opacity: 0,
                    child: TextField(
                      controller: _mobileCtl,
                      focusNode: _mobileFocus,
                      onChanged: _onMobileChanged,
                      onSubmitted: _onMobileSubmitted,
                      autocorrect: false,
                      enableSuggestions: false,
                      maxLines: _mobileMultiline ? null : 1,
                      keyboardType: _mobileMultiline
                          ? TextInputType.multiline
                          : TextInputType.text,
                      textInputAction: _mobileMultiline
                          ? TextInputAction.newline
                          : TextInputAction.done,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ),
        ),
      );
    });
  }

  Widget _buildTile(
    EngineTheme theme,
    Tile tile,
    Rect rect,
    double cellH,
    bool showVerb,
    double transparency,
    bool showTheme,
    bool showTransparency,
    int themeIndex,
  ) {
    final focused = wm.focused == tile.id;
    final isShell = tile.type == TileType.shell;
    return AnimatedPositioned(
      key: ValueKey(tile.id),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: ClipRect(
        child: CustomPaint(
          painter: TilePainter(
            tile: tile,
            focused: focused,
            theme: theme,
            cellH: cellH,
            t: _t,
            showVerb: showVerb,
            transparency: transparency,
            showTheme: isShell && showTheme,
            showTransparency: isShell && showTransparency,
            themeIndex: themeIndex,
            glassImage: _glassImage,
            tileRect: rect,
            terminal: isShell ? terminal : null,
          ),
        ),
      ),
    );
  }

  /// Whether a tap falls on the FireBot tile's verbosity slider (line 3).
  bool _hitSlider(Rect rect, Offset pos) {
    final cellH = _size.height / 40;
    final pad = cellH * 0.6;
    final y0 = rect.top + 2 * cellH;
    final y1 = rect.top + 3 * cellH;
    final x0 = rect.left + pad;
    final x1 = rect.left + pad + (rect.width - 2 * pad) * kSliderTrackFraction;
    return pos.dy >= y0 && pos.dy <= y1 && pos.dx >= x0 && pos.dx <= x1;
  }

  /// Which verbosity segment (0..2) a tap on the slider selects.
  int _sliderIndex(Rect rect, Offset pos) {
    final cellH = _size.height / 40;
    final pad = cellH * 0.6;
    final x0 = rect.left + pad;
    final width = (rect.width - 2 * pad) * kSliderTrackFraction;
    final idx = ((pos.dx - x0) / (width / 3)).floor();
    return idx < 0 ? 0 : (idx > 2 ? 2 : idx);
  }

  /// Which theme index (0..n-1) a tap on the theme selector selects.
  int _themeIndexAt(Rect rect, Offset pos) {
    final cellH = _size.height / 40;
    final pad = cellH * 0.6;
    final x0 = rect.left + pad;
    final width = rect.width - 2 * pad;
    final n = engineThemes.length;
    final idx = ((pos.dx - x0) / (width / n)).floor();
    return idx < 0 ? 0 : (idx >= n ? n - 1 : idx);
  }

  /// Transparency (0..1) from a tap position on the transparency selector.
  double _transparencyAt(Rect rect, Offset pos) {
    final cellH = _size.height / 40;
    final pad = cellH * 0.6;
    final x0 = rect.left + pad;
    final width = rect.width - 2 * pad;
    return ((pos.dx - x0) / width).clamp(0.0, 1.0);
  }

  /// Fade helper: fully visible until the last second, then 0 at `until`.
  double _fadeAlpha(double until) {
    final remaining = until - _t;
    if (remaining <= 0) return 0;
    return remaining >= 1.0 ? 1.0 : remaining;
  }
}
