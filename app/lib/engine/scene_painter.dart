import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/graph.dart';
import 'markdown_renderer.dart';
import 'settings.dart';
import 'starfield.dart';
import 'terminal.dart';
import 'themes.dart';
import 'wm.dart';

/// Draws the flat starfield characters. The CRT shader warps and filters them.
void drawStarfieldChars(
  Canvas canvas,
  Size size,
  Starfield starfield,
  EngineTheme theme,
  EngineSettings settings,
  double t,
) {
  const cols = 80, rows = 40;
  final cellW = size.width / cols;
  final cellH = size.height / rows;
  final style = TextStyle(
    fontFamily: 'ShareTechMono',
    fontSize: cellH,
    color: theme.color,
    height: 1.0,
  );
  for (final s in starfield.stars) {
    final ix = (s.x * (cols - 1)).toInt();
    final iy = (s.y * (rows - 1)).toInt();
    if (ix < 0 || ix >= cols || iy < 0 || iy >= rows) continue;
    final ch = starfield.charFor(s, t, settings.twinkle);
    if (ch == ' ') continue;
    final tp = TextPainter(
      text: TextSpan(text: ch, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(ix * cellW, iy * cellH));
  }
}

/// Draws only the CRT starfield — the "desktop" behind the tiled windows.
class BackgroundPainter extends CustomPainter {
  final EngineTheme theme;
  final EngineSettings settings;
  final Starfield starfield;
  final double t;
  final ui.FragmentShader? shader;
  final ui.Image? starfieldImage;
  final String? hintText; // e.g. "\\ for terminal" when there are no tiles
  final double hintAlpha;

  BackgroundPainter({
    required this.theme,
    required this.settings,
    required this.starfield,
    required this.t,
    this.shader,
    this.starfieldImage,
    this.hintText,
    this.hintAlpha = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.black);

    if (shader != null && starfieldImage != null) {
      final s = shader!;
      s.setImageSampler(0, starfieldImage!);
      s.setFloat(0, settings.curvature);
      s.setFloat(1, settings.vignette);
      s.setFloat(2, settings.scanlines);
      s.setFloat(3, settings.glow);
      s.setFloat(4, settings.bezelN);
      s.setFloat(5, settings.bezelInset);
      s.setFloat(6, size.width / size.height); // true flex: bezel fills the window
      s.setFloat(7, size.width);
      s.setFloat(8, size.height);
      s.setFloat(9, theme.color.r);
      s.setFloat(10, theme.color.g);
      s.setFloat(11, theme.color.b);
      canvas.drawRect(Offset.zero & size, Paint()..shader = s);
    } else {
      drawStarfieldChars(canvas, size, starfield, theme, settings, t);
    }

    // Fading center hint (e.g. "\\ for terminal") when there are no tiles.
    if (hintText != null && hintAlpha > 0) {
      final style = TextStyle(
        fontFamily: 'ShareTechMono',
        fontSize: size.height / 40,
        color: theme.color.withValues(alpha: hintAlpha * 0.8),
        height: 1.0,
      );
      final tp = TextPainter(
        text: TextSpan(text: hintText, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset((size.width - tp.width) / 2, size.height * 0.62));
    }
  }

  @override
  bool shouldRepaint(covariant BackgroundPainter old) =>
      old.t != t ||
      old.theme != theme ||
      old.shader != shader ||
      old.starfieldImage != starfieldImage ||
      old.hintText != hintText ||
      old.hintAlpha != hintAlpha;
}

/// Draws a single tile's content: frosted tint, border, title bar and text.
/// The shell tile (`terminal != null`) renders the live terminal; other tiles
/// render their `tile.lines`.
class TilePainter extends CustomPainter {
  final Tile tile;
  final bool focused;
  final EngineTheme theme;
  final double cellH; // global line height (consistent across tiles)
  final Terminal? terminal; // non-null only for the shell tile
  final double t;
  final bool showVerb; // whether to show the verbosity slider + hint
  final double transparency; // 0 clear .. 1 frosted (glass level)
  final bool showTheme; // show the theme selector line
  final bool showTransparency; // show the transparency selector line
  final int themeIndex; // active theme (highlighted in the selector)
  final ui.Image? glassImage; // Kawase-blurred starfield (tile backdrop)
  final Rect tileRect; // this tile's global rect (source region in glassImage)

  TilePainter({
    required this.tile,
    required this.focused,
    required this.theme,
    required this.cellH,
    required this.t,
    this.terminal,
    this.showVerb = true,
    this.transparency = 0,
    this.showTheme = false,
    this.showTransparency = false,
    this.themeIndex = 0,
    this.glassImage,
    this.tileRect = Rect.zero,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final glyphW = cellH * 0.6;
    final pad = glyphW;

    // Kawase glass backdrop (blurred starfield) + frost tint.
    final frost = transparency;
    if (glassImage != null && frost > 0) {
      canvas.save();
      canvas.clipRect(Offset.zero & size);
      canvas.drawImageRect(
        glassImage!,
        tileRect,
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = Colors.white.withValues(alpha: frost),
      );
      canvas.restore();
    }
    canvas.drawRect(
        Offset.zero & size, Paint()..color = Colors.white.withValues(alpha: 0.18 * frost));
    canvas.drawRect(
        Offset.zero & size, Paint()..color = theme.color.withValues(alpha: 0.05 * frost));
    canvas.drawRect(
        Offset.zero & size, Paint()..color = Colors.black.withValues(alpha: 0.10 * frost));

    // Border (focused tiles glow brighter).
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = focused ? 2.0 : 1.0
        ..color = theme.color.withValues(alpha: focused ? 0.95 : 0.35),
    );

    final titleStyle = _style(cellH, focused ? theme.color : _dim);
    final bodyStyle = _style(cellH, theme.color);

    var ty = cellH * 0.5;
    if (focused) {
      // Focus indicator: a highlighted title bar + ▸ marker.
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, cellH * 1.6),
        Paint()..color = theme.color.withValues(alpha: 0.12),
      );
      _line(canvas, '▶ ${tile.title.toUpperCase()}', pad, ty, titleStyle);
    } else {
      _line(canvas, tile.title.toUpperCase(), pad, ty, titleStyle);
    }
    ty += cellH;
    final maxChars = _maxChars(size, pad, glyphW);
    _line(canvas, '─' * maxChars, pad, ty, titleStyle);
    ty += cellH;

    final maxLines = ((size.height - ty) / cellH).floor();
    if (maxLines <= 0) return;

    if (terminal != null) {
      // Selector lines (theme / transparency) above the terminal content.
      if (showTheme) {
        _paintThemeSelector(canvas, size, pad, glyphW, ty);
        ty += cellH;
      }
      if (showTransparency) {
        _paintTransparencySelector(canvas, size, pad, glyphW, ty);
        ty += cellH;
      }
      // Shell: startup script + history + input draft, scrolled to the bottom.
      var revealed = terminal!.revealed();
      if (revealed.endsWith('\n')) {
        revealed = revealed.substring(0, revealed.length - 1);
      }
      final scriptLines = revealed.isEmpty ? <String>[] : revealed.split('\n');
      final draftLines = terminal!.input.split('\n');
      final all = [...scriptLines, ...terminal!.history, ...draftLines];
      final shellMaxLines = ((size.height - ty) / cellH).floor();
      if (shellMaxLines > 0) {
        final shown = all.length > shellMaxLines
            ? all.sublist(all.length - shellMaxLines)
            : all;
        for (final line in shown) {
          final clipped = line.length > maxChars ? line.substring(0, maxChars) : line;
          _line(canvas, clipped, pad, ty, bodyStyle);
          ty += cellH;
        }
        // Blinking block cursor at the end of the last draft line.
        if ((t * 2).floor().isEven && draftLines.isNotEmpty) {
          final tp = TextPainter(
            text: TextSpan(text: draftLines.last, style: bodyStyle),
            textDirection: TextDirection.ltr,
          )..layout();
          canvas.drawRect(
            Rect.fromLTWH(pad + tp.width, ty - cellH, glyphW - 2, cellH - 2),
            Paint()..color = theme.color,
          );
        }
      }
    } else if (tile.type == TileType.notes) {
      if (tile.mode == 1) {
        // Create mode: title prompt.
        _line(canvas, 'NEW NOTE — type a title, enter to create', pad, ty,
            _style(cellH, _dim));
        ty += cellH;
        final inputLine = '> ${tile.input}';
        final clipped =
            inputLine.length > maxChars ? inputLine.substring(0, maxChars) : inputLine;
        _line(canvas, clipped, pad, ty, _style(cellH, theme.color));
        if ((t * 2).floor().isEven) {
          final tp = TextPainter(
            text: TextSpan(text: clipped, style: _style(cellH, theme.color)),
            textDirection: TextDirection.ltr,
          )..layout();
          canvas.drawRect(
            Rect.fromLTWH(pad + tp.width, ty, glyphW - 2, cellH - 2),
            Paint()..color = theme.color,
          );
        }
      } else {
        // Browse mode: hint + list with a selection cursor.
        _line(canvas, '↑↓ select · enter/tap open · N new', pad, ty, _style(cellH, _dim));
        ty += cellH;
        final contentLines = ((size.height - ty) / cellH).floor();
        if (contentLines > 0 && tile.lines.isNotEmpty) {
          var start = tile.selection - (contentLines ~/ 2);
          if (start < 0) start = 0;
          if (start + contentLines > tile.lines.length) {
            start = tile.lines.length - contentLines;
          }
          if (start < 0) start = 0;
          final end = start + contentLines > tile.lines.length
              ? tile.lines.length
              : start + contentLines;
          for (var i = start; i < end; i++) {
            final sel = i == tile.selection;
            final label = sel ? '▶ ${tile.lines[i]}' : '  ${tile.lines[i]}';
            final clipped = label.length > maxChars ? label.substring(0, maxChars) : label;
            _line(canvas, clipped, pad, ty, _style(cellH, sel ? theme.color : _dim));
            ty += cellH;
          }
        }
      }
    } else if (tile.type == TileType.lesson) {
      if (tile.mode == 1) {
        // Reading a lesson: hint + scrollable rich markdown.
        _line(canvas, '↑↓/drag scroll · ←/→ prev/next · esc/tap-title back', pad, ty,
            _style(cellH, _dim));
        ty += cellH;
        _paintMarkdown(canvas, size, pad, ty, cellH, maxChars, skip: tile.scroll);
      } else {
        // Browse the curriculum: hint + hierarchical list with a cursor.
        _line(canvas, '↑↓ select · →/tap expand · enter/tap open', pad, ty,
            _style(cellH, _dim));
        ty += cellH;
        final contentLines = ((size.height - ty) / cellH).floor();
        if (contentLines > 0 && tile.lines.isNotEmpty) {
          var start = tile.selection - (contentLines ~/ 2);
          if (start < 0) start = 0;
          if (start + contentLines > tile.lines.length) {
            start = tile.lines.length - contentLines;
          }
          if (start < 0) start = 0;
          final end = start + contentLines > tile.lines.length
              ? tile.lines.length
              : start + contentLines;
          for (var i = start; i < end; i++) {
            final sel = i == tile.selection;
            final label = sel ? '▶ ${tile.lines[i]}' : '  ${tile.lines[i]}';
            final clipped = label.length > maxChars ? label.substring(0, maxChars) : label;
            _line(canvas, clipped, pad, ty, _style(cellH, sel ? theme.color : _dim));
            ty += cellH;
          }
        }
      }
    } else if (tile.type == TileType.graph) {
      _paintGraph(canvas, size, pad, ty, cellH);
    } else if (tile.type == TileType.investigations) {
      _paintInvestigations(canvas, size, pad, ty, cellH, maxChars);
    } else {
      final isChat = tile.type == TileType.chat;
      final isNote = tile.type == TileType.note;
      final isStudy = tile.type == TileType.study;
      final noteEditing = isNote && tile.mode == 1;
      final richMd =
          ((isNote && !noteEditing) || isStudy || isChat) && tile.mdLines.isNotEmpty;

      // Verbosity slider (FireBot chat tile) — hidden unless hovered/recent.
      if (isChat && showVerb) {
        _paintSlider(canvas, size, pad, glyphW, ty);
        ty += cellH;
      }

      // Note mode hint line.
      if (isNote) {
        final hint = noteEditing
            ? 'EDIT  tap title save · F2 view'
            : 'VIEW  tap edit · F2 edit';
        _line(canvas, hint, pad, ty, _style(cellH, _dim));
        ty += cellH;
      }

      final inputReserved = (isChat && focused) ? 1 : 0;
      final contentLines = ((size.height - ty) / cellH).floor() - inputReserved;
      if (contentLines > 0) {
        if (richMd) {
          if (isChat) {
            // Chat: conversation as markdown, anchored to the latest message
            // (tile.scroll = lines scrolled up from the bottom). The input line
            // is pinned to the bottom; a blank head-room line above it keeps the
            // end of a long answer clearly separated from the draft prompt.
            final inputY = size.height - cellH;
            final contentBottom = inputY - cellH;
            final visible = ((contentBottom - ty) / cellH).floor();
            if (visible > 0) {
              final diff = tile.mdLines.length - visible;
              final maxScroll = diff < 0 ? 0 : diff;
              var scroll = tile.scroll;
              if (scroll > maxScroll) scroll = maxScroll;
              if (scroll < 0) scroll = 0;
              canvas.save();
              canvas.clipRect(Rect.fromLTWH(0, ty, size.width, contentBottom - ty));
              _paintMarkdown(
                canvas,
                size,
                pad,
                ty,
                cellH,
                maxChars,
                skip: maxScroll - scroll,
                bottom: contentBottom,
              );
              canvas.restore();
            }
            ty = inputY;
          } else {
            _paintMarkdown(canvas, size, pad, ty, cellH, maxChars);
          }
        } else {
          final List<String> shown;
          if (noteEditing) {
            final raw = tile.input.split('\n');
            final start = raw.length > contentLines ? raw.length - contentLines : 0;
            shown = raw.sublist(start);
          } else if (isChat) {
            final start =
                tile.lines.length > contentLines ? tile.lines.length - contentLines : 0;
            shown = tile.lines.sublist(start);
          } else {
            shown = tile.lines.length > contentLines
                ? tile.lines.take(contentLines).toList()
                : tile.lines.toList();
          }
          for (final line in shown) {
            final clipped = line.length > maxChars ? line.substring(0, maxChars) : line;
            _line(canvas, clipped, pad, ty, bodyStyle);
            ty += cellH;
          }
        }
      }

      // Figure thumbnails (long RAG answers).
      if (isChat) {
        ty = _paintFigures(canvas, size, pad, glyphW, ty, cellH);
      }

      // Draft input (chat) with a blinking cursor when focused.
      if (isChat && focused) {
        final inputLine = '> ${tile.input}';
        final clippedInput =
            inputLine.length > maxChars ? inputLine.substring(0, maxChars) : inputLine;
        _line(canvas, clippedInput, pad, ty, bodyStyle);
        if ((t * 2).floor().isEven) {
          final tp = TextPainter(
            text: TextSpan(text: clippedInput, style: bodyStyle),
            textDirection: TextDirection.ltr,
          )..layout();
          canvas.drawRect(
            Rect.fromLTWH(pad + tp.width, ty, glyphW - 2, cellH - 2),
            Paint()..color = theme.color,
          );
        }
      } else if (noteEditing && (t * 2).floor().isEven) {
        // Cursor at the actual (row, col) within the visible raw text.
        final raw = tile.input.split('\n');
        final cur = tile.cursor < 0
            ? 0
            : (tile.cursor > tile.input.length ? tile.input.length : tile.cursor);
        final before = tile.input.substring(0, cur);
        final row = '\n'.allMatches(before).length;
        final col = before.length - (before.lastIndexOf('\n') + 1);
        final shownCount = raw.length > contentLines ? contentLines : raw.length;
        if (shownCount > 0) {
          final start = raw.length - shownCount;
          final visRow = row - start;
          if (visRow >= 0 && visRow < shownCount) {
            final contentStart = ty - shownCount * cellH;
            final cx = pad + (col > maxChars ? maxChars : col) * glyphW;
            final cy = contentStart + visRow * cellH;
            canvas.drawRect(
              Rect.fromLTWH(cx, cy, glyphW - 2, cellH - 2),
              Paint()..color = theme.color,
            );
          }
        }
      }
    }
  }

  TextStyle _style(double fontSize, Color color) => TextStyle(
        fontFamily: 'ShareTechMono',
        fontSize: fontSize,
        color: color,
        height: 1.0,
      );

  Color get _dim => theme.color.withValues(alpha: 0.55);

  int _maxChars(Size size, double pad, double glyphW) {
    final n = ((size.width - pad * 2) / glyphW).floor();
    return n < 1 ? 1 : n;
  }

  void _line(Canvas canvas, String text, double x, double y, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x, y));
  }

  // ---- Rich markdown rendering (study tiles + note view mode) ----

  Color get _bodyColor => theme.color.withValues(alpha: 0.78);
  Color get _boldColor => theme.color.withValues(alpha: 1.0);
  Color get _italicColor => theme.color.withValues(alpha: 0.66);
  Color get _codeColor => theme.color.withValues(alpha: 0.9);
  Color get _accent => _deriveAccent(theme.color);

  Color _deriveAccent(Color c) {
    final hsl = HSLColor.fromColor(c);
    return HSLColor.fromAHSL(
      hsl.alpha,
      (hsl.hue + 60) % 360,
      (hsl.saturation * 1.05).clamp(0.0, 1.0).toDouble(),
      (hsl.lightness * 0.85 + 0.12).clamp(0.0, 1.0).toDouble(),
    ).toColor();
  }

  double _paintMarkdown(
    Canvas canvas,
    Size size,
    double pad,
    double ty,
    double cellH,
    int maxChars, {
    int skip = 0,
    double? bottom,
  }) {
    final limit = bottom ?? (size.height - cellH * 0.5);
    var y = ty;
    tile.links.clear();
    for (var i = skip; i < tile.mdLines.length; i++) {
      if (y > limit) break;
      y = _paintMdLine(canvas, tile.mdLines[i], size, pad, y, cellH, maxChars);
    }
    return y;
  }

  double _paintMdLine(
    Canvas canvas,
    MdLine line,
    Size size,
    double pad,
    double y,
    double cellH,
    int maxChars,
  ) {
    if (line.block == MdBlock.rule) {
      final n = maxChars < 8 ? 8 : (maxChars > 48 ? 48 : maxChars);
      _line(canvas, '─' * n, pad, y, _style(cellH, _dim));
      return y + cellH;
    }
    if (line.block == MdBlock.image) {
      return _paintImage(canvas, line, size, pad, y, cellH);
    }
    final scale = _headingScale(line.block);
    final built = _buildLine(line, cellH, scale);
    final availW = size.width - pad * 2;
    final tp = TextPainter(text: built.$1, textDirection: TextDirection.ltr)
      ..layout(maxWidth: line.block == MdBlock.codeBlock ? double.infinity : availW);
    if (_isHeading(line.block)) {
      final w = tp.width > availW ? availW : tp.width;
      canvas.drawRect(
        Rect.fromLTWH(pad, y + tp.height - cellH * 0.05, w, cellH * 0.06),
        Paint()..color = _accent.withValues(alpha: 0.5),
      );
    }
    if (line.block == MdBlock.codeBlock) {
      canvas.drawRect(
        Rect.fromLTWH(pad, y, size.width - pad * 2, tp.height),
        Paint()..color = theme.color.withValues(alpha: 0.06),
      );
    }
    tp.paint(canvas, Offset(pad, y));
    for (final l in built.$2) {
      final boxes = tp.getBoxesForSelection(
        TextSelection(baseOffset: l.start, extentOffset: l.end),
      );
      for (final b in boxes) {
        final r = b.toRect();
        tile.links.add(LinkHit(
          Rect.fromLTWH(pad + r.left, y + r.top, r.width, r.height),
          l.href,
        ));
      }
    }
    return y + tp.height + cellH * 0.22;
  }

  double _paintImage(
    Canvas canvas,
    MdLine line,
    Size size,
    double pad,
    double y,
    double cellH,
  ) {
    final url = line.imageUrl ?? '';
    final alt = line.marker;
    final img = tile.images[url];
    final maxW = size.width - pad * 2;
    final maxH = cellH * 10;
    if (img != null && img.width > 0 && img.height > 0) {
      var s = maxW / img.width;
      if (img.height * s > maxH) s = maxH / img.height;
      final w = img.width * s;
      final h = img.height * s;
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        Rect.fromLTWH(pad, y, w, h),
        Paint(),
      );
      canvas.drawRect(
        Rect.fromLTWH(pad, y, w, h),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..color = theme.color.withValues(alpha: 0.4),
      );
      return y + h + cellH * 0.3;
    }
    _line(canvas, '▨ ${alt.isNotEmpty ? alt : url}', pad, y, _style(cellH, _dim));
    return y + cellH;
  }

  (TextSpan, List<({int start, int end, String href})>) _buildLine(
    MdLine line,
    double cellH,
    double scale,
  ) {
    final fontSize = cellH * scale;
    Color baseColor;
    if (_isHeading(line.block)) {
      baseColor = _accent;
    } else if (line.block == MdBlock.quote) {
      baseColor = _dim;
    } else if (line.block == MdBlock.codeBlock) {
      baseColor = _codeColor;
    } else {
      baseColor = _bodyColor;
    }
    final children = <InlineSpan>[];
    final links = <({int start, int end, String href})>[];
    var offset = 0;
    void add(String text, TextStyle style, {String? href}) {
      children.add(TextSpan(text: text, style: style));
      if (href != null && href.isNotEmpty) {
        links.add((start: offset, end: offset + text.length, href: href));
      }
      offset += text.length;
    }

    if (line.block == MdBlock.quote) {
      add(
        '│ ',
        TextStyle(
          fontFamily: 'ShareTechMono',
          fontSize: fontSize,
          color: _accent.withValues(alpha: 0.7),
        ),
      );
    } else if (line.block == MdBlock.listItem && line.marker.isNotEmpty) {
      add(
        '  ${line.marker} ',
        TextStyle(fontFamily: 'ShareTechMono', fontSize: fontSize, color: _accent),
      );
    }
    for (final s in line.spans) {
      add(s.text, _spanStyle(s, fontSize), href: s.link ? (s.href ?? '') : null);
    }
    return (
      TextSpan(
        style: TextStyle(
          fontFamily: 'ShareTechMono',
          fontSize: fontSize,
          height: 1.0,
          color: baseColor,
        ),
        children: children,
      ),
      links,
    );
  }

  TextStyle _spanStyle(MdSpan s, double fontSize) {
    Color? color;
    if (s.link) {
      color = _accent;
    } else if (s.code) {
      color = _codeColor;
    } else if (s.bold) {
      color = _boldColor;
    } else if (s.italic) {
      color = _italicColor;
    }
    return TextStyle(
      fontFamily: 'ShareTechMono',
      fontSize: fontSize,
      color: color,
      fontStyle: s.italic ? FontStyle.italic : FontStyle.normal,
      fontWeight: s.bold ? FontWeight.w700 : FontWeight.w400,
      decoration: s.link ? TextDecoration.underline : TextDecoration.none,
      decorationColor: s.link ? _accent : null,
      backgroundColor: s.code ? theme.color.withValues(alpha: 0.12) : null,
    );
  }

  /// Investigations dashboard: ranked list (browse) or a detail read view.
  void _paintInvestigations(
    Canvas canvas,
    Size size,
    double pad,
    double ty,
    double cellH,
    int maxChars,
  ) {
    if (tile.mode == 1 || tile.mode == 3) {
      final hint = tile.mode == 1
          ? '↑↓/drag scroll · ←/→ prev/next · esc/tap-title back'
          : '↑↓/drag scroll · esc/tap-title back';
      _line(canvas, hint, pad, ty, _style(cellH, _dim));
      ty += cellH;
      _paintMarkdown(canvas, size, pad, ty, cellH, maxChars, skip: tile.scroll);
    } else {
      final hint = tile.mode == 2
          ? '↑↓ move · space toggle · enter compare · esc back'
          : '↑↓ select · enter detail · c compare · click to open';
      _line(canvas, hint, pad, ty, _style(cellH, _dim));
      ty += cellH;
      final contentLines = ((size.height - ty) / cellH).floor();
      if (contentLines > 0 && tile.lines.isNotEmpty) {
        var start = tile.selection - (contentLines ~/ 2);
        if (start < 0) start = 0;
        if (start + contentLines > tile.lines.length) {
          start = tile.lines.length - contentLines;
        }
        if (start < 0) start = 0;
        final end = start + contentLines > tile.lines.length
            ? tile.lines.length
            : start + contentLines;
        for (var i = start; i < end; i++) {
          final sel = i == tile.selection;
          final label = sel ? '▶ ${tile.lines[i]}' : '  ${tile.lines[i]}';
          final clipped =
              label.length > maxChars ? label.substring(0, maxChars) : label;
          _line(canvas, clipped, pad, ty, _style(cellH, sel ? theme.color : _dim));
          ty += cellH;
        }
      }
    }
  }

  void _paintGraph(Canvas canvas, Size size, double pad, double ty, double cellH) {
    final g = tile.graph;
    if (g == null) {
      _line(canvas, '(no notes yet — /note to create)', pad, ty, _style(cellH, _dim));
      return;
    }
    _line(canvas, 'click node → open note · esc close', pad, ty, _style(cellH, _dim));
    ty += cellH;
    if (g.edges.isNotEmpty) {
      final edgePaint = Paint()
        ..color = theme.color.withValues(alpha: 0.35)
        ..strokeWidth = 1.0;
      for (final e in g.edges) {
        final a = _graphNode(e.source);
        final b = _graphNode(e.target);
        if (a == null || b == null) continue;
        canvas.drawLine(
          Offset(pad + a.x, ty + a.y),
          Offset(pad + b.x, ty + b.y),
          edgePaint,
        );
      }
    }
    for (final n in g.nodes) {
      final c = Offset(pad + n.x, ty + n.y);
      canvas.drawCircle(c, n.radius, Paint()..color = theme.color.withValues(alpha: 0.12));
      canvas.drawCircle(
        c,
        n.radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = theme.color.withValues(alpha: 0.9),
      );
      final tp = TextPainter(
        text: TextSpan(text: n.label, style: _style(cellH * 0.85, theme.color)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(pad + n.x - tp.width / 2, ty + n.y + n.radius + 2));
    }
  }

  GraphNode? _graphNode(String id) {
    final g = tile.graph;
    if (g == null) return null;
    for (final n in g.nodes) {
      if (n.id == id) return n;
    }
    return null;
  }

  bool _isHeading(MdBlock b) =>
      b == MdBlock.heading1 ||
      b == MdBlock.heading2 ||
      b == MdBlock.heading3 ||
      b == MdBlock.heading4 ||
      b == MdBlock.heading5 ||
      b == MdBlock.heading6;

  double _headingScale(MdBlock b) {
    switch (b) {
      case MdBlock.heading1:
        return 1.35;
      case MdBlock.heading2:
        return 1.22;
      case MdBlock.heading3:
        return 1.12;
      case MdBlock.heading4:
        return 1.05;
      default:
        return 1.0;
    }
  }

  /// CRT-styled verbosity slider — three labels (selected bracketed) plus an
  /// unclickable [CTRL+L] hint at the far right.
  void _paintSlider(Canvas canvas, Size size, double pad, double glyphW, double y) {
    final trackLeft = pad;
    final trackW = (size.width - pad * 2) * kSliderTrackFraction;
    final third = trackW / 3;
    for (var i = 0; i < kVerbosityLabels.length; i++) {
      final selected = tile.verbosity == i;
      final label =
          selected ? '[${kVerbosityLabels[i]}]' : ' ${kVerbosityLabels[i]} ';
      final style = _style(cellH, selected ? theme.color : _dim);
      final tp = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      final x = trackLeft + i * third + (third - tp.width) / 2;
      tp.paint(canvas, Offset(x, y));
    }
    final hint = TextPainter(
      text: TextSpan(
        text: '[CTRL+L]',
        style: _style(cellH, theme.color.withValues(alpha: 0.4)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    hint.paint(canvas, Offset(size.width - pad - hint.width, y));
  }

  /// Theme selector — the theme names, the active one bracketed.
  void _paintThemeSelector(Canvas canvas, Size size, double pad, double glyphW, double y) {
    final trackLeft = pad;
    final trackW = size.width - pad * 2;
    final seg = trackW / engineThemes.length;
    for (var i = 0; i < engineThemes.length; i++) {
      final selected = themeIndex == i;
      final name = engineThemes[i].name;
      final label = selected ? '[$name]' : name;
      final style = _style(cellH, selected ? theme.color : _dim);
      final tp = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      final x = trackLeft + i * seg + (seg - tp.width) / 2;
      tp.paint(canvas, Offset(x, y));
    }
  }

  /// Glass selector — a compact block-char bar showing the frost/glass amount.
  void _paintTransparencySelector(Canvas canvas, Size size, double pad, double glyphW, double y) {
    final pct = (transparency * 100).round();
    const barCells = 10; // compact fixed-width bar
    final filled = (barCells * transparency).round().clamp(0, barCells);
    final bar = '█' * filled + '░' * (barCells - filled);
    _line(canvas, 'GLASS $bar $pct%', pad, y, _style(cellH, theme.color));
  }

  /// Draw figure thumbnails (long RAG answers) below the text; returns new ty.
  double _paintFigures(
    Canvas canvas,
    Size size,
    double pad,
    double glyphW,
    double ty,
    double cellH,
  ) {
    if (tile.figureImages.isEmpty) return ty;
    final maxW = size.width - pad * 2;
    final maxH = size.height * 0.4;
    for (final img in tile.figureImages) {
      final scale = (maxW / img.width) < (maxH / img.height)
          ? (maxW / img.width)
          : (maxH / img.height);
      final dw = img.width * scale;
      final dh = img.height * scale;
      if (ty + dh > size.height - cellH) break; // no room left
      final dst = Rect.fromLTWH(pad, ty, dw, dh);
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        dst,
        Paint(),
      );
      canvas.drawRect(
        dst,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..color = theme.color.withValues(alpha: 0.4),
      );
      ty += dh + cellH * 0.3;
    }
    return ty;
  }

  @override
  bool shouldRepaint(covariant TilePainter old) =>
      old.t != t ||
      old.tile != tile ||
      old.focused != focused ||
      old.theme != theme ||
      old.cellH != cellH ||
      old.terminal != terminal ||
      old.showVerb != showVerb ||
      old.transparency != transparency ||
      old.showTheme != showTheme ||
      old.showTransparency != showTransparency ||
      old.themeIndex != themeIndex ||
      old.glassImage != glassImage ||
      old.tileRect != tileRect;
}
