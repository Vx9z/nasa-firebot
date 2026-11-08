/// A node in the graph — a note, lesson, or concept.
class GraphNode {
  final String id;
  final String label;
  double x;
  double y;

  /// Pinned nodes keep a fixed position (constellation stars); they still exert
  /// forces on free nodes but don't move themselves. Mutable so a drag can pin/unpin.
  bool pinned;

  /// Discrete size stage 0..3, derived from the note's character count.
  /// Drives both the drawn radius and the repulsion "mass".
  final int size;

  GraphNode({
    required this.id,
    required this.label,
    this.x = 0,
    this.y = 0,
    this.pinned = false,
    this.size = 1,
  });

  int get clamped => size < 0 ? 0 : (size > 3 ? 3 : size);

  /// Drawing radius (px) per size stage.
  double get radius => _radius[clamped];

  /// Repulsion "mass" — bigger notes push harder.
  double get mass => _mass[clamped];

  static const _radius = [6.0, 10.0, 15.0, 22.0];
  static const _mass = [0.5, 1.0, 1.6, 2.4];
}

/// A directed edge between two nodes (by id).
class GraphEdge {
  final String source;
  final String target;

  GraphEdge({required this.source, required this.target});
}

/// The graph — nodes + edges. The single abstraction every view renders.
class Graph {
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;

  Graph({required this.nodes, required this.edges});
}
