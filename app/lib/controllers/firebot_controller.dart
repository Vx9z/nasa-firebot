import 'package:flutter/foundation.dart';

import '../services/ai_service.dart';
import 'curriculum_controller.dart';

/// A single chat bubble.
class ChatMessage {
  final bool isUser;
  final String text;
  final List<String> sources;
  final List<String> figureUrls;
  final bool markdown;
  const ChatMessage({
    required this.isUser,
    required this.text,
    this.sources = const [],
    this.figureUrls = const [],
    this.markdown = false,
  });
}

/// FireBot chat state: the message thread, online status, and the "texting"
/// feel (answers arrive as short, broken-up messages).
class FireBotController extends ChangeNotifier {
  FireBotController._() {
    refreshOnline();
  }

  static final FireBotController instance = FireBotController._();

  final AiService ai = AiService();
  final List<ChatMessage> _messages = [];

  bool _open = false; // floating chatbox expanded?
  bool _online = false;
  bool _thinking = false;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get open => _open;
  bool get online => _online;
  bool get thinking => _thinking;

  void toggle() {
    _open = !_open;
    if (_open) refreshOnline();
    notifyListeners();
  }

  void close() {
    if (_open) {
      _open = false;
      notifyListeners();
    }
  }

  Future<void> refreshOnline() async {
    final v = await ai.isOnline();
    if (v != _online) {
      _online = v;
      notifyListeners();
    }
  }

  /// Send a message; FireBot replies as short messages (or one detailed answer).
  Future<void> send(String text, {required bool concise}) async {
    final q = text.trim();
    if (q.isEmpty || _thinking) return;
    _messages.add(ChatMessage(isUser: true, text: q));
    _thinking = true;
    notifyListeners();

    final c = CurriculumController.instance;
    final ctx = c.loaded ? '${c.currentLesson.id} ${c.currentLesson.title}' : null;

    try {
      if (concise) {
        final answer = await ai.askConcise(q, lessonContext: ctx);
        if (answer.isEmpty) {
          _messages.add(const ChatMessage(isUser: false, text: '⚠️ No response — is the FireBot backend running?'));
        } else {
          for (final part in _split(answer)) {
            _messages.add(ChatMessage(isUser: false, text: part));
            notifyListeners();
            await Future.delayed(const Duration(milliseconds: 350)); // typing feel
          }
        }
      } else {
        // Detailed: one full answer with citations + figures (no texting split).
        final result = await ai.askDetailed(q, lessonContext: ctx);
        _messages.add(
          result.text.isEmpty
              ? const ChatMessage(isUser: false, text: '⚠️ No response — is the FireBot backend running?')
              : ChatMessage(isUser: false, text: result.text, sources: result.sources, figureUrls: result.figureUrls, markdown: true),
        );
      }
    } catch (_) {
      _messages.add(const ChatMessage(isUser: false, text: '⚠️ FireBot is offline — start the RAG backend to chat.'));
    } finally {
      _thinking = false;
      notifyListeners();
    }
  }

  List<String> _split(String answer) {
    final t = answer.trim();
    if (t.isEmpty) return const ['…'];
    final raw = t.split(RegExp(r'(?<=[.!?])\s+'));
    final out = <String>[];
    final buf = StringBuffer();
    for (final s in raw) {
      if (buf.isNotEmpty && buf.length + s.length > 200) {
        out.add(buf.toString().trim());
        buf.clear();
      }
      if (buf.isNotEmpty) buf.write(' ');
      buf.write(s);
    }
    if (buf.isNotEmpty) out.add(buf.toString().trim());
    return out;
  }
}
