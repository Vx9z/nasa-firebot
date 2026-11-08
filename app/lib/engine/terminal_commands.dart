import '../controllers/curriculum_controller.dart';
import '../controllers/vault_controller.dart';
import '../models/lesson.dart';
import 'themes.dart';
import 'wm.dart';

/// Turns a typed command into a [CommandOutcome]: text echoed into the
/// terminal, plus (optionally) a tile to open/focus.
class TerminalCommands {
  /// Called when the `theme` command switches themes.
  final void Function(int index)? onThemeChanged;

  TerminalCommands({this.onThemeChanged});

  Future<CommandOutcome> run(String command) async {
    final parts = command.trim().split(RegExp(r'\s+'));
    final verb = parts.isEmpty ? '' : parts.first.toLowerCase();
    final rest = parts.length > 1 ? parts.sublist(1).join(' ') : '';

    switch (verb) {
      case 'help':
        return CommandOutcome(_help);
      case 'open':
        return _open(rest);
      case 'theme':
        return CommandOutcome(_theme(rest));
      case 'list':
        return CommandOutcome(_list());
      default:
        return CommandOutcome(['unknown: $verb — type /help']);
    }
  }

  static const _help = [
    'commands (prefix with /):',
    '  /help            — this list',
    '  /open <lesson>   — open a lesson tile',
    '  /lesson          — browse the course (↑↓, → expand, enter open)',
    '  /graph           — note graph (click node to open)',
    '  /investigate     — ranked fire-safety investigations (↑↓, enter)',
    '  /compare         — compare two investigations side by side',
    '  /notes           — browse + create notes (↑↓, enter, N)',
    '  /ask [question]  — open FireBot, then chat in its tile',
    '  /theme [name]    — switch theme (bare = picker, then ←/→)',
    '  /transparency    — tile glass level (then ↑/↓)',
    '  /list            — list lessons + notes',
    '  /close           — close the focused tile',
    '  /windows         — close every tile',
    '  \\ (no tiles)     — spawn a terminal',
    '  F2               — note view/edit toggle (auto-save)',
    '  Ctrl+← / Ctrl+→  — switch focus between tiles',
  ];

  Future<CommandOutcome> _open(String q) async {
    if (q.isEmpty) return const CommandOutcome(['usage: open <lesson id or title>']);
    final c = CurriculumController.instance;
    Lesson? match;
    for (final l in c.allLessons) {
      if (l.id.toLowerCase() == q.toLowerCase() ||
          l.title.toLowerCase().contains(q.toLowerCase())) {
        match = l;
        break;
      }
    }
    if (match == null) return CommandOutcome(['no lesson matching: $q']);
    c.openLesson(match.id);
    try {
      final md = await c.curriculum.loadContent(match);
      return CommandOutcome(
        ['opened lesson: ${match.title}'],
        tile: TileSpec(
          type: TileType.study,
          title: 'LESSON · ${match.title}',
          lines: markdownToLines(md),
          raw: md,
        ),
      );
    } catch (_) {
      return CommandOutcome(['⚠️ could not load lesson: ${match.title}']);
    }
  }

  List<String> _theme(String name) {
    final idx = engineThemes.indexWhere(
      (t) => t.name.toLowerCase() == name.trim().toLowerCase(),
    );
    if (idx < 0) {
      return ['themes: ${engineThemes.map((t) => t.name).join(', ')}'];
    }
    onThemeChanged?.call(idx);
    return ['theme → ${engineThemes[idx].name}'];
  }

  List<String> _list() {
    final lessons = CurriculumController.instance.allLessons;
    final notes = VaultController.instance.vault.allTitles;
    return [
      'lessons (${lessons.length}):',
      for (final l in lessons.take(6)) '  • ${l.title}',
      'notes (${notes.length}):',
      for (final n in notes.take(6)) '  • $n',
    ];
  }

  /// Markdown → CRT text: headings get underlines, lists get bullets,
  /// blockquotes get a bar, and inline markup (`**`, `*`, `` ` ``, links) is
  /// stripped so nothing renders as raw `*`.
  static List<String> markdownToLines(String md) {
    final out = <String>[];
    for (final rawLine in md.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        out.add('');
        continue;
      }
      // Horizontal rule.
      if (line == '---' || line == '***' || line == '___') {
        out.add('─' * 24);
        continue;
      }
      // Headings: uppercase + underline.
      final h = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(line);
      if (h != null) {
        final text = _mdInline(h.group(2)!);
        out.add(text.toUpperCase());
        final len = text.length < 3 ? 3 : (text.length > 40 ? 40 : text.length);
        out.add('─' * len);
        continue;
      }
      // Blockquote.
      if (line.startsWith('>')) {
        out.add('│ ${_mdInline(line.substring(1).trim())}');
        continue;
      }
      // Unordered list.
      final ul = RegExp(r'^[-*+]\s+(.*)$').firstMatch(line);
      if (ul != null) {
        out.add('• ${_mdInline(ul.group(1)!)}');
        continue;
      }
      // Ordered list.
      final ol = RegExp(r'^(\d+)\.\s+(.*)$').firstMatch(line);
      if (ol != null) {
        out.add('${ol.group(1)}. ${_mdInline(ol.group(2)!)}');
        continue;
      }
      out.add(_mdInline(line));
    }
    return out.isEmpty ? const ['(empty)'] : out;
  }

  /// Strip inline markdown (bold/italic/code/links) from a span of text.
  static String _mdInline(String s) => s
      .replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1')
      .replaceAll(RegExp(r'__([^_]+)__'), r'$1')
      .replaceAll(RegExp(r'\*([^*]+)\*'), r'$1')
      .replaceAll(RegExp(r'`([^`]+)`'), r'$1')
      .replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), '')
      .replaceAll(RegExp(r'\[([^\]]+)\]\([^)]*\)'), r'$1')
      .replaceAll(RegExp(r'\[\[([^\]]+)\]\]'), r'$1');
}
