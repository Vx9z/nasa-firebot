import 'package:flutter_test/flutter_test.dart';

import 'package:app/models/graph.dart';
import 'package:app/services/graph_physics.dart';

void main() {
  test('repulsion pushes unconnected nodes apart', () {
    final graph = Graph(nodes: [
      GraphNode(id: 'a', label: 'a', x: 0, y: 0),
      GraphNode(id: 'b', label: 'b', x: 20, y: 0),
    ], edges: []);
    final physics = GraphPhysics(
      graph: graph,
      repulsion: 1000,
      elasticity: 0,
      centerGravity: 0,
      damping: 0.9,
    );

    final start = (graph.nodes[0].x - graph.nodes[1].x).abs();
    for (var i = 0; i < 200; i++) {
      physics.step(0.1);
    }
    final end = (graph.nodes[0].x - graph.nodes[1].x).abs();

    expect(end, greaterThan(start));
  });

  test('springs pull connected nodes toward rest length', () {
    final graph = Graph(nodes: [
      GraphNode(id: 'a', label: 'a', x: 0, y: 0),
      GraphNode(id: 'b', label: 'b', x: 400, y: 0),
    ], edges: [GraphEdge(source: 'a', target: 'b')]);
    final physics = GraphPhysics(
      graph: graph,
      repulsion: 0,
      elasticity: 0.1,
      restLength: 100,
      centerGravity: 0,
      damping: 0.9,
    );

    for (var i = 0; i < 1000; i++) {
      physics.step(0.1);
    }
    final d = (graph.nodes[0].x - graph.nodes[1].x).abs();

    expect(d, closeTo(100, 25)); // settled near rest length
  });

  test('nodes stay inside the box', () {
    final graph = Graph(nodes: [
      GraphNode(id: 'a', label: 'a', x: -200, y: -200),
      GraphNode(id: 'b', label: 'b', x: 600, y: 600),
    ], edges: []);
    final physics = GraphPhysics(
      graph: graph,
      repulsion: 1000,
      elasticity: 0,
      centerGravity: 0,
      width: 400,
      height: 400,
      damping: 0.85,
    );

    for (var i = 0; i < 1000; i++) {
      physics.step(0.1);
    }

    for (final n in graph.nodes) {
      expect(n.x, greaterThanOrEqualTo(-5));
      expect(n.x, lessThanOrEqualTo(405));
      expect(n.y, greaterThanOrEqualTo(-5));
      expect(n.y, lessThanOrEqualTo(405));
    }
  });

  test('pinned nodes do not move', () {
    final graph = Graph(nodes: [
      GraphNode(id: 'a', label: 'a', x: 100, y: 100, pinned: true),
      GraphNode(id: 'b', label: 'b', x: 200, y: 200),
    ], edges: [GraphEdge(source: 'a', target: 'b')]);
    final physics = GraphPhysics(graph: graph);

    for (var i = 0; i < 500; i++) {
      physics.step(0.1);
    }

    expect(graph.nodes[0].x, 100); // pinned stays put
    expect(graph.nodes[0].y, 100);
  });

  test('bigger nodes repel harder', () {
    Graph makePair(int size) => Graph(nodes: [
      GraphNode(id: 'a', label: 'a', x: 200, y: 300, size: size),
      GraphNode(id: 'b', label: 'b', x: 230, y: 300, size: size),
    ], edges: []);

    final small = GraphPhysics(
      graph: makePair(0),
      repulsion: 1000,
      elasticity: 0,
      centerGravity: 0,
      damping: 1.0,
    );
    final big = GraphPhysics(
      graph: makePair(3),
      repulsion: 1000,
      elasticity: 0,
      centerGravity: 0,
      damping: 1.0,
    );

    for (var i = 0; i < 10; i++) {
      small.step(0.1);
      big.step(0.1);
    }
    final smallSep = (small.graph.nodes[0].x - small.graph.nodes[1].x).abs();
    final bigSep = (big.graph.nodes[0].x - big.graph.nodes[1].x).abs();

    expect(bigSep, greaterThan(smallSep));
  });

  test('whole node stays inside the box (radius accounted for)', () {
    final graph = Graph(nodes: [
      GraphNode(id: 'a', label: 'a', x: -200, y: -200, size: 3),
      GraphNode(id: 'b', label: 'b', x: 600, y: 600, size: 3),
    ], edges: []);
    final physics = GraphPhysics(
      graph: graph,
      repulsion: 1000,
      elasticity: 0,
      centerGravity: 0,
      width: 400,
      height: 400,
      damping: 0.85,
    );

    for (var i = 0; i < 1000; i++) {
      physics.step(0.1);
    }

    for (final n in graph.nodes) {
      expect(n.x, greaterThanOrEqualTo(n.radius - 3));
      expect(n.x, lessThanOrEqualTo(400 - n.radius + 3));
      expect(n.y, greaterThanOrEqualTo(n.radius - 3));
      expect(n.y, lessThanOrEqualTo(400 - n.radius + 3));
    }
  });
}
