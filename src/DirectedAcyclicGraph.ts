#! /usr/bin/env bun
/**
 * Directed Acyclic Graph via DeepSeek/Gemini
 * https://aistudio.google.com/app/prompts?state=%7B%22ids%22:%5B%221fEe3aIyMprYqSWyFKmQD-yLloyqjlHZ4%22%5D,%22action%22:%22open%22,%22userId%22:%22118203198241431162179%22,%22resourceKeys%22:%7B%7D%7D&usp=sharing
 */
export class DirectedAcyclicGraph<T = string> {

  private vertices: Set<T>;
  private edges: Map<T, Set<T>>;

  constructor(vertex?: T) {
    this.vertices = new Set<T>();
    this.edges = new Map<T, Set<T>>();
    if (vertex !== undefined) this.addVertex(vertex);
  }

  // Add a single vertex
  addVertex(vertex: T): this {
    this.vertices.add(vertex);
    if (!this.edges.has(vertex)) {
      this.edges.set(vertex, new Set<T>());
    }
    return this;
  }

  // Add an edge from 'from' to 'to'
  addEdge(from: T, to: T): this {
    // Ensure both vertices exist
    if (!this.vertices.has(from)) this.addVertex(from);
    if (!this.vertices.has(to)) this.addVertex(to);

    // Check if this edge would create a cycle
    if (this.wouldCreateCycle(from, to)) {
      throw new Error(`Cannot add edge ${from} -> ${to}: would create a cycle`);
    }

    // Add the edge
    this.edges.get(from)!.add(to);
    return this;
  }

  // Check if adding edge from->to would create a cycle
  private wouldCreateCycle(from: T, to: T): boolean {
    // If there's already a path from 'to' to 'from', adding from->to creates a cycle
    return this.hasPath(to, from);
  }

  // Check if there's a path from start to target
  private hasPath(start: T, target: T): boolean {
    if (start === target) return true;

    const visited = new Set<T>();
    const stack: T[] = [start];

    while (stack.length > 0) {
      const current = stack.pop()!;
      if (current === target) return true;

      if (visited.has(current)) continue;
      visited.add(current);

      const neighbors = this.edges.get(current);
      if (neighbors) {
        for (const neighbor of neighbors) {
          if (!visited.has(neighbor)) {
            stack.push(neighbor);
          }
        }
      }
    }
    return false;
  }

  // Topological sort using Kahn's algorithm with O(1) queue operations
  topologicalSort(): T[] {
    const inDegree = new Map<T, number>();
    const result: T[] = [];

    // Initialize in-degree for all vertices
    for (const vertex of this.vertices) {
      inDegree.set(vertex, 0);
    }

    // Calculate in-degrees
    for (const [from, neighbors] of this.edges) {
      for (const to of neighbors) {
        inDegree.set(to, (inDegree.get(to) || 0) + 1);
      }
    }

    // Use array as stack (pop() is O(1)) instead of shift()
    // Order doesn't matter for topological sort correctness
    const stack: T[] = [];
    for (const [vertex, degree] of inDegree) {
      if (degree === 0) stack.push(vertex);
    }

    // Process stack using pop() for O(1) operations
    while (stack.length > 0) {
      const current = stack.pop()!;
      result.push(current);

      // Reduce in-degree of neighbors
      const neighbors = this.edges.get(current);
      if (neighbors) {
        for (const neighbor of neighbors) {
          const newDegree = (inDegree.get(neighbor) || 0) - 1;
          inDegree.set(neighbor, newDegree);
          if (newDegree === 0) stack.push(neighbor);
        }
      }
    }

    // If result length doesn't match vertices count, there's a cycle (shouldn't happen)
    if (result.length !== this.vertices.size) {
      throw new Error("Graph contains a cycle - this shouldn't happen in a valid DAG");
    }

    return result;
  }

  // Get all vertices
  getVertices(): T[] {
    return Array.from(this.vertices);
  }

  // Get all edges as pairs
  getEdges(): [T, T][] {
    const edges: [T, T][] = [];
    for (const [from, neighbors] of this.edges) {
      for (const to of neighbors) {
        edges.push([from, to]);
      }
    }
    return edges;
  }

  // Check if a vertex exists
  hasVertex(vertex: T): boolean {
    return this.vertices.has(vertex);
  }

  // Check if an edge exists
  hasEdge(from: T, to: T): boolean {
    return this.edges.get(from)?.has(to) || false;
  }

  // Get the number of vertices
  get vertexCount(): number {
    return this.vertices.size;
  }

  // Get the number of edges
  get edgeCount(): number {
    let count = 0;
    for (const neighbors of this.edges.values()) {
      count += neighbors.size;
    }
    return count;
  }

}