import 'package:flutter_test/flutter_test.dart';

import 'package:app/models/investigation.dart';

Investigation _inv({
  required String id,
  required String name,
  required String objective,
  required String fuels,
  required List<String> pillars,
  required int score,
  String crewRelevance = 'high',
  String dataRichness = 'high',
  String directness = 'direct',
  String insight = '',
}) =>
    Investigation(
      id: id,
      name: name,
      papers: const [],
      objective: objective,
      fuels: fuels,
      conditions: '',
      variables: '',
      sensors: '',
      hardware: '',
      pillars: pillars,
      crewRelevance: crewRelevance,
      dataRichness: dataRichness,
      directness: directness,
      summary: '',
      insight: insight,
      earthApplication: '',
      score: score,
      reasons: const [],
    );

void main() {
  test('compareMarkdown surfaces shared pillars and shared subject terms', () {
    final a = _inv(
      id: 'a',
      name: 'Alpha',
      objective: 'Study flame spread in microgravity oxygen environments.',
      fuels: 'PMMA slabs',
      pillars: ['prevention', 'detection'],
      score: 100,
    );
    final b = _inv(
      id: 'b',
      name: 'Beta',
      objective: 'Measure droplet combustion in microgravity at low oxygen.',
      fuels: 'n-decane droplets',
      pillars: ['detection', 'suppression'],
      score: 82,
    );

    final md = Investigation.compareMarkdown(a, b);

    expect(md, contains('Alpha'));
    expect(md, contains('Beta'));
    expect(md, contains('100/100'));
    expect(md, contains('82/100'));
    // Shared pillar (intersection) is surfaced.
    expect(md, contains('detection'));
    // Shared subject matter is surfaced.
    expect(md, contains('microgravity'));
    expect(md, contains('oxygen'));
    // Side-by-side attribute breakdown is present.
    expect(md, contains('Objective'));
    expect(md, contains('Fuels / materials'));
    expect(md, contains('- A:'));
    expect(md, contains('- B:'));
  });

  test('compareMarkdown still renders a similarities section for disjoint cases', () {
    final a = _inv(
      id: 'a',
      name: 'Alpha',
      objective: 'Study solid burning rates.',
      fuels: 'paper',
      pillars: ['prevention'],
      score: 10,
    );
    final b = _inv(
      id: 'b',
      name: 'Beta',
      objective: 'Detect smoke particles.',
      fuels: 'aerosols',
      pillars: ['detection'],
      score: 20,
    );

    final md = Investigation.compareMarkdown(a, b);

    expect(md, contains('Similarities'));
    expect(md, contains('Side by side'));
  });
}
