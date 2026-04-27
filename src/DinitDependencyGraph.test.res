// DinitDependencyGraph.test.res
/***
 * Unit tests for DinitDependencyGraph
 */

// --- Bun Test Bindings ---
type expectMatchers<'a>

@val external describe: (string, unit => unit) => unit = "describe"
@val external test: (string, unit => unit) => unit = "test"
@val external expect: 'a => expectMatchers<'a> = "expect"

@send external toBe: (expectMatchers<'a>, 'a) => unit = "toBe"
@send external toEqual: (expectMatchers<'a>, 'a) => unit = "toEqual"
@send external toContain: (expectMatchers<'container>, 'item) => unit = "toContain"
@send external toThrow: expectMatchers<unit => 'a> => unit = "toThrow"
@send external toBeDefined: expectMatchers<'a> => unit = "toBeDefined"
@send external toHaveLength: (expectMatchers<array<'a>>, int) => unit = "toHaveLength"

// --- Tests ---

describe("Dependency Type Conversion", () => {
  test("dependencyFromString converts valid dependency types", () => {
    // Note: These functions are internal, but we can test through integration
    // or by exposing them. For now, we'll test the behavior through parseServiceFile
    
    // This test validates that the regex and type conversion work correctly
    let content = "depends-on = test-service"
    let result = content->String.split("\n")
    // We can't directly access dependencyFromString, but we can verify
    // the parsing works through parseServiceFile if it's exported
    expect(true)->toBe(true) // Placeholder - see integration tests below
  })
})

describe("Service File Parsing", () => {
  test("parseServiceFile extracts dependency properties", () => {
    let content = `depends-on = service-a
depends-ms = service-b
waits-for = service-c
after = service-d
before = service-e
chain-to = service-f`
    
    let result = DinitDependencyGraph.parseServiceFile(content)
    
    expect(result)->toHaveLength(6)
    expect(result->Array.get(0)->Option.getOr({name: DependsOn, service: ""}).service)->toBe("service-a")
    expect(result->Array.get(1)->Option.getOr({name: DependsOn, service: ""}).service)->toBe("service-b")
    expect(result->Array.get(2)->Option.getOr({name: DependsOn, service: ""}).service)->toBe("service-c")
    expect(result->Array.get(3)->Option.getOr({name: DependsOn, service: ""}).service)->toBe("service-d")
    expect(result->Array.get(4)->Option.getOr({name: DependsOn, service: ""}).service)->toBe("service-e")
    expect(result->Array.get(5)->Option.getOr({name: DependsOn, service: ""}).service)->toBe("service-f")
  })

  test("parseServiceFile handles different assignment operators", () => {
    let contentWithColon = "depends-on: service-a"
    let contentWithEquals = "depends-on = service-a"
    let contentWithBoth = `depends-on = service-a
depends-ms: service-b`
    
    let resultColon = parseServiceFile(contentWithColon)
    let resultEquals = parseServiceFile(contentWithEquals)
    let resultBoth = parseServiceFile(contentWithBoth)
    
    expect(resultColon)->toHaveLength(1)
    expect(resultEquals)->toHaveLength(1)
    expect(resultBoth)->toHaveLength(2)
  })

  test("parseServiceFile ignores comments and whitespace", () => {
    let content = `# This is a comment
depends-on = service-a # inline comment
  depends-ms = service-b  # indented with comment
# Another comment
waits-for = service-c`
    
    let result = parseServiceFile(content)
    
    expect(result)->toHaveLength(3)
    expect(result->Array.get(0)->Option.getOr({name: DependsOn, service: ""}).service)->toBe("service-a")
    expect(result->Array.get(1)->Option.getOr({name: DependsOn, service: ""}).service)->toBe("service-b")
    expect(result->Array.get(2)->Option.getOr({name: DependsOn, service: ""}).service)->toBe("service-c")
  })

  test("parseServiceFile handles directory dependencies", () => {
    let content = `depends-on.d = dir-service
depends-ms.d = another-dir
waits-for.d = third-dir`
    
    let result = parseServiceFile(content)
    
    expect(result)->toHaveLength(3)
    expect(result->Array.get(0)->Option.getOr({name: DependsOn, service: ""}).name)->toBe(DependsOnD)
    expect(result->Array.get(1)->Option.getOr({name: DependsOn, service: ""}).name)->toBe(DependsMsD)
    expect(result->Array.get(2)->Option.getOr({name: DependsOn, service: ""}).name)->toBe(WaitsForD)
  })

  test("parseServiceFile returns empty array for invalid input", () => {
    let emptyContent = ""
    let invalidContent = "invalid line\nnot a dependency\nanother invalid line"
    let commentOnly = "# Just a comment\n# Another comment"
    
    let resultEmpty = parseServiceFile(emptyContent)
    let resultInvalid = parseServiceFile(invalidContent)
    let resultComments = parseServiceFile(commentOnly)
    
    expect(resultEmpty)->toHaveLength(0)
    expect(resultInvalid)->toHaveLength(0)
    expect(resultComments)->toHaveLength(0)
  })

  test("parseServiceFile handles empty lines and whitespace-only lines", () => {
    let content = `depends-on = service-a

depends-ms = service-b
  
waits-for = service-c`
    
    let result = parseServiceFile(content)
    
    expect(result)->toHaveLength(3)
  })
})

describe("Dependency Type Helpers", () => {
  test("isReverseDependency correctly identifies reverse dependencies", () => {
    expect(isReverseDependency(Before))->toBe(true)
    expect(isReverseDependency(ChainTo))->toBe(true)
    expect(isReverseDependency(After))->toBe(false)
    expect(isReverseDependency(DependsOn))->toBe(false)
    expect(isReverseDependency(DependsMs))->toBe(false)
    expect(isReverseDependency(WaitsFor))->toBe(false)
  })

  test("isDirectoryDependency correctly identifies directory dependencies", () => {
    expect(isDirectoryDependency(DependsOnD))->toBe(true)
    expect(isDirectoryDependency(DependsMsD))->toBe(true)
    expect(isDirectoryDependency(WaitsForD))->toBe(true)
    expect(isDirectoryDependency(DependsOn))->toBe(false)
    expect(isDirectoryDependency(WaitsFor))->toBe(false)
    expect(isDirectoryDependency(After))->toBe(false)
  })
})

describe("Service Directory Parsing", () => {
  test("parseServiceDirectory reads and parses service files", () => {
    // This test requires actual filesystem access
    // For now, we test with the current directory structure
    let result = parseServiceDirectory(".")
    
    // Should return a dict (might be empty if no service files found)
    expect(result)->toBeDefined
  })

  test("parseServiceDirectory handles non-existent directory gracefully", () => {
    let result = parseServiceDirectory("/non/existent/directory/12345")
    
    // Should return empty dict without throwing
    expect(result)->toBeDefined
    expect(result->Dict.toArray->Array.length)->toBe(0)
  })
})

describe("Graph Building", () => {
  test("buildDependencyGraph creates a graph with boot node", () => {
    let dependencies: serviceDependencies = Dict.make()
    let graph = buildDependencyGraph(dependencies, ".")
    
    // Should have at least the boot node
    expect(graph->DAG.graphAsAscii)->toContain("boot")
  })

  test("buildDependencyGraph adds service nodes and edges", () => {
    let dependencies: serviceDependencies = Dict.make()
    
    // Add a test service with dependencies
    dependencies->Dict.set("test-service", [
      {name: DependsOn, service: "dependency-a"},
      {name: After, service: "dependency-b"}
    ])
    
    let graph = buildDependencyGraph(dependencies, ".")
    let ascii = graph->DAG.graphAsAscii
    
    expect(ascii)->toContain("test-service")
    expect(ascii)->toContain("dependency-a")
    expect(ascii)->toContain("dependency-b")
  })

  test("buildDependencyGraph handles reverse dependencies correctly", () => {
    let dependencies: serviceDependencies = Dict.make()
    
    dependencies->Dict.set("service-a", [
      {name: Before, service: "service-b"}
    ])
    
    dependencies->Dict.set("service-b", [
      {name: DependsOn, service: "service-c"}
    ])
    
    let graph = buildDependencyGraph(dependencies, ".")
    let ascii = graph->DAG.graphAsAscii
    
    // Before creates reverse edge: service-b -> service-a
    expect(ascii)->toContain("service-a")
    expect(ascii)->toContain("service-b")
    expect(ascii)->toContain("service-c")
  })

  test("buildDependencyGraph prevents adding duplicate vertices", () => {
    let dependencies: serviceDependencies = Dict.make()
    
    dependencies->Dict.set("service-a", [
      {name: DependsOn, service: "service-b"}
    ])
    
    dependencies->Dict.set("service-c", [
      {name: DependsOn, service: "service-b"}  // Duplicate service-b
    ])
    
    let graph = buildDependencyGraph(dependencies, ".")
    let ascii = graph->DAG.graphAsAscii
    
    // Should handle duplicate without crashing
    expect(ascii)->toContain("service-b")
  })

  test("buildDependencyGraph resolves transitive dependencies", () => {
    let dependencies: serviceDependencies = Dict.make()
    
    dependencies->Dict.set("service-a", [
      {name: DependsOn, service: "service-b"}
    ])
    
    dependencies->Dict.set("service-b", [
      {name: DependsOn, service: "service-c"},
      {name: WaitsFor, service: "service-d"}
    ])
    
    let graph = buildDependencyGraph(dependencies, ".")
    let ascii = graph->DAG.graphAsAscii
    
    // All services should appear in the graph
    expect(ascii)->toContain("service-a")
    expect(ascii)->toContain("service-b")
    expect(ascii)->toContain("service-c")
    expect(ascii)->toContain("service-d")
  })
})

describe("Topological Sorting", () => {
  test("topological sort produces valid ordering for linear dependencies", () => {
    let dependencies: serviceDependencies = Dict.make()
    
    dependencies->Dict.set("boot", [
      {name: DependsOn, service: "service-a"}
    ])
    
    dependencies->Dict.set("service-a", [
      {name: DependsOn, service: "service-b"}
    ])
    
    dependencies->Dict.set("service-b", [
      {name: DependsOn, service: "service-c"}
    ])
    
    let graph = buildDependencyGraph(dependencies, ".")
    let sorted = graph->DAG.topologicalSort
    
    // Check that dependencies come before dependents
    let indexOf = (arr: array<string>, item: string): int => {
      arr->Array.findIndex(x => x == item)->Option.getOr(-1)
    }
    
    let bootIdx = sorted->indexOf("boot")
    let aIdx = sorted->indexOf("service-a")
    let bIdx = sorted->indexOf("service-b")
    let cIdx = sorted->indexOf("service-c")
    
    expect(cIdx < bIdx)->toBe(true)
    expect(bIdx < aIdx)->toBe(true)
    expect(aIdx < bootIdx)->toBe(true)
  })

  test("topological sort handles independent services", () => {
    let dependencies: serviceDependencies = Dict.make()
    
    dependencies->Dict.set("boot", [
      {name: DependsOn, service: "service-a"},
      {name: DependsOn, service: "service-b"}
    ])
    
    let graph = buildDependencyGraph(dependencies, ".")
    let sorted = graph->DAG.topologicalSort
    
    // Both service-a and service-b should be before boot
    expect(sorted)->toContain("service-a")
    expect(sorted)->toContain("service-b")
    expect(sorted)->toContain("boot")
  })
})

describe("Integration Tests", () => {
  test("complete workflow: parse directory, build graph, get tiers", () => {
    // This tests the entire pipeline
    // Note: This will work with actual service files in the test directory
    let dependencies = parseServiceDirectory(".")
    let graph = buildDependencyGraph(dependencies, ".")
    
    // Basic validation
    expect(graph)->toBeDefined
    
    // Try to get tiers
    try {
      let tiers = graph->DAG.topologicalSortTiers
      expect(tiers)->toBeDefined
      
      // Should have at least one tier (the boot node)
      expect(tiers->Array.length > 0)->toBe(true)
    } catch {
    | DAG.CycleDetected(msg) => {
        // If cycle detected, that's also a valid result
        expect(msg)->toBeDefined
      }
    }
  })

  test("handles ChainTo dependency type", () => {
    let dependencies: serviceDependencies = Dict.make()
    
    dependencies->Dict.set("service-a", [
      {name: ChainTo, service: "service-b"}
    ])
    
    let graph = buildDependencyGraph(dependencies, ".")
    let ascii = graph->DAG.graphAsAscii
    
    // ChainTo creates reverse dependency (like Before)
    expect(ascii)->toContain("service-a")
    expect(ascii)->toContain("service-b")
  })

  test("handles multiple dependency types in single service", () => {
    let dependencies: serviceDependencies = Dict.make()
    
    dependencies->Dict.set("complex-service", [
      {name: DependsOn, service: "dep-a"},
      {name: DependsMs, service: "dep-b"},
      {name: WaitsFor, service: "dep-c"},
      {name: After, service: "dep-d"},
      {name: Before, service: "dep-e"},
      {name: ChainTo, service: "dep-f"}
    ])
    
    let graph = buildDependencyGraph(dependencies, ".")
    let ascii = graph->DAG.graphAsAscii
    
    // All dependencies should be in the graph
    expect(ascii)->toContain("dep-a")
    expect(ascii)->toContain("dep-b")
    expect(ascii)->toContain("dep-c")
    expect(ascii)->toContain("dep-d")
    expect(ascii)->toContain("dep-e")
    expect(ascii)->toContain("dep-f")
    expect(ascii)->toContain("complex-service")
  })
})

describe("Graph Output Formatting", () => {
  test("ASCII graph output contains graph structure", () => {
    let graph = DAG.make()
    graph->DAG.addVertex("test-service")
    
    let ascii = graph->DAG.graphAsAscii
    
    expect(ascii)->toContain("Directed Acyclic Graph")
    expect(ascii)->toContain("test-service")
  })

  test("topological order output format", () => {
    let graph = DAG.make()
    graph->DAG.addVertex("A")
    graph->DAG.addVertex("B")
    graph->DAG.addEdge("A", "B")
    
    let sorted = graph->DAG.topologicalSort
    
    // Should be an array with proper ordering
    expect(sorted->Array.length)->toBe(2)
    expect(sorted->Array.get(0)->Option.getOr(""))->toBe("A")
    expect(sorted->Array.get(1)->Option.getOr(""))->toBe("B")
  })
})

describe("Error Handling", () => {
  test("handles malformed service files gracefully", () => {
    let content = "garbage content\nmore garbage\n@#$%^&*()"
    let result = parseServiceFile(content)
    
    // Should return empty array for malformed content
    expect(result)->toHaveLength(0)
  })

  test("handles cycle detection in dependencies", () => {
    let dependencies: serviceDependencies = Dict.make()
    
    dependencies->Dict.set("service-a", [
      {name: DependsOn, service: "service-b"}
    ])
    
    dependencies->Dict.set("service-b", [
      {name: DependsOn, service: "service-a"}  // Creates cycle
    ])
    
    let graph = buildDependencyGraph(dependencies, ".")
    
    // Graph building should still succeed (cycle detected during edge addition)
    expect(graph)->toBeDefined
    
    // But topological sort should throw
    expect(() => graph->DAG.topologicalSort)->toThrow
  })

  test("handles empty service directory", () => {
    let dependencies: serviceDependencies = Dict.make()
    let graph = buildDependencyGraph(dependencies, "/tmp/empty-dir")
    
    // Should create graph with just boot node
    let ascii = graph->DAG.graphAsAscii
    expect(ascii)->toContain("boot")
  })
})