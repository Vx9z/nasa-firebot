import 'dart:math' as math;

import 'package:flutter/services.dart';

/// A reusable held-key accelerator.
///
/// A single tap produces a small [base] step; holding the key (KeyRepeatEvent)
/// ramps the step up exponentially, so you can micro-adjust with taps and reach
/// far values quickly by holding. It's independent of what it drives, so it can
/// be reused for any smooth "dial" later (brightness, zoom, opacity, …).
class KeyAccelerator {
  int repeats = 0;

  /// Feed every key event for the accelerated key; returns the step for it.
  double step(
    KeyEvent event,
    double base, {
    double growth = 1.3,
    double maxStep = 1.0,
  }) {
    if (event is KeyRepeatEvent) {
      repeats++;
    } else {
      repeats = 0;
    }
    final s = base * math.pow(growth, repeats.toDouble());
    return s > maxStep ? maxStep : s;
  }
}
