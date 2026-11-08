import 'package:flutter_test/flutter_test.dart';

import 'package:app/services/vault_service.dart';

void main() {
  test('character count maps to 4 discrete size stages', () {
    expect(VaultService.sizeFor(0), 0);
    expect(VaultService.sizeFor(49), 0);
    expect(VaultService.sizeFor(50), 1);
    expect(VaultService.sizeFor(199), 1);
    expect(VaultService.sizeFor(200), 2);
    expect(VaultService.sizeFor(999), 2);
    expect(VaultService.sizeFor(1000), 3);
    expect(VaultService.sizeFor(99999), 3);
  });
}
