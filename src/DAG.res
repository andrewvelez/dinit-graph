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

let topologicalSort = (g: graph): array<string> => {
  let inDeg = g.inDegree->Dict.copy
  let queue = inDeg->Dict.toArray->Array.filterMap(((v, d)) => d == 0 ? Some(v) : None)
  let result = []

  while queue->Array.length > 0 {
    switch queue->Array.pop {
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

let addEdge = (g: graph, from: string, to_: string) => {
  if !(g.adjacency->Dict.has(from)) {
    throw(NoSuchVertex(from))
  }
  if !(g.adjacency->Dict.has(to_)) {
    throw(NoSuchVertex(to_))
  }

  let neighbors = g.adjacency->Dict.get(from)->Option.getOr([])
  g.adjacency->Dict.set(from, neighbors->Array.concat([to_]))
  let d = g.inDegree->Dict.get(to_)->Option.getOr(0)
  g.inDegree->Dict.set(to_, d + 1)

  try {
    let _ = g->topologicalSort
  } catch {
  | CycleDetected(_) =>
    g.adjacency->Dict.set(from, neighbors)
    g.inDegree->Dict.set(to_, d)
    throw(CycleDetected(`Adding edge "${from}" -> "${to_}" would create a cycle`))
  }
}

let topologicalSortTiers = (g: graph): array<array<string>> => {
  let inDeg = g.inDegree->Dict.copy
  let rec loop = (queue: array<string>, acc: array<array<string>>) => {
    if queue->Array.length == 0 {
      acc
    } else {
      let nextQueue = []
      queue->Array.forEach(v => {
        g.adjacency
        ->Dict.get(v)
        ->Option.getOr([])
        ->Array.forEach(n => {
          let newD = inDeg->Dict.get(n)->Option.getOr(0) - 1
          inDeg->Dict.set(n, newD)
          if newD == 0 {
            nextQueue->Array.push(n)
          }
        })
      })
      loop(nextQueue, acc->Array.concat([queue]))
    }
  }

  let start = g.inDegree->Dict.toArray->Array.filterMap(((v, d)) => d == 0 ? Some(v) : None)
  loop(start, [])
}

let graphAsAscii = (g: graph): string => {
  let header = "Directed Acyclic Graph:\n=======================\n"
  let sortedNodes = g->topologicalSortTiers->Array.flat

  let body = if sortedNodes->Array.length == 0 {
    "(empty graph)\n"
  } else {
    sortedNodes
    ->Array.map(v => {
      let indeg = g.inDegree->Dict.get(v)->Option.mapOr("?", n => Int.toString(n))
      let neighbors = g.adjacency->Dict.get(v)->Option.getOr([])
      let neighborStr = neighbors->Array.length == 0 ? "" : " -> " ++ neighbors->Array.join(", ")
      `[${v}] (in:${indeg})${neighborStr}`
    })
    ->Array.join("\n") ++ "\n"
  }
  header ++ body ++ "=======================\n"
}
