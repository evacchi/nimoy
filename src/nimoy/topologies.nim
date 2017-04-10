import nimoy, future

type  
  ActorNode*[In, Out] =
    proc(self: ActorRef[In], subscriber: ActorRef[Out])
  
  Topology* = object
    system: ActorSystem
    
proc createTopology*(system: ActorSystem): Topology =
  Topology(system: system)

proc createTopology*(): Topology =
  Topology(system: createActorSystem())

proc awaitTermination*(topology: Topology) =
  topology.system.awaitTermination()


proc initNode*[In,Out](
  topology: Topology, 
  actorNode: ActorNode[In, Out], 
  subscriber: ActorRef[Out]
): ActorRef[In] =
  topology.system.initActor(
    (self: ActorRef[In]) => 
      actorNode(self, subscriber))

proc broadcastRef*[In](
  topology: Topology, 
  subscribers: varargs[ActorRef[In]]): ActorRef[In] =
  let subs = @subscribers
  topology.system.createActor do (self: ActorRef[In], m: In): 
      for s in subs:
        s ! m

proc node*[In,Out]( f: proc(x:In): Out ): ActorNode[In,Out] = 
  (self: ActorRef[In], subscriber: ActorRef[Out]) => 
    self.become((inp: In) => subscriber.send(f(inp)))

proc sinkNode*[In]( f: proc(x:In) ): ActorInit[In] =
  (self: ActorRef[In]) =>
    self.become((inp: In) => f(inp))

proc broadcastNode*[In](node1: ActorRef[In], node2: ActorRef[In]): ActorInit[In] =
  (self: ActorRef[In]) => 
    self.become do (inp: In):
      node1.send(inp)
      node2.send(inp)

proc sinkRef*[In](topology: Topology, f: proc(x:In) ): ActorRef[In] =
   topology.system.initActor(sinkNode(f))

proc nodeRef*[In,Out](topology: Topology, f: proc(x:In): Out, subscriber: ActorRef[Out]): ActorRef[In] =
   topology.initNode(node[In,Out](f), subscriber)
