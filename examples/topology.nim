import nimoy, future

type
  ActorNode[In, Out] =
    proc(subscriber: ActorRef[Out]): ActorInit[In]
  
  SourceCommand = enum
    Next
  
  Edge[In,X,Out] = tuple
    left: ActorNode[In,X]
    right: ActorNode[X,Out]  

proc `~>`[A,X,B](left: ActorNode[A,X], right: ActorNode[X,B]): Edge[A,X,B] =
  (left, right)

let system = createActorSystem()

let noSender = system.createActor do (self: ActorRef[int], m: int):
  discard
let deadLetters = system.createActor do (self: ActorRef[int], m: int):
  discard
  
proc mapNode[In,Out]( f: proc(x:In): Out ): ActorNode[In,Out] = 
  return proc (subscriber: ActorRef[Out]): ActorInit[In] =
      return proc(self: ActorRef[In]) =
        self.become do (inp: In):
          subscriber.send(f(inp))

proc sinkNode[In]( f: proc(x:In) ): ActorInit[In] =
  return proc(self: ActorRef[In]) =
      self.become do (inp: In):
        f(inp)



proc sourceNode[Out]( iter: iterator(): Out ): ActorNode[SourceCommand,Out] =
  return proc (subscriber: ActorRef[Out]): ActorInit[SourceCommand] =
    return proc(self: ActorRef[SourceCommand]) =
      self.become do (e: SourceCommand):
        subscriber.send(iter())


let src: ActorNode[SourceCommand,int]  = sourceNode[int](
  iterator(): int = 
    for i in 0..10: 
      yield i 
)
let sink: ActorInit[int] = sinkNode[int]( (x: int) => echo(x) )
let map2: ActorNode[int, int] = mapNode[int,int]( (x: int) => x-1 )
let map1: ActorNode[int, int] = mapNode[int,int]( (x: int) => x*2 )

let sinkRef = system.initActor(sink)
let map2Ref = system.initActor(map2(sinkRef))
let map1Ref = system.initActor(map1(map2Ref))
let srcRef  = system.initActor(src(map1Ref))

# send a tick
for i in 0..10:
  srcRef.send(Next)


# for i in 0..10:
#   map1Ref.send(Envelope[int](message: i, sender: noSender))

# let mapNode    = node(map[int]())
# let sourceNode = node(sink[int]())

system.awaitTermination()

