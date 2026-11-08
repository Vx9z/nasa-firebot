import 'package:flutter_test/flutter_test.dart';

import 'package:app/services/curriculum_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('curriculum discovers modules & lessons from asset files', () async {
    final service = CurriculumService();
    final modules = await service.load();

    expect(modules, isNotEmpty);
    expect(modules.length, 7);

    final total = modules.fold<int>(0, (sum, m) => sum + m.lessons.length);
    expect(total, 35);

    expect(modules.first.id, '0');
    expect(modules.first.title, 'Foundations');
    expect(modules.first.lessons.first.title, 'Matter, atoms & molecules');
    expect(modules.first.lessons.first.moduleId, '0');
  });
}
