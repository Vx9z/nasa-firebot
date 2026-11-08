import 'dart:math';

import '../models/graph.dart';

/// Force-directed graph physics: repulsion + springs + boundary + damping.
///
/// Pure Dart, no UI. Call [step] each frame (or at a fixed timestep) to advance
/// positions; the view just renders `graph.nodes`. All the tunable knobs are
/// public fields so the UI sliders can map to them directly.
class GraphPhysics {
  final Graph graph;

  // Tunable parameters (the UI controls).
  double repulsion;    // how hard nodes push each other apart
  double elasticity;   // how stiffly threads pull linked nodes together
  double restLength;   // target length of a thread
  double damping;      // velocity decay per step (0..1); higher = settles faster
  double width;        // box width
  double height;       // box height
  double centerGravity; // subtle pull toward center (0 = off)

  GraphPhysics({
    required this.graph,
    this.repulsion = 5000,
    this.elasticity = 0.22,
    this.restLength = 80,
    this.damping = 0.8,
    this.width = 800,
    this.height = 600,
    this.centerGravity = 0.02,
  });

  final Map<String, double> _vx = {};
  final Map<String, double> _vy = {};

  /// Advance the simulation by one step (dt in arbitrary time units).
  void step(double dt) {
    final fx = <String, double>{};
    final fy = <String, double>{};
    for (final n in graph.nodes) {
      fx[n.id] = 0;
      fy[n.id] = 0;
    }

    // 1) Repulsion — every pair pushes apart (Coulomb-like, 1/d²).
    for (var i = 0; i < graph.nodes.length; i++) {
      for (var j = i + 1; j < graph.nodes.length; j++) {
        final a = graph.nodes[i];
        final b = graph.nodes[j];
        final dx = a.x - b.x;
        final dy = a.y - b.y;
        final d2 = max(dx * dx + dy * dy, 1.0); // avoid div-by-zero
        final d = sqrt(d2);
        final f = repulsion * ((a.mass + b.mass) / 2) / d2;
        final ux = dx / d;
        final uy = dy / d;
        fx[a.id] = fx[a.id]! + ux * f;
        fy[a.id] = fy[a.id]! + uy * f;
        fx[b.id] = fx[b.id]! - ux * f;
        fy[b.id] = fy[b.id]! - uy * f;
      }
    }

    // 2) Springs (threads) — pull connected nodes toward rest length.
    for (final e in graph.edges) {
      final a = _byId(e.source);
      final b = _byId(e.target);
      if (a == null || b == null) continue;
      final dx = a.x - b.x;
      final dy = a.y - b.y;
      final d = max(sqrt(dx * dx + dy * dy), 1e-6);
      final f = elasticity * (d - restLength); // + = stretched (pull in), - = compressed (push out)
      final ux = dx / d;
      final uy = dy / d;
      fx[a.id] = fx[a.id]! - ux * f;
      fy[a.id] = fy[a.id]! - uy * f;
      fx[b.id] = fx[b.id]! + ux * f;
      fy[b.id] = fy[b.id]! + uy * f;
    }

    // 3) Boundary — soft walls keep the WHOLE node (not just its center) inside.
    const wall = 0.5;
    for (final n in graph.nodes) {
      final r = n.radius;
      if (n.x < r) fx[n.id] = fx[n.id]! + wall * (r - n.x);
      if (n.x > width - r) fx[n.id] = fx[n.id]! - wall * (n.x - (width - r));
      if (n.y < r) fy[n.id] = fy[n.id]! + wall * (r - n.y);
      if (n.y > height - r) fy[n.id] = fy[n.id]! - wall * (n.y - (height - r));
    }

    // 4) Center gravity (optional, keeps the cluster from drifting).
    if (centerGravity != 0) {
      for (final n in graph.nodes) {
        fx[n.id] = fx[n.id]! - centerGravity * (n.x - width / 2);
        fy[n.id] = fy[n.id]! - centerGravity * (n.y - height / 2);
      }
    }

    // 5) Integrate (semi-implicit Euler) + damping — the smooth accel/decel.
    for (final n in graph.nodes) {
      if (n.pinned) continue;
      final vx = ((_vx[n.id] ?? 0) + fx[n.id]! * dt) * damping;
      final vy = ((_vy[n.id] ?? 0) + fy[n.id]! * dt) * damping;
      _vx[n.id] = vx;
      _vy[n.id] = vy;
      n.x += vx * dt;
      n.y += vy * dt;
    }
  }

  GraphNode? _byId(String id) {
    for (final n in graph.nodes) {
      if (n.id == id) return n;
    }
    return null;
  }

  /// Current speed (velocity magnitude) of a node — for velocity-based visuals.
  double speedOf(String id) {
    final vx = _vx[id] ?? 0;
    final vy = _vy[id] ?? 0;
    return sqrt(vx * vx + vy * vy);
  }
}
