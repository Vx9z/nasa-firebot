import 'dart:ui' show Offset;

/// A constellation figure: ordered star positions (normalized 0..1) and the
/// lines connecting them (index pairs). Lessons map to stars by index.
class ConstellationFigure {
  final String name;
  final List<Offset> stars;
  final List<(int, int)> edges;
  const ConstellationFigure({required this.name, required this.stars, required this.edges});
}

/// The constellation shapes, keyed by module id. The module → constellation
/// mapping is a design decision; unknown modules fall back to a generic layout.
///
/// Shapes are stylized approximations of the real asterisms (recognizable
/// figures, not exact RA/Dec) — swappable for precise coordinates later.
class ConstellationData {
  static final Map<String, ConstellationFigure> _figures = {
    '0': const ConstellationFigure(name: 'Norma', stars: [
      Offset(0.30, 0.30),
      Offset(0.70, 0.30),
      Offset(0.70, 0.70),
      Offset(0.30, 0.70),
      Offset(0.50, 0.22),
      Offset(0.50, 0.78),
    ], edges: [
      (0, 1), (1, 2), (2, 3), (3, 0), (4, 5),
    ]),
    '1': const ConstellationFigure(name: 'Phoenix', stars: [
      Offset(0.12, 0.55),
      Offset(0.30, 0.42),
      Offset(0.48, 0.55),
      Offset(0.55, 0.35),
      Offset(0.72, 0.45),
      Offset(0.86, 0.30),
    ], edges: [
      (0, 1), (1, 2), (2, 4), (4, 5), (2, 3),
    ]),
    '2': const ConstellationFigure(name: 'Ara', stars: [
      Offset(0.50, 0.72),
      Offset(0.35, 0.55),
      Offset(0.65, 0.55),
      Offset(0.50, 0.40),
      Offset(0.30, 0.26),
      Offset(0.70, 0.26),
      Offset(0.50, 0.16),
    ], edges: [
      (0, 1), (0, 2), (1, 3), (2, 3), (3, 4), (3, 5), (4, 6), (5, 6),
    ]),
    '3': const ConstellationFigure(name: 'Boötes', stars: [
      Offset(0.50, 0.14),
      Offset(0.30, 0.35),
      Offset(0.20, 0.60),
      Offset(0.50, 0.86),
      Offset(0.80, 0.60),
      Offset(0.70, 0.35),
    ], edges: [
      (0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (5, 0),
    ]),
    '4': const ConstellationFigure(name: 'Sagitta', stars: [
      Offset(0.18, 0.72),
      Offset(0.40, 0.60),
      Offset(0.62, 0.48),
      Offset(0.84, 0.36),
    ], edges: [
      (0, 1), (1, 2), (2, 3),
    ]),
    '5': const ConstellationFigure(name: 'Vela', stars: [
      Offset(0.32, 0.74),
      Offset(0.15, 0.40),
      Offset(0.50, 0.50),
      Offset(0.78, 0.35),
      Offset(0.55, 0.16),
    ], edges: [
      (0, 1), (0, 2), (1, 2), (2, 3), (2, 4), (3, 4),
    ]),
    '6': const ConstellationFigure(name: 'Horologium', stars: [
      Offset(0.50, 0.50),
    ], edges: []),
  };

  static ConstellationFigure? figureFor(String moduleId) => _figures[moduleId];
}
