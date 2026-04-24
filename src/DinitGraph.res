/***
 * dinit-graph - Dependency graph generator
 * by: Andrew Velez
 */
@val external argv: array<string> = "process.argv"
@val external exit: int => 'a = "process.exit"

type commandOptions = {
  targetDirectory: string,
}

type dependencyType =
  | DependsOn
  | DependsMs
  | WaitsFor
  | DependsOnD
  | DependsMsD
  | WaitsForD
  | After
  | Before
  | ChainTo

type dependencyProp = {
  name: dependencyType,
  service: string,
}

let parseArgs = (args: array<string>): commandOptions => {
  switch args {
  | [_, _, dir] => {targetDirectory: dir}
  | _ => {
      Console.log("Usage: dinit-graph <targetDirectory>")
      exit(1)
    }
  }
}

let validateServiceDirectory = (targetDir: string): bool => {
  Console.log(targetDir)
  false
}

let cli = async () => {
  let options = parseArgs(Bun.argv)

  if !validateServiceDirectory(options.targetDirectory) {
    Console.error("Invalid service directory.  No boot service found.")
    exit(1)
  }

  // populate the Map of all properties[] keyed by target service name

  // create dependency graph, for each service, add vertex
  // for each service, add dependents and edge

  // do topological sort
}

//region Exception wrapper
try {
  await cli()
} catch {
| JsExn(e) => {
    Console.error("Error: " ++ JsExn.message(e)->Option.getOr("Unknown error"))
    exit(1)
  }
| _ => {
    Console.error("An unknown exception occurred.")
    exit(1)
  }
}
//endregion Exception wrapper
