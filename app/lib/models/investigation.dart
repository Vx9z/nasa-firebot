/// A fire-safety "investigation" — a group of papers sharing an experiment or
/// research thread, with structured attributes, a generated summary and
/// interpretation, and a deterministic relevance score (0-100).
class Investigation {
  final String id;
  final String name;
  final List<String> papers;
  final String objective;
  final String fuels;
  final String conditions;
  final String variables;
  final String sensors;
  final String hardware;
  final List<String> pillars;
  final String crewRelevance;
  final String dataRichness;
  final String directness;
  final String summary;
  final String insight;
  final String earthApplication;
  final int score;
  final List<String> reasons;

  const Investigation({
    required this.id,
    required this.name,
    required this.papers,
    required this.objective,
    required this.fuels,
    required this.conditions,
    required this.variables,
    required this.sensors,
    required this.hardware,
    required this.pillars,
    required this.crewRelevance,
    required this.dataRichness,
    required this.directness,
    required this.summary,
    required this.insight,
    required this.earthApplication,
    required this.score,
    required this.reasons,
  });

  static String _str(dynamic v) => (v ?? '').toString();

  static List<String> _strList(dynamic v) =>
      [for (final e in (v as List? ?? const [])) e.toString()];

  factory Investigation.fromJson(Map<String, dynamic> j) => Investigation(
        id: _str(j['id']),
        name: _str(j['name']),
        papers: _strList(j['papers']),
        objective: _str(j['objective']),
        fuels: _str(j['fuels']),
        conditions: _str(j['conditions']),
        variables: _str(j['variables']),
        sensors: _str(j['sensors']),
        hardware: _str(j['hardware']),
        pillars: _strList(j['pillars']),
        crewRelevance: _str(j['crew_relevance']),
        dataRichness: _str(j['data_richness']),
        directness: _str(j['directness']),
        summary: _str(j['summary']),
        insight: _str(j['insight']),
        earthApplication: _str(j['earth_application']),
        score: (j['score'] as num?)?.toInt() ?? 0,
        reasons: _strList(j['reasons']),
      );

  /// Markdown for the detail view (rendered by the rich markdown renderer).
  String toMarkdown() {
    final b = StringBuffer()
      ..writeln('## $name')
      ..writeln()
      ..writeln('**Relevance: $score/100**')
      ..writeln();
    for (final r in reasons) {
      b.writeln('- $r');
    }
    b
      ..writeln()
      ..writeln('### Objective')
      ..writeln(objective)
      ..writeln()
      ..writeln('### Fuels / materials')
      ..writeln(fuels)
      ..writeln()
      ..writeln('### Conditions')
      ..writeln(conditions)
      ..writeln()
      ..writeln('### Variables')
      ..writeln(variables)
      ..writeln()
      ..writeln('### Sensors / measurements')
      ..writeln(sensors)
      ..writeln()
      ..writeln('### Hardware')
      ..writeln(hardware)
      ..writeln()
      ..writeln('### Summary')
      ..writeln(summary)
      ..writeln()
      ..writeln('### Fire-safety insight')
      ..writeln(insight);
    if (earthApplication.isNotEmpty) {
      b
        ..writeln()
        ..writeln('### Earth application')
        ..writeln(earthApplication);
    }
    b
      ..writeln()
      ..writeln('_Pillars: ${pillars.join(', ')} · Papers: ${papers.join(', ')}_');
    return b.toString();
  }

  /// Markdown for a two-way comparison, surfacing shared attributes and
  /// per-attribute differences (deterministic, from the structured fields).
  static String compareMarkdown(Investigation a, Investigation b) {
    final buf = StringBuffer()
      ..writeln('## Comparison')
      ..writeln()
      ..writeln('**A** — ${a.name}  (_${a.score}/100_)')
      ..writeln('**B** — ${b.name}  (_${b.score}/100_)')
      ..writeln();

    buf
      ..writeln('### Similarities')
      ..writeln();
    final sims = _similarities(a, b);
    if (sims.isEmpty) {
      buf.writeln('- (no strong structural overlap found)');
    } else {
      for (final s in sims) {
        buf.writeln('- $s');
      }
    }
    buf.writeln();

    buf.writeln('### Side by side');
    buf.writeln();
    _sideBySide(buf, 'Objective', a.objective, b.objective);
    _sideBySide(buf, 'Fuels / materials', a.fuels, b.fuels);
    _sideBySide(buf, 'Conditions', a.conditions, b.conditions);
    _sideBySide(buf, 'Variables', a.variables, b.variables);
    _sideBySide(buf, 'Sensors / measurements', a.sensors, b.sensors);
    _sideBySide(buf, 'Hardware', a.hardware, b.hardware);

    buf.writeln('### Fire-safety insight');
    buf.writeln();
    buf.writeln('- **A:** ${a.insight}');
    buf.writeln('- **B:** ${b.insight}');
    buf.writeln();
    buf.writeln('_Pillars — A: ${a.pillars.join(', ')} · B: ${b.pillars.join(', ')}_');
    return buf.toString();
  }

  static void _sideBySide(StringBuffer buf, String label, String lhs, String rhs) {
    buf.writeln('**$label**');
    buf.writeln('- A: $lhs');
    buf.writeln('- B: $rhs');
    buf.writeln();
  }

  static List<String> _similarities(Investigation a, Investigation b) {
    final sims = <String>[];
    final shared = a.pillars.toSet().intersection(b.pillars.toSet()).toList()..sort();
    if (shared.isNotEmpty) {
      sims.add('Both target the fire-safety pillar(s): ${shared.join(', ')}.');
    }
    if (a.crewRelevance == b.crewRelevance && a.crewRelevance.isNotEmpty) {
      sims.add('Both are rated **${a.crewRelevance}** crew-environment relevance.');
    }
    if (a.dataRichness == b.dataRichness && a.dataRichness.isNotEmpty) {
      sims.add('Both are rated **${a.dataRichness}** data richness.');
    }
    if (a.directness == b.directness && a.directness.isNotEmpty) {
      sims.add('Both are **${a.directness}** fire-safety measurements.');
    }
    final terms = _sharedTerms(a, b);
    if (terms.isNotEmpty) {
      sims.add('Shared subject matter: ${terms.join(', ')}.');
    }
    return sims;
  }

  static const Set<String> _stop = {
    'the', 'a', 'an', 'and', 'or', 'of', 'to', 'in', 'for', 'on', 'with',
    'by', 'at', 'as', 'is', 'are', 'was', 'were', 'be', 'been', 'being',
    'from', 'that', 'this', 'these', 'those', 'it', 'its', 'their', 'they',
    'we', 'via', 'using', 'used', 'use', 'into', 'between', 'during', 'over',
    'under', 'both', 'each', 'also', 'such', 'which', 'when', 'where',
  };

  static Set<String> _tokens(String s) => s
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9]+'))
      .where((w) => w.length > 2 && !_stop.contains(w))
      .toSet();

  static List<String> _sharedTerms(Investigation a, Investigation b) {
    final at = {
      ..._tokens(a.objective),
      ..._tokens(a.fuels),
      ..._tokens(a.conditions),
      ..._tokens(a.variables),
      ..._tokens(a.sensors),
    };
    final bt = {
      ..._tokens(b.objective),
      ..._tokens(b.fuels),
      ..._tokens(b.conditions),
      ..._tokens(b.variables),
      ..._tokens(b.sensors),
    };
    final shared = at.intersection(bt).toList()..sort();
    return shared.take(6).toList();
  }
}
