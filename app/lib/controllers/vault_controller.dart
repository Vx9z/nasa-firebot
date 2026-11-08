import 'package:flutter/foundation.dart';

import '../models/note.dart';
import '../services/vault_service.dart';

/// Browser-like navigation: a root directory + open note tabs.
///
/// NOTE: singleton for the first pass — will migrate to Riverpod (settled in
/// ARCHITECTURE.md) once the note system stabilizes.
class VaultController extends ChangeNotifier {
  VaultController._();
  static final VaultController instance = VaultController._();

  final VaultService vault = VaultService();
  final List<String> _tabs = [];
  String? _active; // null = showing the root directory

  List<String> get tabs => List.unmodifiable(_tabs);
  String? get active => _active;
  bool get isRoot => _active == null;
  Note? get activeNote => _active == null ? null : vault.get(_active!);

  void goRoot() {
    _active = null;
    notifyListeners();
  }

  void openNote(String title) {
    if (!vault.has(title)) return;
    if (!_tabs.contains(title)) _tabs.add(title);
    _active = title;
    notifyListeners();
  }

  void openLink(String title) {
    if (title.isEmpty) return;
    if (!vault.has(title)) {
      vault.addNote(Note(title: title, content: '')); // create missing note (Obsidian-style)
    }
    openNote(title);
  }

  void closeTab(String title) {
    _tabs.remove(title);
    if (_active == title) _active = _tabs.isEmpty ? null : _tabs.last;
    notifyListeners();
  }

  /// Create a note (if the title is free) and open it.
  void addNote(String title) {
    if (title.isEmpty) return;
    if (!vault.has(title)) {
      vault.addNote(Note(title: title, content: ''));
    }
    openNote(title);
  }

  /// Delete a note, closing its tab if it was open.
  void deleteNote(String title) {
    vault.deleteNote(title);
    _tabs.remove(title);
    if (_active == title) _active = _tabs.isEmpty ? null : _tabs.last;
    notifyListeners();
  }

  /// Persist a note's edited content.
  void saveNote(String title, String content) {
    vault.updateNote(title, content);
    notifyListeners();
  }
}
