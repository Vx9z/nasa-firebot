import 'package:flutter/foundation.dart';

import '../models/investigation.dart';
import '../services/investigations_service.dart';

/// State for the investigations dashboard: the ranked list, loaded from the
/// bundled `investigations.json` asset.
class InvestigationsController extends ChangeNotifier {
  InvestigationsController._();
  static final InvestigationsController instance = InvestigationsController._();

  final InvestigationsService service = InvestigationsService();
  List<Investigation> _investigations = [];
  bool _loaded = false;

  bool get loaded => _loaded;
  List<Investigation> get investigations => _investigations;

  Future<void> load() async {
    if (_loaded) return;
    try {
      _investigations = await service.load();
      _loaded = true;
    } catch (_) {
      // Asset unavailable (e.g. in some tests) — leave the list empty.
    }
    notifyListeners();
  }
}
