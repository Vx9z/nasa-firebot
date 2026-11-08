import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/graph.dart';
import '../models/note.dart';

/// The "vault" — holds every note. Notes are added/edited/deleted by the user
/// and persisted to local storage (via shared_preferences) so they survive
/// reloads without touching the filesystem.
class VaultService {
  final Map<String, Note> _notes = {};
  static const _prefsKey = 'vault_notes';

  Note? get(String title) => _notes[title];
  bool has(String title) => _notes.containsKey(title);
  List<String> get allTitles => _notes.keys.toList();

  /// Load notes persisted from a previous session (idempotent).
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_prefsKey);
      if (json == null) return;
      final map = jsonDecode(json) as Map<String, dynamic>;
      _notes.clear();
      for (final e in map.entries) {
        _notes[e.key] = Note(title: e.key, content: e.value as String);
      }
    } catch (_) {
      // Corrupt or missing store — start empty.
    }
  }

  void _persist() {
    final map = {for (final n in _notes.values) n.title: n.content};
    SharedPreferences.getInstance()
        .then((prefs) => prefs.setString(_prefsKey, jsonEncode(map)));
  }

  /// Create a note (or overwrite if the title already exists).
  void addNote(Note note) {
    _notes[note.title] = note;
    _persist();
  }

  /// Remove a note.
  void deleteNote(String title) {
    _notes.remove(title);
    _persist();
  }

  /// Replace a note's content (keeps the title).
  void updateNote(String title, String content) {
    if (_notes.containsKey(title)) {
      _notes[title] = Note(title: title, content: content);
      _persist();
    }
  }

  /// Character-count boundaries for the 4 node-size stages.
  /// stage 0: < 50 · stage 1: 50–199 · stage 2: 200–999 · stage 3: ≥ 1000
  static const sizeThresholds = [50, 200, 1000];

  /// Map a note's character count to a discrete size stage (0..3).
  static int sizeFor(int charCount) {
    var s = 0;
    for (final t in sizeThresholds) {
      if (charCount >= t) s++;
    }
    return s;
  }

  /// Derive the notes + links as a [Graph] (each note = node, each `[[link]]` = edge).
  Graph toGraph() {
    final nodes = [
      for (final note in _notes.values)
        GraphNode(id: note.title, label: note.title, size: sizeFor(note.content.length)),
    ];
    final ids = _notes.keys.toSet();
    final edges = <GraphEdge>[];
    for (final note in _notes.values) {
      for (final link in note.links) {
        if (ids.contains(link)) {
          edges.add(GraphEdge(source: note.title, target: link));
        }
      }
    }
    return Graph(nodes: nodes, edges: edges);
  }

}