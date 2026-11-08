import 'package:flutter/services.dart';

import '../models/lesson.dart';
import '../models/module.dart';

/// Discovers and loads the curriculum from `assets/lessons/*.md` at runtime.
/// The course is self-describing: the filename encodes the lesson id, the `#`
/// line is the title, and the `**Module:**` line groups lessons into modules.
/// Adding a new course = dropping new markdown files into the folder — no Dart
/// changes required.
class CurriculumService {
  static const assetRoot = 'assets/lessons/';

  Future<List<Module>> load() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final files = manifest
        .listAssets()
        .where((k) => k.startsWith(assetRoot) && k.endsWith('.md'))
        .toList()
      ..sort();

    final lessons = <Lesson>[];
    final moduleTitles = <String, String>{};
    for (final f in files) {
      final content = await rootBundle.loadString(f);
      final lesson = _parse(f, content);
      lessons.add(lesson);
      final mt = _moduleTitle(content);
      if (mt != null) moduleTitles.putIfAbsent(lesson.moduleId, () => mt);
    }

    final grouped = <String, List<Lesson>>{};
    for (final l in lessons) {
      grouped.putIfAbsent(l.moduleId, () => []).add(l);
    }
    final ids = grouped.keys.toList()..sort(_numCompare);

    return [
      for (final id in ids)
        Module(id: id, title: moduleTitles[id] ?? 'Module $id', lessons: grouped[id]!),
    ];
  }

  /// Load a single lesson's markdown content.
  Future<String> loadContent(Lesson lesson) => rootBundle.loadString(lesson.file);

  Lesson _parse(String file, String content) {
    final name = file.split('/').last; // "0.1-matter-atoms-molecules.md"
    final id = name.split('-').first; // "0.1"
    final fallback = name.substring(id.length + 1, name.length - 3).replaceAll('-', ' ');
    return Lesson(
      id: id,
      moduleId: id.split('.').first,
      title: _title(content) ?? fallback,
      file: file,
      papers: const [],
    );
  }

  String? _title(String content) {
    final m = RegExp(r'^#\s+.+$', multiLine: true).firstMatch(content);
    if (m == null) return null;
    var t = m.group(0)!;
    t = t.replaceFirst(RegExp(r'^#\s+'), '');
    t = t.replaceFirst(RegExp(r'^\d+\.\d+\s+'), '');
    return t.trim();
  }

  String? _moduleTitle(String content) {
    final m = RegExp(r'\*\*Module:\*\*\s*([^\n·]+)').firstMatch(content);
    if (m == null) return null;
    var t = m.group(1)!.trim();
    t = t.replaceFirst(RegExp(r'^[\d.]+\s*[—–-]\s*'), '');
    return t.trim();
  }

  int _numCompare(String a, String b) =>
      (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0);
}

