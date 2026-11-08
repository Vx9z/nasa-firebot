import 'package:flutter/material.dart';

import 'graph_theme.dart';

/// Constellation palette — decoupled from the painter.
class ConstellationTheme {
  final Color background;
  final Color line;
  final Color label;
  final Color starDim;
  final Color starBright;
  final Color currentRing;

  const ConstellationTheme({
    required this.background,
    required this.line,
    required this.label,
    required this.starDim,
    required this.starBright,
    required this.currentRing,
  });
}

/// App-wide theme tokens — the single source of truth for colours.
/// Views read from this instead of hardcoding hex values.
class AppTheme {
  final Color seed;
  final Color canvas;
  final GraphTheme graph;
  final ConstellationTheme constellation;

  const AppTheme({
    required this.seed,
    required this.canvas,
    required this.graph,
    required this.constellation,
  });

  ThemeData get material => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: canvas,
      );

  static const fire = AppTheme(
    seed: Color(0xFFFF6B35),
    canvas: Color(0xFF0A0E1A),
    graph: GraphTheme.fire,
    constellation: ConstellationTheme(
      background: Color(0xFF0A0E1A),
      line: Color(0x33FFFFFF),
      label: Color(0xB3FFFFFF),
      starDim: Color(0xFF546E7A),
      starBright: Color(0xFFFFB74D),
      currentRing: Colors.white,
    ),
  );
}
