import 'lesson.dart';

/// A module (one "constellation") containing a sequence of lessons.
class Module {
  final String id;             // "0"
  final String title;          // "Foundations" (derived from the lesson files)
  final List<Lesson> lessons;

  const Module({
    required this.id,
    required this.title,
    required this.lessons,
  });
}
