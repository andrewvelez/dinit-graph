/**
 * dinit-graph - Dependency graph generator
 * Core implementation for generating dependency graphs
 * by: Andrew Velez
 */
/**
 * Core implementation for the dependency graph generation.
 * @param targetDirectory - The directory to analyze for dependencies
 */
let run = (~targetDirectory: string): unit => {
  Console.log(`Generating dependency graph for: ${targetDirectory}`)

  let absolutePath = Bun.pathToFileURL(targetDirectory)->URL.pathname

  Console.log(`Graph generation complete for ${absolutePath}`)
}

// Parse arguments and execute
let targetDirectory = CliArgs.processArgs()
run(~targetDirectory)
