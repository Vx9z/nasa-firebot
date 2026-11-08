import 'package:flutter/material.dart';

import 'pointer.dart';

/// Draws the sonar mouse pointer on top of everything.
class SonarPainter extends CustomPainter {
  final Sonar sonar;
  final double t;
  final Color color;

  SonarPainter(this.sonar, this.t, this.color);

  @override
  void paint(Canvas canvas, Size size) => sonar.draw(canvas, t, color);

  @override
  bool shouldRepaint(covariant SonarPainter old) =>
      old.t != t || old.color != color;
}
