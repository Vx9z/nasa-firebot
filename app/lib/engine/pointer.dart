import 'dart:math' as math;
import 'package:flutter/painting.dart';

/// Layer 4 — the sonar mouse pointer (state + drawing).
class Sonar {
  double x = -100;
  double y = -100;
  bool on = false;

  void move(double x, double y) {
    this.x = x;
    this.y = y;
    on = true;
  }

  void hide() => on = false;

  void draw(Canvas canvas, double t, Color color) {
    if (!on) return;
    final c = Offset(x, y);
    final pulse = 0.85 + 0.15 * math.sin(t * 1.8);
    final r0 = 3.0 * pulse;

    // Soft phosphor glow (radial gradient).
    final glowR = r0 + 9;
    canvas.drawCircle(
      c,
      glowR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: 0.55),
            color.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: glowR)),
    );

    // Bright centre dot.
    canvas.drawCircle(c, r0, Paint()..color = color);

    // One close expanding ring.
    final ph = (t / 3.2) % 1.0;
    final r = 4.0 + ph * 4.0;
    final a = 0.86 * (1.0 - ph);
    if (a > 0.02) {
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = color.withValues(alpha: a),
      );
    }
  }
}
