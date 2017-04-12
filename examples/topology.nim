import nimoy, future

type  
  ActorNode[In, Out] =
    proc(self: ActorRef[In], subscriber: ActorRef[Out])
  
  Topology = object
    system: ActorSystem

#   Edge[In,X,Out] = tuple
#     left: ActorNode[In,X]
#     right: ActorNode[X,Out]  

# proc `~>`[A,X,B](left: ActorNode[A,X], right: ActorNode[X,B]): Edge[A,X,B] =
#   (left, right)

proc createTopology(system: ActorSystem): Topology =
  Topology(system: system)

proc createTopology(): Topology =
  Topology(system: createActorSystem())


proc initNode[In,Out](
  topology: Topology, 
  actorNode: ActorNode[In, Out], 
  subscriber: ActorRef[Out]
): ActorRef[In] =
  topology.system.initActor(
    (self: ActorRef[In]) => 
      actorNode(self, subscriber))

proc broadcastRef[In](
  topology: Topology, 
  subscribers: varargs[ActorRef[In]]): ActorRef[In] =
  let subs = @subscribers
  topology.system.createActor do (self: ActorRef[In], m: In): 
      for s in subs:
        s ! m

proc node[In,Out]( f: In -> Out ): ActorNode[In,Out] = 
  (self: ActorRef[In], subscriber: ActorRef[Out]) => 
    self.become((inp: In) => subscriber.send(f(inp)))

proc sinkNode[In]( f: proc(x:In) ): ActorInit[In] =
  (self: ActorRef[In]) =>
    self.become((inp: In) => f(inp))

proc broadcastNode[In](node1: ActorRef[In], node2: ActorRef[In]): ActorInit[In] =
  (self: ActorRef[In]) => 
    self.become do (inp: In):
      node1.send(inp)
      node2.send(inp)

proc sinkRef[In](topology: Topology, f: proc(x:In) ): ActorRef[In] =
   topology.system.initActor(sinkNode(f))

proc nodeRef[In,Out](topology: Topology, f: proc(x:In): Out, subscriber: ActorRef[Out]): ActorRef[In] =
   topology.initNode(node[In,Out](f), subscriber)

proc initNode[In,Out](
  system: ActorSystem, 
  actorNode: ActorNode[In, Out], 
  subscriber: ActorRef[Out]
): ActorRef[In] =
  system.initActor(
    (self: ActorRef[In]) => 
      actorNode(self, subscriber))


#
# source ~> map1 ~> fanIn ~> map3 ~> broadcast ~> sink1
#    +~~~~> map2 ~~~~~^                 +~~~~> sink2
#  

# let t = createTopology()

# let sink1Ref = t.sinkRef((x: int) => echo("sink1 = ", x))
# let sink2Ref = t.sinkRef((x: int) => echo("sink2 = ", x))
# let bref = t.broadcastRef(sink1Ref, sink2Ref))

# let map3Ref  = t.nodeRef((x: int) => x+7,  bref)
# let fanInRef = t.nodeRef((x: int) => ( echo("fan in = ", x); x ), map3Ref)
# let map2Ref  = t.nodeRef((x: int) => x-1, fanInRef)
# let map1Ref  = t.nodeRef((x: int) => x*2, fanInRef)

# # send input
# for i in 0..10:
#   map1Ref ! i

# t.system.awaitTermination()

type
  HalfNode[Out] = object
    discard
  Node[In,Out] = object
    f: In -> Out
  Source[Out] = object
    f: () -> Out
  Sink[In] = object
    f: In -> void

  NilFlow = object
    discard

  Flow[Head, Tail] = object
    system: ActorSystem
    head: Head
    tail: Tail

  FlowBuilder[In] = object
    system: ActorSystem

proc createNode[In,Out](f: In -> Out): Node[In,Out] =
  Node[In,Out](f:f)

proc createSource[Out](f: () -> Out): Source[Out] =
  Source[Out](f:f)

proc createSink[In](f: In -> void): Sink[In] =
  Sink[In](f:f)

proc renderNode[In,Out](system: ActorSystem, n: Node[In,Out], subscriber: ActorRef[Out]): ActorRef[In] =
  system.initNode(node[In,Out](n.f), subscriber)

proc render*[Out](flow: NilFlow, subscriber: ActorRef[Out]): ActorRef[Out] =
  subscriber

proc render*[Head,Tail,Out](flow: Flow[Head,Tail], subscriber: ActorRef[Out]): auto =
  let nextRef = renderNode(flow.system, flow.head, subscriber)
  render(flow.tail, nextRef)

proc flow[In](system: ActorSystem): FlowBuilder[In] =
  result.system = system

proc `~>`[In,Out](flow: FlowBuilder[In], node: Node[In,Out]): Flow[Node[In,Out], NilFlow] =
  result.system = flow.system
  result.head = node
  result.tail = NilFlow()

proc `~>`[Head,Tail,In,Out](flow: Flow[Head,Tail], node: Node[In,Out]): Flow[ Node[In,Out], Flow[Head, Tail] ] =
  result.system = flow.system
  result.head = node
  result.tail = flow

# proc fanIn*[In1,In2,Out](leftFlow: Flow[Out,In1], rightFlow: Flow[Out,In2]): Flow[ Out, tuple[left: Flow[Out, In1], right: Flow[Out,In2] ] ] =
#   result.system = leftFlow.system
#   result.tail = (leftFlow, rightFlow)


# proc fanOut*[In,Out](flow: Flow[Out,In]): tuple[left: Flow[Out,In], right: Flow[Out,In]] =
#   (
#     Flow[Out,In](system: flow.system, tail: flow.tail),
#     Flow[Out,In](system: flow.system, tail: flow.tail)
#   )


proc flow[Head,Tail](h:Head,t:Tail): auto = 
  Flow[Head,Tail](head:h,tail:t)


let system = createActorSystem()

let source = createSource(() => 1.int)
let node1: Node[int,float]  = createNode((x: int) => x.float*2.0)
let node2: Node[float,float]  = createNode((x: float) => x/3.0)
let node3: Node[float,float]  = createNode((x: float) => (10*x))
let node4  = createNode((x: int) => x)

let sink   = createSink((x: float) => echo(x))

proc sinkRef[In](system: ActorSystem, sink: Sink[In]): ActorRef[In] =
   system.initActor(sinkNode(sink.f))

let t3 = flow[int](system) ~> node1 ~> node2 ~> node3


# let (fout1, fout2) = fanOut(t)

# let t1 = fout1 ~> node1 ~> node2 ~> node3
# let t2 = fout2 ~> node4

# let myFlow = fanIn(t1, t2)

let sref = system.initActor(sinkNode(sink.f))
let inRef = t3.render(sref)

inRef.send(1)
system.awaitTermination()

