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
  actorNodeBehavior: 
  ActorNode[In, Out], 
  subscriber: ActorRef[Out]): ActorRef[In] =
  system.initActor(
    (self: ActorRef[In]) => 
      actorNodeBehavior(self, subscriber))

proc mapNode[In,Out]( f: proc(x:In): Out ): ActorNode[In,Out] = 
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

# nodes
let sink1: ActorInit[int] = sinkNode[int]( (x: int) => echo("sink1 = ", x) )
let sink2: ActorInit[int] = sinkNode[int]( (x: int) => echo("sink2 = ", x) )

let fanIn: ActorNode[int, int] = mapNode[int,int] do (x:int) -> int:
  echo("fan in = ", x) 
  x

let map3: ActorNode[int, int] = mapNode[int,int]( (x: int) => x+7 )
let map2: ActorNode[int, int] = mapNode[int,int]( (x: int) => x-1 )
let map1: ActorNode[int, int] = mapNode[int,int]( (x: int) => x*2 )

# instantiate topology
let system = createActorSystem()

#
# source ~> map1 ~> fanIn ~> map3 ~> fanOut ~> sink1
# source ~> map2 ~~~~~^                 +~~~~> sink2
#


let sink1Ref = system.initActor(sink1)
let sink2Ref = system.initActor(sink2)
let fanOut: ActorInit[int] = fanOutNode[int]( sink1Ref, sink2Ref )
let fanOutRef = system.initActor(fanOut)

let map3Ref = system.initNode(map3, fanOutRef)
let fanInRef = system.initNode(fanIn, map3Ref)
let map2Ref = system.initNode(map2, fanInRef)
let map1Ref = system.initNode(map1, fanInRef)

# send input
for i in 0..10:
  map1Ref ! i

system.awaitTermination()

