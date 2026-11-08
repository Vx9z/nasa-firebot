import 'dart:convert';

import 'package:http/http.dart' as http;

/// A detailed (RAG) answer — full text plus citations and figure image URLs.
class AiAnswer {
  final String text;
  final List<String> sources;
  final List<String> figureUrls;
  const AiAnswer({required this.text, this.sources = const [], this.figureUrls = const []});
}

/// FireBot's brain — talks to the RAG web app (Flask backend), which is backed
/// by Gemini. No local Ollama dependency.
class AiService {
  /// Backend base URL. Override at build time with:
  ///   flutter build web --dart-define=RAG_URL=https://your-backend.onrender.com
  static const ragUrl = String.fromEnvironment(
    'RAG_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  /// Green if the RAG backend responds, grey otherwise.
  Future<bool> isOnline() async {
    try {
      final r = await http
          .get(Uri.parse('$ragUrl/health'))
          .timeout(const Duration(seconds: 2));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Short, text-message-style answer (Gemini via the RAG backend).
  Future<String> askConcise(
    String question, {
    String? lessonContext,
    List<String>? history,
  }) async {
    final res = await _ask(question, 'short');
    return res.text;
  }

  /// Grounded answer with citations + figures (Gemini via the RAG backend).
  Future<AiAnswer> askDetailed(
    String question, {
    String? lessonContext,
    String verbosity = 'long',
  }) =>
      _ask(question, verbosity);

  Future<AiAnswer> _ask(String question, String verbosity) async {
    final r = await http
        .post(
          Uri.parse('$ragUrl/ask'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'question': question, 'verbosity': verbosity}),
        )
        .timeout(const Duration(seconds: 120));
    if (r.statusCode != 200) return const AiAnswer(text: '');
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    return AiAnswer(
      text: (data['answer'] as String?)?.trim() ?? '',
      sources: (data['sources'] as List? ?? const [])
          .map((s) => '[${s['nn']}] ${s['paper']} (p${s['page']})')
          .toList(),
      figureUrls: (data['figures'] as List? ?? const [])
          .map((f) => '$ragUrl/figures/${Uri.encodeComponent(f['file'] as String)}')
          .toList(),
    );
  }
}
