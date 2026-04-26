/***
 * dinit-graph - Dependency graph generator
 * by: Andrew Velez
 */

//region "Import, Modules, etc"
@val external argv: array<string> = "process.argv"
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
type commandOptions = {
  targetDirectory: string,
}

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

type serviceProperties = Dict.t<array<serviceProperty>>
//endregion "Types"

let parseArgs = (args: array<string>): commandOptions => {
  switch args {
  | [_, _, dir] => {targetDirectory: dir}
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

let dependencyTypes = "depends-on|depends-ms|waits-for|depends-on\\.d|depends-ms\\.d|waits-for\\.d|after|before|chain-to"
let pattern = `^\s*(${dependencyTypes})\s*[:=]\s*([^#\s]+.*?)(?:\s+|#|$)`
let regex = RegExp.fromString(pattern, ~flags="g")

let parseServiceFile = (input: string): array<serviceProperty> => {
  input
  ->String.split("\n")
  ->Array.filterMap(line => {
    line
    ->String.match(regex)
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

let parseServiceDirectory = (serviceDir: string): serviceProperties => {
  let emptyProperties: serviceProperties = Dict.make()

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
            emptyProperties->Dict.set(filename, parsed)
          }
        } catch {
        | _ => () // Skip files that cause errors during reading/parsing
        }
      }
    })

    emptyProperties
  } catch {
  | _ =>
    Console.error("An unexpected error occurred while reading directory: " ++ serviceDir)
    emptyProperties
  }
}

let cli = async () => {
  let options = parseArgs(Bun.argv)
  let directoryProps = parseServiceDirectory(options.targetDirectory)
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
