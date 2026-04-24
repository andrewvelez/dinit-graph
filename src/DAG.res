/***
 * Directed Acyclic Graph
 * by: Andrew Velez
 */
exception NoSuchVertex(string)
exception DuplicateVertex(string)
exception CycleDetected(string)

type graph = {
  adjacency: Dict.t<array<string>>,
  inDegree: Dict.t<int>,
}

let make = (): graph => {
  adjacency: Dict.make(),
  inDegree: Dict.make(),
}

let addVertex = (g: graph, v: string) => {
  if g.adjacency->Dict.has(v) {
    throw(DuplicateVertex(`Vertex "${v}" already exists`))
  }
  g.adjacency->Dict.set(v, [])
  g.inDegree->Dict.set(v, 0)
}

let wouldCreateCycle = (g: graph, from: string, to_: string): bool => {
  if !(g.adjacency->Dict.has(from)) {
    throw(NoSuchVertex(`Vertex "${from}" does not exist`))
  }
  if !(g.adjacency->Dict.has(to_)) {
    throw(NoSuchVertex(`Vertex "${to_}" does not exist`))
  }

  let visited = Dict.make()

  let rec dfs = (cur: string): bool => {
    if cur == from {
      true
    } else if visited->Dict.has(cur) {
      false
    } else {
      visited->Dict.set(cur, true)
      g.adjacency->Dict.get(cur)->Option.getOr([])->Array.some(dfs)
    }
  }

  dfs(to_)
}

let addEdge = (g: graph, from: string, to_: string) => {
  if wouldCreateCycle(g, from, to_) {
    throw(CycleDetected(`Adding edge "${from}" -> "${to_}" would create a cycle`))
  }

  // Update Adjacency
  let neighbors = g.adjacency->Dict.get(from)->Option.getOr([])
  g.adjacency->Dict.set(from, neighbors->Array.concat([to_]))

  // Update In-Degree
  let d = g.inDegree->Dict.get(to_)->Option.getOr(0)
  g.inDegree->Dict.set(to_, d + 1)
}

let topologicalSort = (g: graph): array<string> => {
  let inDeg = g.inDegree->Dict.copy
  let queue = inDeg->Dict.toArray->Array.filterMap(((v, d)) => d == 0 ? Some(v) : None)
  let result = []

  while queue->Array.length > 0 {
    switch queue->Array.shift {
    | None => ()
    | Some(v) =>
      result->Array.push(v)
      g.adjacency
      ->Dict.get(v)
      ->Option.getOr([])
      ->Array.forEach(n => {
        let d = inDeg->Dict.get(n)->Option.getOr(0) - 1
        inDeg->Dict.set(n, d)
        if d == 0 {
          queue->Array.push(n)
        }
      })
    }
  }

  if result->Array.length != g.inDegree->Dict.size {
    throw(CycleDetected("Graph contains a cycle"))
  }

  result
}

let topologicalSortTiers = (g: graph): array<array<string>> => {
  // Create a mutable copy of the in-degrees so we don't modify the original graph
  let inDeg = g.inDegree->Dict.toArray->Dict.fromArray

  let rec loop = (queue: array<string>, acc: array<array<string>>) => {
    if queue->Array.length == 0 {
      acc
    } else {
      let nextQueue = []

      // Process every node in the current tier
      queue->Array.forEach(v => {
        let neighbors = g.adjacency->Dict.get(v)->Option.getOr([])

        neighbors->Array.forEach(n => {
          // Decrement in-degree for each neighbor
          let currentD = inDeg->Dict.get(n)->Option.getOr(0)
          let newD = currentD - 1
          inDeg->Dict.set(n, newD)

          // If in-degree hits 0, it belongs in the next tier
          if newD == 0 {
            let _ = nextQueue->Array.push(n)
          }
        })
      })

      // Add the current tier to acc and recurse with the next tier
      loop(nextQueue, acc->Array.concat([queue]))
    }
  }

  // Find initial nodes (those with 0 incoming edges)
  let start =
    g.inDegree
    ->Dict.toArray
    ->Array.filterMap(((v, d)) => d == 0 ? Some(v) : None)

  loop(start, [])
}

let graphAsAscii = (g: graph): string => {
  let header = "Directed Acyclic Graph:\n=======================\n"

  // Use the tiered sort and flatten it for a simple list view,
  // or use your existing topologicalSort function.
  let sortedNodes = g->topologicalSortTiers->Array.flat

  let body = if sortedNodes->Array.length == 0 {
    "(empty graph)\n"
  } else {
    sortedNodes
    ->Array.map(v => {
      let indeg = g.inDegree->Dict.get(v)->Option.mapOr("?", n => Int.toString(n))
      let neighbors = g.adjacency->Dict.get(v)->Option.getOr([])

      if neighbors->Array.length == 0 {
        `[${v}] (in:${indeg})`
      } else {
        let neighborStr = neighbors->Array.join(", ")
        `[${v}] (in:${indeg}) -> ${neighborStr}`
      }
    })
    ->Array.join("\n") ++ "\n"
  }

  header ++ body ++ "=======================\n"
}
