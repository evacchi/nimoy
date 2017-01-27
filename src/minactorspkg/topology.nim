type
  Node = object
    name: string 
  Edge = tuple[left: Node, right: Node]
  Topology = object
    edges: seq[Edge]

let node1 = Node(name: "node1")
let node2 = Node(name: "node2")

proc `~>`(n1: Node, n2: Node): Edge = (n1, n2)

let t = Topology(
  edges: @[
    node1 ~> node2
  ]
)
