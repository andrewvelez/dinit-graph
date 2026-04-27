/***
 * dinit-graph - Dependency graph generator
 * by: Andrew Velez
 */

//region "Import, Modules, etc"
@val external exit: int => 'a = "process.exit"

@module("node:fs")
external readdirSyncRecursive: (string, @as(json`{"recursive": true}`) _) => array<string> =
  "readdirSync"

@module("node:path")
external join: (string, string) => string = "join"

@module("node:fs")
external statSync: string => RescriptBun.Fs.Stats.t = "statSync"

@module("node:fs")
external readdirSync: string => array<string> = "readdirSync"

@module("node:fs")
external readFileSync: (string, @as(json`"utf8"`) _) => string = "readFileSync"
//endregion "Import, Modules, etc"

//region "Types"
type directory = string

type dependency =
  | DependsOn
  | DependsMs
  | WaitsFor
  | DependsOnD
  | DependsMsD
  | WaitsForD
  | After
  | Before
  | ChainTo

type serviceProperty = {
  name: dependency,
  service: string,
}

type serviceDependencies = Dict.t<array<serviceProperty>>
//endregion "Types"

let dependencyTypes = "depends-on|depends-ms|waits-for|depends-on\\.d|depends-ms\\.d|waits-for\\.d|after|before|chain-to"
let propPattern = `^\\s*(${dependencyTypes})\\s*[:=]\\s*([^#\\s]+.*?)(?:\\s+|#|$)`
let propRegex = RegExp.fromString(propPattern)

let parseArgs = (args: array<string>): directory => {
  switch args {
  | [_, _, dir] => dir
  | _ => {
      Console.log("Usage: dinit-graph <targetDirectory>")
      exit(1)
    }
  }
}

let dependencyFromString = (str: string): option<dependency> => {
  switch str {
  | "depends-on" => Some(DependsOn)
  | "depends-ms" => Some(DependsMs)
  | "waits-for" => Some(WaitsFor)
  | "depends-on.d" => Some(DependsOnD)
  | "depends-ms.d" => Some(DependsMsD)
  | "waits-for.d" => Some(WaitsForD)
  | "after" => Some(After)
  | "before" => Some(Before)
  | "chain-to" => Some(ChainTo)
  | _ => None
  }
}

let parseServiceFile = (input: string): array<serviceProperty> => {
  input
  ->String.split("\n")
  ->Array.filterMap(line => {
    line
    ->String.match(propRegex)
    ->Option.flatMap(result => {
      switch result {
      | [_, Some(keyStr), Some(valStr)] =>
        keyStr
        ->dependencyFromString
        ->Option.map(
          name => {
            {name, service: valStr->String.trim}
          },
        )
      | _ => None
      }
    })
  })
}

let parseServiceDirectory = (serviceDir: string): serviceDependencies => {
  let propertyDict: serviceDependencies = Dict.make()

  try {
    let files = readdirSyncRecursive(serviceDir)

    files->Array.forEach(filename => {
      let fullPath = join(serviceDir, filename)
      let fileStats = statSync(fullPath)

      if fileStats->RescriptBun.Fs.Stats.isFile {
        try {
          let content = readFileSync(fullPath)
          let parsed = parseServiceFile(content)

          if parsed->Array.length > 0 {
            propertyDict->Dict.set(filename, parsed)
          }
        } catch {
        | _ => () // Skip files that cause errors during reading/parsing
        }
      }
    })

    propertyDict
  } catch {
  | _ =>
    Console.error("An unexpected error occurred while reading directory: " ++ serviceDir)
    propertyDict
  }
}

let isReverseDependency = (dep: dependency): bool => {
  switch dep {
  | Before | ChainTo => true
  | _ => false
  }
}

let isDirectoryDependency = (dep: dependency): bool => {
  switch dep {
  | DependsOnD | DependsMsD | WaitsForD => true
  | _ => false
  }
}

let getServicesInDirectory = (dirPath: string): array<string> => {
  try {
    let files = readdirSyncRecursive(dirPath)
    files->Array.filter(filename => {
      let fullPath = join(dirPath, filename)
      try {
        statSync(fullPath)->RescriptBun.Fs.Stats.isFile
      } catch {
      | _ => false
      }
    })
  } catch {
  | _ => []
  }
}

let addVertexIfNew = (g: Dag.graph, vertex: string): unit => {
  try {
    g->Dag.addVertex(vertex)
  } catch {
  | Dag.DuplicateVertex(_) => () // Already exists, that's fine
  }
}

let addEdgeWithDirection = (g: Dag.graph, from: string, to_: string, isReverse: bool): unit => {
  if isReverse {
    g->Dag.addEdge(to_, from) // Reverse: dependency -> service
  } else {
    g->Dag.addEdge(from, to_) // Normal: service -> dependency
  }
}

let resolveDependency = (prop: serviceProperty, targetDir: string): array<string> => {

  if isDirectoryDependency(prop.name) {
    getServicesInDirectory(join(targetDir, prop.service))
  } else {
    [prop.service]
  }

}

let rec addServiceToGraph = (g: Dag.graph, serviceName: string, dependencies: serviceDependencies,
  visited: Dict.t<bool>, targetDir: string) => {

  switch visited->Dict.get(serviceName) {
  | Some(_) => ()
  | None => {
      visited->Dict.set(serviceName, true)
      addVertexIfNew(g, serviceName)

      let serviceDeps =
        dependencies->Dict.get(serviceName)->Option.getOr([])

      serviceDeps->Array.forEach(prop => {
        let isReverse = isReverseDependency(prop.name)
        let resolved = resolveDependency(prop, targetDir)

        resolved->Array.forEach(depService => {
          addVertexIfNew(g, depService)

          try {
            addEdgeWithDirection(
              g,
              serviceName,
              depService,
              isReverse,
            )
          } catch {
          | Dag.CycleDetected(msg) => Console.warn(msg)
          }

          addServiceToGraph(
            g,
            depService,
            dependencies,
            visited,
            targetDir,
          )
        })
      })
    }
  }

}

let buildDependencyGraph = (dependencies: serviceDependencies, targetDir: string): Dag.graph => {
  let g = Dag.make()
  let visited: Dict.t<bool> = Dict.make()
  let bootService = "boot"

  addVertexIfNew(g, bootService)
  addServiceToGraph(g, bootService, dependencies, visited, targetDir)

  g
}

let printGraphAscii = (graph: Dag.graph): unit => {
  Console.log("\n" ++ graph->Dag.graphAsAscii)
}

let printTopologicalOrder = (graph: Dag.graph): unit => {
  try {
    let sortOrder = graph->Dag.topologicalSort
    Console.log("Topological order:")
    Console.log(sortOrder->Array.join(" -> "))
  } catch {
  | Dag.CycleDetected(msg) => Console.error("Error: " ++ msg)
  }
}

let printTiers = (graph: Dag.graph): unit => {
  try {
    let tiers = graph->Dag.topologicalSortTiers
    Console.log("\nDependency tiers:")
    tiers->Array.forEachWithIndex((tier, index) => {
      Console.log(`Tier ${Int.toString(index + 1)}: ${tier->Array.join(", ")}`)
    })
  } catch {
  | Dag.CycleDetected(msg) => Console.error("Error: " ++ msg)
  }
}

