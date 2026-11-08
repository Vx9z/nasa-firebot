import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/investigation.dart';

/// Loads the pre-compiled investigations from `assets/investigations.json`
/// (generated offline by `ai/scripts/compile_investigations.py`), already
/// ranked by relevance score.
class InvestigationsService {
  static const asset = 'assets/investigations.json';

  Future<List<Investigation>> load() async {
    final raw = await rootBundle.loadString(asset);
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final list = [
      for (final e in (data['investigations'] as List? ?? const []))
        Investigation.fromJson(e as Map<String, dynamic>),
    ];
    list.sort((a, b) => b.score.compareTo(a.score));
    return list;
  }
}
