/// A lesson (one "star" in a constellation) with 4 levels of abstraction.
class Lesson {
  final String id;            // "0.1"
  final String moduleId;      // "0"
  final String title;         // "Matter, atoms & molecules"
  final String file;          // asset filename, e.g. "0.1-matter-atoms-molecules.md"
  final List<String> papers;  // ["14", "28"] — empty for foundational (⚛)

  const Lesson({
    required this.id,
    required this.moduleId,
    required this.title,
    required this.file,
    required this.papers,
  });
}
