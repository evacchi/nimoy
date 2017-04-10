import nimoy, future

type  
  ActorNode[In, Out] =
    proc(self: ActorRef[In], subscriber: ActorRef[Out])
    
#   Edge[In,X,Out] = tuple
#     left: ActorNode[In,X]
#     right: ActorNode[X,Out]  

# proc `~>`[A,X,B](left: ActorNode[A,X], right: ActorNode[X,B]): Edge[A,X,B] =
#   (left, right)

proc initNode[In,Out](
  system: ActorSystem, 
  actorNode: ActorNode[In, Out], 
  subscriber: ActorRef[Out]
): ActorRef[In] =
  system.initActor(
    (self: ActorRef[In]) => 
      actorNode(self, subscriber))

proc createFanOutRef[In](
  system: ActorSystem, 
  subscribers: varargs[ActorRef[In]]): ActorRef[In] =
  let subs = @subscribers
  system.createActor do (self: ActorRef[In], m: In): 
      for s in subs:
        s ! m

proc node[In,Out]( f: proc(x:In): Out ): ActorNode[In,Out] = 
  (self: ActorRef[In], subscriber: ActorRef[Out]) => 
    self.become((inp: In) => subscriber.send(f(inp)))

proc sinkNode[In]( f: proc(x:In) ): ActorInit[In] =
  (self: ActorRef[In]) =>
    self.become((inp: In) => f(inp))

proc fanOutNode[In](node1: ActorRef[In], node2: ActorRef[In]): ActorInit[In] =
  (self: ActorRef[In]) => 
    self.become do (inp: In):
      node1.send(inp)
      node2.send(inp)

proc createSinkRef[In](system: ActorSystem, f: proc(x:In) ): ActorRef[In] =
   system.initActor(sinkNode(f))

proc createNodeRef[In,Out](system: ActorSystem, f: proc(x:In): Out, subscriber: ActorRef[Out]): ActorRef[In] =
   system.initNode(node[In,Out](f), subscriber)


# instantiate topology
let system = createActorSystem()

#
# source ~> map1 ~> fanIn ~> map3 ~> fanOut ~> sink1
#    +~~~~> map2 ~~~~~^                 +~~~~> sink2
#  

let sink1Ref  = system.createSinkRef((x: int) => echo("sink1 = ", x))
let sink2Ref  = system.createSinkRef((x: int) => echo("sink2 = ", x))
let fanOutRef = system.createFanOutRef(sink1Ref, sink2Ref)
let map3Ref   = system.createNodeRef((x: int) => x+7, fanOutRef)
let fanInRef  = system.createNodeRef((x: int) => ( echo("fan in = ", x); x ), map3Ref)
let map2Ref   = system.createNodeRef((x: int) => x-1, fanInRef)
let map1Ref   = system.createNodeRef((x: int) => x*2, fanInRef)

# send input
for i in 0..10:
  map1Ref ! i

system.awaitTermination()

