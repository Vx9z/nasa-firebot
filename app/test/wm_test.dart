import 'package:flutter_test/flutter_test.dart';

import 'package:app/engine/wm.dart';

void main() {
  test('spawn copies spec.lines so const [] becomes a mutable list', () {
    final wm = WindowManager();
    final tile = wm.spawn(const TileSpec(
      type: TileType.investigations,
      title: 'INVESTIGATIONS',
      lines: [],
    ));

    // A const [] is unmodifiable — spawn must hand back a growable copy so the
    // list-refresh methods (clear + addAll) work and the tile renders.
    expect(() {
      tile.lines
        ..clear()
        ..addAll(['100  Saffire', '82  CFI']);
    }, returnsNormally);
    expect(tile.lines, ['100  Saffire', '82  CFI']);
  });
}
