import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/splash.dart';

void main() {
  testWidgets('IntroSplash types out the brand text', (tester) async {
    await tester.pumpWidget(MaterialApp(home: IntroSplash(onFinished: () {})));

    // Empty at first — just the blinking block cursor.
    expect(find.textContaining('Firebot'), findsNothing);

    // Fast-forward through the typing phases ("Firebot by" + pause + "Jellyfire").
    await tester.pump(const Duration(milliseconds: 2100));
    expect(find.textContaining('Firebot by Jellyfire'), findsOneWidget);

    // Unmount to dispose the timers cleanly.
    await tester.pumpWidget(const SizedBox());
  });
}
