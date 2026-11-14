/// The startup script, paced by `(pause N)` markers (N = milliseconds).
const String startupScript = '> INITIALIZING...\n'
    '(pause 350)\n'
    '> CRT MONITOR v0.1\n'
    '> [OK] STARFIELD\n'
    '(pause 200)\n'
    '> [OK] CRT FILTERS\n'
    '> [OK] TERMINAL LAYER\n'
    '(pause 250)\n'
    '> ALL SYSTEMS NOMINAL\n'
    '(pause 400)\n'
    '> type /help · Ctrl+←/→ cycle tiles\n';

/// Layer 3 — the text interface: a startup script + a free-form multi-line
/// draft + command history. Enter inserts a newline; a line starting with `/`
/// is run as a command.
class Terminal {
  final List<List<Object>> _segments; // [String chunk, double pauseSeconds]
  double elapsed = 0;
  String input = '';
  final List<String> history = [];

  Terminal(String script) : _segments = _parse(script);

  static List<List<Object>> _parse(String script) {
    final segments = <List<Object>>[];
    final re = RegExp(r'\(pause\s+(\d+)\)');
    var pos = 0;
    for (final m in re.allMatches(script)) {
      final chunk = script.substring(pos, m.start);
      if (chunk.isNotEmpty) {
        segments.add([chunk, int.parse(m.group(1)!) / 1000.0]);
      }
      pos = m.end;
      if (pos < script.length && script[pos] == '\n') pos++;
    }
    final tail = script.substring(pos);
    if (tail.isNotEmpty) segments.add([tail, 0.0]);
    return segments;
  }

  /// Script text revealed so far (chunks are instant, pauses consume time).
  String revealed() {
    var acc = 0.0;
    final buf = StringBuffer();
    for (final seg in _segments) {
      if (acc <= elapsed) buf.write(seg[0] as String);
      acc += seg[1] as double;
      if (acc > elapsed) break;
    }
    return buf.toString();
  }

  void step(double dt) => elapsed += dt;

  void key(String ch) => input += ch;

  void backspace() =>
      input = input.isNotEmpty ? input.substring(0, input.length - 1) : '';

  void deleteWord() {
    final s = input.trimRight();
    final i = s.lastIndexOf(' ');
    input = i != -1 ? s.substring(0, i) : '';
  }

  void clearLine() => input = '';

  /// Enter: if the last line starts with `/`, submit it as a command (echo it
  /// and return it); otherwise append a newline (free-form multi-line text).
  String? enter() {
    final lines = input.split('\n');
    final last = lines.isNotEmpty ? lines.last.trim() : '';
    if (last.startsWith('/')) {
      final cmd = last.substring(1).trim();
      lines.removeLast();
      input = lines.join('\n');
      if (cmd.isNotEmpty) history.add('/ $cmd');
      return cmd.isEmpty ? null : cmd;
    }
    input += '\n';
    return null;
  }
}
