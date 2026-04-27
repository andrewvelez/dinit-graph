open DinitDependencyGraph

let graphCli = () => {

  let serviceDirectory = parseArgs(Bun.argv)
  let dictDependencies: serviceDependencies = parseServiceDirectory(serviceDirectory)
  let depGraph = buildDependencyGraph(dictDependencies, serviceDirectory)

  printGraphAscii(depGraph)
  printTopologicalOrder(depGraph)
  printTiers(depGraph)

}

try {
  graphCli()
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