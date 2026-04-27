// --- Bun Test Bindings ---
open Dag
open BunTest

// --- Tests ---

describe("DAG Module", () => {
  test("make() creates an empty graph", () => {
    let g = Dag.make()
    expect(g.inDegree->Dict.toArray->Array.length)->toBe(0)
  })

  test("addVertex() adds nodes and prevents duplicates", () => {
    let g = Dag.make()
    g->Dag.addVertex("A")
    g->Dag.addVertex("B")

    expect(g.inDegree->Dict.has("A"))->toBe(true)

    // Testing exception for duplicates
    expect(() => g->Dag.addVertex("A"))->toThrow
  })

  test("addEdge() updates in-degrees and neighbors", () => {
    let g = Dag.make()
    g->Dag.addVertex("A")
    g->Dag.addVertex("B")
    g->Dag.addEdge("A", "B")

    let neighbors = g.adjacency->Dict.get("A")->Option.getOr([])
    expect(neighbors)->toEqual(["B"])

    let inDegB = g.inDegree->Dict.get("B")->Option.getOr(0)
    expect(inDegB)->toBe(1)
  })

  test("addEdge() throws on non-existent vertices", () => {
    let g = Dag.make()
    g->Dag.addVertex("A")

    expect(() => g->Dag.addEdge("A", "Z"))->toThrow
  })

  test("Cycle detection prevents circular dependencies", () => {
    let g = Dag.make()
    g->Dag.addVertex("A")
    g->Dag.addVertex("B")
    g->Dag.addVertex("C")

    g->Dag.addEdge("A", "B")
    g->Dag.addEdge("B", "C")

    // Adding C -> A would create a cycle
    expect(() => g->Dag.addEdge("C", "A"))->toThrow
  })

  test("topologicalSort() returns nodes in valid order", () => {
    let g = Dag.make()
    g->Dag.addVertex("A")
    g->Dag.addVertex("B")
    g->Dag.addVertex("C")

    g->Dag.addEdge("A", "B")
    g->Dag.addEdge("B", "C")

    let sorted = g->Dag.topologicalSort
    expect(sorted)->toEqual(["A", "B", "C"])
  })

  test("topologicalSortTiers() groups independent nodes", () => {
    let g = Dag.make()
    // Setup: A and B are independent, both point to C
    g->Dag.addVertex("A")
    g->Dag.addVertex("B")
    g->Dag.addVertex("C")
    g->Dag.addVertex("D")

    g->Dag.addEdge("A", "C")
    g->Dag.addEdge("B", "C")
    g->Dag.addEdge("C", "D")

    let tiers = g->Dag.topologicalSortTiers

    // Tier 0: A, B (can be in any order within the inner array)
    expect(tiers->Array.get(0)->Option.getOr([]))->toContain("A")
    expect(tiers->Array.get(0)->Option.getOr([]))->toContain("B")

    // Tier 1: C
    expect(tiers->Array.get(1)->Option.getOr([]))->toEqual(["C"])

    // Tier 2: D
    expect(tiers->Array.get(2)->Option.getOr([]))->toEqual(["D"])
  })

  test("graphAsAscii() produces correct formatting", () => {
    let g = Dag.make()
    g->Dag.addVertex("Root")
    g->Dag.addVertex("Child")
    g->Dag.addEdge("Root", "Child")

    let ascii = g->Dag.graphAsAscii

    expect(ascii)->toContain("Directed Acyclic Graph")
    expect(ascii)->toContain("[Root] (in:0) -> Child")
    expect(ascii)->toContain("[Child] (in:1)")
  })

  test("graphAsAscii() handles empty graphs", () => {
    let g = Dag.make()
    let ascii = g->Dag.graphAsAscii
    expect(ascii)->toContain("(empty graph)")
  })
})
