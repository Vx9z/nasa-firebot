/// A note — a markdown document with optional `[[wikilinks]]` to other notes.
class Note {
  final String title;
  final String content;

  const Note({required this.title, required this.content});

  /// Titles referenced via `[[wikilink]]` in the content.
  List<String> get links => RegExp(r'\[\[([^\]]+)\]\]')
      .allMatches(content)
      .map((m) => m.group(1)!.trim())
      .toList();
}
