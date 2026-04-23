/***
 * dinit-graph - Dependency graph generator
 * by: Andrew Velez
 */
@val external argv: array<string> = "process.argv"
@val external exit: int => 'a = "process.exit"

type commandOptions = {targetDirectory: string}

let parseArgs = (args: array<string>): commandOptions => {
  let positionalArgs = args->Array.sliceToEnd(~start=2, ...)

  switch positionalArgs {
  | [dir] => {targetDirectory: dir}
  | _ => {
      Console.log("Usage: dinit-graph <targetDirectory>")
      exit(1)
    }
  }
}

let cli = async () => {
  let _options = parseArgs(Bun.argv)
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
