import 'dart:math';

const String _ramp = ' .·+*#';

/// A single stationary star.
class Star {
  final double x; // normalized 0..1
  final double y;
  final double brightness;
  final double phase;
  final double speed;

  const Star(this.x, this.y, this.brightness, this.phase, this.speed);
}

/// Layer 1 — a static starfield with slow, subtle twinkle.
class Starfield {
  final List<Star> stars;

  Starfield({int count = 120, int seed = 7}) : stars = _spawn(count, seed);

  static List<Star> _spawn(int count, int seed) {
    final rng = Random(seed);
    return List.generate(
      count,
      (_) => Star(
        rng.nextDouble(),
        rng.nextDouble(),
        0.25 + rng.nextDouble() * 0.75,
        rng.nextDouble() * 2 * pi,
        0.08 + rng.nextDouble() * 0.32,
      ),
    );
  }

  /// Ramp character for a star at time `t` (twinkle modulates brightness).
  String charFor(Star s, double t, double twinkle) {
    final amp = min(1.0, twinkle * 0.5);
    final blink = 1.0 - amp * (0.5 + 0.5 * sin(t * s.speed + s.phase));
    final v = s.brightness * blink;
    var idx = (v * (_ramp.length - 1)).toInt();
    if (idx < 0) idx = 0;
    if (idx >= _ramp.length) idx = _ramp.length - 1;
    return _ramp[idx];
  }
}
