/**
 * CLI argument parsing module
 * Handles parsing and validation of command line arguments
 */
type t = {
  targetDirectory: option<string>,
  helpRequested: bool,
}

let make = (): t => {
  targetDirectory: None,
  helpRequested: false,
}

let showUsage = (): unit => {
  Console.log("Usage: dinit-graph <targetDirectory>")
}

let parse = (args: array<string>): t => {
  let rec loop = (remaining: list<string>, acc: t): t => {
    switch remaining {
    | list{} => acc
    | list{"--help", ...rest} => loop(rest, {...acc, helpRequested: true})
    | list{"-h", ...rest} => loop(rest, {...acc, helpRequested: true})
    | list{dir, ...rest} if !String.startsWith(dir, "-") =>
      loop(rest, {...acc, targetDirectory: Some(dir)})
    | list{arg, ..._} =>
      Console.error(`Error: Unknown argument '${arg}'`)
      showUsage()
      %raw(`process.exit(1)`)
    }
  }

  args->List.fromArray->loop(make())
}

let showHelp = (): unit => {
  Console.log("\n📊 dinit-graph - Generate dependency graphs for your projects\n")
  Console.log("Usage:")
  Console.log("  dinit-graph <targetDirectory>")
  Console.log("  dinit-graph --help, -h    Show this help message\n")
  Console.log("Examples:")
  Console.log("  dinit-graph ./my-project")
  Console.log("  dinit-graph /absolute/path/to/project")
  Console.log("  dinit-graph ../relative/path\n")
}

let validate = (parsed: t): result<string, string> => {
  switch (parsed.helpRequested, parsed.targetDirectory) {
  | (true, _) =>
    showHelp()
    %raw(`process.exit(0)`)
  | (false, Some(dir)) => Ok(dir)
  | (false, None) => Error("Missing required parameter 'targetDirectory'")
  }
}

let processArgs = (): string => {
  let args = Bun.argv->Array.sliceToEnd(~start=2)
  let parsed = parse(args)

  switch validate(parsed) {
  | Ok(dir) => dir
  | Error(msg) =>
    Console.error(`Error: ${msg}`)
    showUsage()
    %raw(`process.exit(1)`)
  }
}
