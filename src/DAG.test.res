// --- Bun Test Bindings ---
type expectMatchers<'a>

@val external describe: (string, unit => unit) => unit = "describe"
@val external test: (string, unit => unit) => unit = "test"
@val external expect: 'a => expectMatchers<'a> = "expect"

@send external toBe: (expectMatchers<'a>, 'a) => unit = "toBe"
@send external toEqual: (expectMatchers<'a>, 'a) => unit = "toEqual"
@send external toContain: (expectMatchers<'container>, 'item) => unit = "toContain"
@send external toThrow: expectMatchers<unit => 'a> => unit = "toThrow"

// --- Tests ---

describe("DAG Module", () => {
  test("make() creates an empty graph", () => {
    let g = DAG.make()
    expect(g.inDegree->Dict.toArray->Array.length)->toBe(0)
  })

  test("addVertex() adds nodes and prevents duplicates", () => {
    let g = DAG.make()
    g->DAG.addVertex("A")
    g->DAG.addVertex("B")

    expect(g.inDegree->Dict.has("A"))->toBe(true)

    // Testing exception for duplicates
    expect(() => g->DAG.addVertex("A"))->toThrow
  })

  test("addEdge() updates in-degrees and neighbors", () => {
    let g = DAG.make()
    g->DAG.addVertex("A")
    g->DAG.addVertex("B")
    g->DAG.addEdge("A", "B")

    let neighbors = g.adjacency->Dict.get("A")->Option.getOr([])
    expect(neighbors)->toEqual(["B"])

    let inDegB = g.inDegree->Dict.get("B")->Option.getOr(0)
    expect(inDegB)->toBe(1)
  })

  test("addEdge() throws on non-existent vertices", () => {
    let g = DAG.make()
    g->DAG.addVertex("A")

    expect(() => g->DAG.addEdge("A", "Z"))->toThrow
  })

  test("Cycle detection prevents circular dependencies", () => {
    let g = DAG.make()
    g->DAG.addVertex("A")
    g->DAG.addVertex("B")
    g->DAG.addVertex("C")

    g->DAG.addEdge("A", "B")
    g->DAG.addEdge("B", "C")

    // Adding C -> A would create a cycle
    expect(() => g->DAG.addEdge("C", "A"))->toThrow
  })

  test("topologicalSort() returns nodes in valid order", () => {
    let g = DAG.make()
    g->DAG.addVertex("A")
    g->DAG.addVertex("B")
    g->DAG.addVertex("C")

    g->DAG.addEdge("A", "B")
    g->DAG.addEdge("B", "C")

    let sorted = g->DAG.topologicalSort
    expect(sorted)->toEqual(["A", "B", "C"])
  })

  test("topologicalSortTiers() groups independent nodes", () => {
    let g = DAG.make()
    // Setup: A and B are independent, both point to C
    g->DAG.addVertex("A")
    g->DAG.addVertex("B")
    g->DAG.addVertex("C")
    g->DAG.addVertex("D")

    g->DAG.addEdge("A", "C")
    g->DAG.addEdge("B", "C")
    g->DAG.addEdge("C", "D")

    let tiers = g->DAG.topologicalSortTiers

    // Tier 0: A, B (can be in any order within the inner array)
    expect(tiers->Array.get(0)->Option.getOr([]))->toContain("A")
    expect(tiers->Array.get(0)->Option.getOr([]))->toContain("B")

    // Tier 1: C
    expect(tiers->Array.get(1)->Option.getOr([]))->toEqual(["C"])

    // Tier 2: D
    expect(tiers->Array.get(2)->Option.getOr([]))->toEqual(["D"])
  })

  test("graphAsAscii() produces correct formatting", () => {
    let g = DAG.make()
    g->DAG.addVertex("Root")
    g->DAG.addVertex("Child")
    g->DAG.addEdge("Root", "Child")

    let ascii = g->DAG.graphAsAscii

    expect(ascii)->toContain("Directed Acyclic Graph")
    expect(ascii)->toContain("[Root] (in:0) -> Child")
    expect(ascii)->toContain("[Child] (in:1)")
  })

  test("graphAsAscii() handles empty graphs", () => {
    let g = DAG.make()
    let ascii = g->DAG.graphAsAscii
    expect(ascii)->toContain("(empty graph)")
  })
})
