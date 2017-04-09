import nimoy, future

type  
  ActorNodeInit[In, Out] =
    proc(self: ActorRef[In], subscriber: ActorRef[Out])
    
  
#   Edge[In,X,Out] = tuple
#     left: ActorNode[In,X]
#     right: ActorNode[X,Out]  

# proc `~>`[A,X,B](left: ActorNode[A,X], right: ActorNode[X,B]): Edge[A,X,B] =
#   (left, right)

proc initNode[In,Out](system: ActorSystem, actorNodeBehavior: ActorNodeInit[In, Out], subscriber: ActorRef[Out]): ActorRef[In] =
  system.initActor() do (self: ActorRef[In]):
    actorNodeBehavior(self, subscriber)


let system = createActorSystem()

let noSender = system.createActor do (self: ActorRef[int], m: int):
  discard
let deadLetters = system.createActor do (self: ActorRef[int], m: int):
  discard
  
proc mapNode[In,Out]( f: proc(x:In): Out ): ActorNodeInit[In,Out] = 
  return proc (self: ActorRef[In], subscriber: ActorRef[Out]) =
        self.become do (inp: In):
          subscriber.send(f(inp))

proc sinkNode[In]( f: proc(x:In) ): ActorInit[In] =
  return proc(self: ActorRef[In]) =
      self.become do (inp: In):
        f(inp)



let sink: ActorInit[int] = sinkNode[int]( (x: int) => echo(x) )
let map2: ActorNodeInit[int, int] = mapNode[int,int]( (x: int) => x-1 )
let map1: ActorNodeInit[int, int] = mapNode[int,int]( (x: int) => x*2 )

let sinkRef = system.initActor(sink)
let map2Ref = system.initNode(map2, sinkRef)
let map1Ref = system.initNode(map1, map2Ref)

# send a tick
for i in 0..10:
  map1Ref.send(i)


# for i in 0..10:
#   map1Ref.send(Envelope[int](message: i, sender: noSender))

# let mapNode    = node(map[int]())
# let sourceNode = node(sink[int]())

system.awaitTermination()

