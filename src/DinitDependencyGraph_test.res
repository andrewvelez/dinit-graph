/***
 * Unit tests for DinitDependencyGraph
 */
open DinitDependencyGraph
open BunTest

@module("node:fs")
external mkdtempSync: string => string = "mkdtempSync"

@module("node:fs")
external mkdirSync: string => unit = "mkdirSync"

@module("node:fs")
external writeFileSync: (string, string) => unit = "writeFileSync"

@module("node:fs")
external rmSync: (string, @as(json`{"recursive": true, "force": true}`) _) => unit = "rmSync"

@module("node:os")
external tmpdir: unit => string = "tmpdir"

@module("node:path")
external join: (string, string) => string = "join"

let tmpRoot = () => mkdtempSync(join(tmpdir(), "dinit-graph-test-"))

let withTempDir = (f: string => unit) => {
  let dir = tmpRoot()
  try {
    f(dir)
    rmSync(dir)
  } catch {
  | e =>
    rmSync(dir)
    throw(e)
  }
}

let expectProp = (
  props: array<serviceProperty>,
  index: int,
  expectedName: dependency,
  expectedService: string,
) => {
  switch props->Array.get(index) {
  | Some(prop) =>
    expect(prop.name)->toBe(expectedName)
    expect(prop.service)->toBe(expectedService)
  | None => failwith(`expected service property at index ${index->Int.toString}`)
  }
}

let expectContains = (text: string, expected: string) => {
  expect(text)->toContain(expected)
}

let makeDependencies = (entries: array<(string, array<serviceProperty>)>): serviceDependencies => {
  let deps: serviceDependencies = Dict.make()

  entries->Array.forEach(((service, props)) => {
    deps->Dict.set(service, props)
  })

  deps
}

let graphAscii = (deps: serviceDependencies, targetDir: string) =>
  deps->buildDependencyGraph(targetDir)->Dag.graphAsAscii

describe("parseArgs", () => {
  test("returns the third CLI argument as the target directory", () => {
    expect(parseArgs(["bun", "dinit-graph", "/etc/dinit.d"]))->toBe("/etc/dinit.d")
  })
})

describe("parseServiceFile", () => {

  test("parses all supported dependency property names", () => {
    let props = parseServiceFile(`depends-on = service-a
depends-ms = service-b
waits-for = service-c
depends-on.d = dir-a
depends-ms.d = dir-b
waits-for.d = dir-c
after = service-d
before = service-e
chain-to = service-f`)

    expect(props)->toHaveLength(9)

    expectProp(props, 0, DependsOn, "service-a")
    expectProp(props, 1, DependsMs, "service-b")
    expectProp(props, 2, WaitsFor, "service-c")
    expectProp(props, 3, DependsOnD, "dir-a")
    expectProp(props, 4, DependsMsD, "dir-b")
    expectProp(props, 5, WaitsForD, "dir-c")
    expectProp(props, 6, After, "service-d")
    expectProp(props, 7, Before, "service-e")
    expectProp(props, 8, ChainTo, "service-f")
  })

  test("accepts equals and colon assignment operators", () => {
    let props = parseServiceFile(`depends-on = service-a
depends-ms: service-b`)

    expect(props)->toHaveLength(2)
    expectProp(props, 0, DependsOn, "service-a")
    expectProp(props, 1, DependsMs, "service-b")
  })

  test("ignores comments, blank lines, and leading whitespace", () => {
    let props = parseServiceFile(`# comment

  depends-on = service-a # inline comment
depends-ms = service-b
     
waits-for: service-c`)

    expect(props)->toHaveLength(3)
    expectProp(props, 0, DependsOn, "service-a")
    expectProp(props, 1, DependsMs, "service-b")
    expectProp(props, 2, WaitsFor, "service-c")
  })

  test("returns an empty array for malformed or unsupported lines", () => {
    expect(parseServiceFile(""))->toHaveLength(0)
    expect(parseServiceFile("nonsense"))->toHaveLength(0)
    expect(parseServiceFile("unknown-key = service-a"))->toHaveLength(0)
    expect(parseServiceFile("# only comments\n# anot__her comment"))->toHaveLength(0)
  })
})

describe("dependency helpers", () => {
  test("identifies reverse dependency types", () => {
    expect(isReverseDependency(Before))->toBe(true)
    expect(isReverseDependency(ChainTo))->toBe(true)

    expect(isReverseDependency(DependsOn))->toBe(false)
    expect(isReverseDependency(DependsMs))->toBe(false)
    expect(isReverseDependency(WaitsFor))->toBe(false)
    expect(isReverseDependency(DependsOnD))->toBe(false)
    expect(isReverseDependency(DependsMsD))->toBe(false)
    expect(isReverseDependency(WaitsForD))->toBe(false)
    expect(isReverseDependency(After))->toBe(false)
  })

  test("identifies directory dependency types", () => {
    expect(isDirectoryDependency(DependsOnD))->toBe(true)
    expect(isDirectoryDependency(DependsMsD))->toBe(true)
    expect(isDirectoryDependency(WaitsForD))->toBe(true)

    expect(isDirectoryDependency(DependsOn))->toBe(false)
    expect(isDirectoryDependency(DependsMs))->toBe(false)
    expect(isDirectoryDependency(WaitsFor))->toBe(false)
    expect(isDirectoryDependency(After))->toBe(false)
    expect(isDirectoryDependency(Before))->toBe(false)
    expect(isDirectoryDependency(ChainTo))->toBe(false)
  })
})

describe("parseServiceDirectory", () => {
  test("recursively reads service files and parses dependency properties", () => {
    withTempDir(root => {
      mkdirSync(join(root, "nested"))

      writeFileSync(join(root, "boot"), "depends-on = app")
      writeFileSync(join(root, "app"), "depends-on = logger")
      writeFileSync(join(root, "nested/worker"), "waits-for = app")

      let deps = parseServiceDirectory(root)

      expect(deps->Dict.toArray->Array.length)->toBe(3)

      switch deps->Dict.get("boot") {
      | Some(props) => expectProp(props, 0, DependsOn, "app")
      | None => failwith("expected boot service")
      }

      switch deps->Dict.get("app") {
      | Some(props) => expectProp(props, 0, DependsOn, "logger")
      | None => failwith("expected app service")
      }

      switch deps->Dict.get("nested/worker") {
      | Some(props) => expectProp(props, 0, WaitsFor, "app")
      | None => failwith("expected nested/worker service")
      }
    })
  })

  test("returns an empty dictionary for a missing directory", () => {
    let deps = parseServiceDirectory("/non/existent/dinit-graph-test-directory")

    expect(deps->Dict.toArray)->toHaveLength(0)
  })

  test("skips files that do not__ contain dependency properties", () => {
    withTempDir(root => {
      writeFileSync(join(root, "boot"), "# no dependencies here")
      writeFileSync(join(root, "app"), "depends-on = logger")

      let deps = parseServiceDirectory(root)

      expect(deps->Dict.has("boot"))->toBe(false)
      expect(deps->Dict.has("app"))->toBe(true)
    })
  })
})

describe("getServicesInDirectory", () => {
  test("returns files inside a dependency directory", () => {
    withTempDir(root => {
      let dir = join(root, "enabled")
      mkdirSync(dir)

      writeFileSync(join(dir, "service-a"), "")
      writeFileSync(join(dir, "service-b"), "")

      let services = getServicesInDirectory(dir)

      expect(services)->toHaveLength(2)
      expect(services)->toContain("service-a")
      expect(services)->toContain("service-b")
    })
  })

  test("returns an empty array for a missing directory", () => {
    expect(getServicesInDirectory("/non/existent/dinit-service-dir"))->toHaveLength(0)
  })
})

describe("buildDependencyGraph", () => {
  test("creates a graph containing boot even when no dependencies exist", () => {
    let deps = makeDependencies([])
    let ascii = graphAscii(deps, ".")

    expectContains(ascii, "[boot]")
  })

  test("only traverses services reachable from boot", () => {
    let deps = makeDependencies([
      ("unreachable", [{name: DependsOn, service: "ignored"}]),
    ])

    let ascii = graphAscii(deps, ".")

    expectContains(ascii, "[boot]")
    expect(ascii)->not_->toContain("unreachable")
    expect(ascii)->not_->toContain("ignored")
  })

  test("adds normal dependency edges for services reachable from boot", () => {
    let deps = makeDependencies([
      ("boot", [{name: DependsOn, service: "app"}]),
      ("app", [
        {name: DependsOn, service: "logger"},
        {name: DependsMs, service: "network"},
        {name: WaitsFor, service: "database"},
        {name: After, service: "clock"},
      ]),
    ])

    let ascii = graphAscii(deps, ".")

    expectContains(ascii, "[boot]")
    expectContains(ascii, "boot")
    expectContains(ascii, "app")
    expectContains(ascii, "logger")
    expectContains(ascii, "network")
    expectContains(ascii, "database")
    expectContains(ascii, "clock")
  })

  test("adds reverse edges for before and chain-to", () => {
    let deps = makeDependencies([
      ("boot", [{name: DependsOn, service: "app"}]),
      ("app", [
        {name: Before, service: "shutdown"},
        {name: ChainTo, service: "next-service"},
      ]),
    ])

    let ascii = graphAscii(deps, ".")

    expectContains(ascii, "[shutdown]")
    expectContains(ascii, "-> app")
    expectContains(ascii, "[next-service]")
    expectContains(ascii, "-> app")
  })

  test("resolves directory dependencies to files inside the named directory", () => {
    withTempDir(root => {
      let enabled = join(root, "enabled")
      mkdirSync(enabled)

      writeFileSync(join(enabled, "service-a"), "")
      writeFileSync(join(enabled, "service-b"), "")

      let deps = makeDependencies([
        ("boot", [{name: DependsOnD, service: "enabled"}]),
      ])

      let ascii = graphAscii(deps, root)

      expectContains(ascii, "boot")
      expectContains(ascii, "service-a")
      expectContains(ascii, "service-b")
    })
  })

  test("recursively adds transitive dependencies", () => {
    let deps = makeDependencies([
      ("boot", [{name: DependsOn, service: "app"}]),
      ("app", [{name: DependsOn, service: "database"}]),
      ("database", [{name: DependsOn, service: "storage"}]),
    ])

    let ascii = graphAscii(deps, ".")

    expectContains(ascii, "boot")
    expectContains(ascii, "app")
    expectContains(ascii, "database")
    expectContains(ascii, "storage")
  })

  test("handles duplicate dependency references without crashing", () => {
    let deps = makeDependencies([
      ("boot", [
        {name: DependsOn, service: "app"},
        {name: DependsOn, service: "app"},
      ]),
      ("app", [{name: DependsOn, service: "logger"}]),
    ])

    let ascii = graphAscii(deps, ".")

    expectContains(ascii, "boot")
    expectContains(ascii, "app")
    expectContains(ascii, "logger")
  })

  test("skips an edge that would create a cycle and still returns a graph", () => {
    let deps = makeDependencies([
      ("boot", [{name: DependsOn, service: "app"}]),
      ("app", [{name: DependsOn, service: "boot"}]),
    ])

    let graph = buildDependencyGraph(deps, ".")
    let ascii = graph->Dag.graphAsAscii

    expectContains(ascii, "boot")
    expectContains(ascii, "app")
  })
})

describe("topological behavior of the constructed graph", () => {
  test("orders edges according to the graph direction used by buildDependencyGraph", () => {
    let deps = makeDependencies([
      ("boot", [{name: DependsOn, service: "app"}]),
      ("app", [{name: DependsOn, service: "database"}]),
    ])

    let sorted = deps->buildDependencyGraph(".")->Dag.topologicalSort

    let bootIndex = sorted->Array.findIndex(v => v == "boot")
    let appIndex = sorted->Array.findIndex(v => v == "app")
    let databaseIndex = sorted->Array.findIndex(v => v == "database")

    expect(bootIndex >= 0)->toBe(true)
    expect(appIndex >= 0)->toBe(true)
    expect(databaseIndex >= 0)->toBe(true)

    expect(bootIndex < appIndex)->toBe(true)
    expect(appIndex < databaseIndex)->toBe(true)
  })

  test("creates tiers for a boot service with independent dependencies", () => {
    let deps = makeDependencies([
      ("boot", [
        {name: DependsOn, service: "app-a"},
        {name: DependsOn, service: "app-b"},
      ]),
    ])

    let tiers = deps->buildDependencyGraph(".")->Dag.topologicalSortTiers

    expect(tiers->Array.length >= 2)->toBe(true)

    switch tiers->Array.get(0) {
    | Some(firstTier) => expect(firstTier)->toContain("boot")
    | None => failwith("expected first tier")
    }
  })
})