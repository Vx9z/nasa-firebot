import 'package:flutter/material.dart';

/// Palette for the graph view, decoupled from the painter so the colours can be
/// swapped in one place (e.g. dark mode, or matching a NASA/fire theme).
class GraphTheme {
  final Color nodeFill;
  final Color nodeHover;
  final Color nodeGlow;
  final Color nodeOutline;
  final Color edgeNeutral;
  final Color edgeStretched;
  final Color edgeCompressed;
  final Color tooltipBg;
  final Color tooltipText;
  final double edgeStrokeWidth;

  const GraphTheme({
    required this.nodeFill,
    required this.nodeHover,
    required this.nodeGlow,
    required this.nodeOutline,
    required this.edgeNeutral,
    required this.edgeStretched,
    required this.edgeCompressed,
    required this.tooltipBg,
    required this.tooltipText,
    required this.edgeStrokeWidth,
  });

  /// The default fire palette (aligns with the Material seed `0xFFFF6B35`).
  static const fire = GraphTheme(
    nodeFill: Color(0xFFFF9800), // orange 500
    nodeHover: Color(0xFFFFA726), // orange 400 (brighter on hover)
    nodeGlow: Color(0x26FF9800), // orange @ ~15% alpha
    nodeOutline: Colors.white,
    edgeNeutral: Color(0xFF90A4AE), // blueGrey 300
    edgeStretched: Color(0xFFFF5722), // deepOrange 500
    edgeCompressed: Color(0xFF42A5F5), // blue 400
    tooltipBg: Color(0xE6212121), // dark @ ~90%
    tooltipText: Colors.white,
    edgeStrokeWidth: 1.5,
  );
}
