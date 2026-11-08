import 'package:flutter/foundation.dart';

import '../models/lesson.dart';
import '../models/module.dart';
import '../services/curriculum_service.dart';

/// Curriculum state: the discovered course, current lesson, per-lesson progress
/// (0–4 levels), and navigation between the constellation and the lesson detail.
class CurriculumController extends ChangeNotifier {
  CurriculumController._();
  static final CurriculumController instance = CurriculumController._();

  final CurriculumService curriculum = CurriculumService();

  List<Module> _modules = [];
  List<Lesson> _all = [];
  bool _loaded = false;
  int _index = 0;
  final Map<String, int> _progress = {};
  bool _showingLesson = false;

  bool get loaded => _loaded;
  List<Module> get modules => _modules;
  List<Lesson> get allLessons => _all;
  Lesson get currentLesson => _all[_index];
  Module get currentModule => _modules.firstWhere((m) => m.id == currentLesson.moduleId);
  bool get showingLesson => _showingLesson;
  int get lessonCount => _all.length;

  /// Number of the lesson's 4 abstraction levels completed (0–4).
  int progressOf(String id) => _progress[id] ?? 0;

  /// Discovers + loads the course from the asset files (idempotent).
  Future<void> load() async {
    if (_loaded) return;
    try {
      final modules = await curriculum.load();
      _modules = modules;
      _all = [for (final m in modules) ...m.lessons];
      _loaded = true;
      _index = 0;
    } catch (_) {
      // Assets unavailable (e.g. in some tests) — leave the course empty.
    }
    notifyListeners();
  }

  void selectModule(String id) {
    final idx = _modules.indexWhere((m) => m.id == id);
    if (idx < 0) return;
    final m = _modules[idx];
    if (m.lessons.isEmpty) return;
    final i = _all.indexWhere((l) => l.id == m.lessons.first.id);
    if (i >= 0) _index = i;
    _showingLesson = false;
    notifyListeners();
  }

  void openLesson(String id) {
    final i = _all.indexWhere((l) => l.id == id);
    if (i >= 0) _index = i;
    _showingLesson = true;
    notifyListeners();
  }

  void showConstellation() {
    _showingLesson = false;
    notifyListeners();
  }

  void next() {
    if (_index < _all.length - 1) _index++;
    notifyListeners();
  }

  void previous() {
    if (_index > 0) _index--;
    notifyListeners();
  }

  /// Complete one of the 4 levels; when all 4 are done, advance to the next lesson.
  void completeLevel() {
    final id = currentLesson.id;
    final p = (_progress[id] ?? 0) + 1;
    _progress[id] = p > 4 ? 4 : p;
    if (_progress[id]! >= 4 && _index < _all.length - 1) _index++;
    notifyListeners();
  }
}

