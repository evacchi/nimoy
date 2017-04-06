import nimoy, future

type
  Props[A] =
    proc(self: ActorRef[A])

  ActorNodeFactory[In, Out] =
    proc(subscriber: ActorRef[Out]): Props[In]
  
  ActorNode[In, Out] = object
    factory: ActorNodeFactory[In, Out]

  SourceCommand = enum
    Next
  
  Edge[In,X,Out] = tuple
    left: ActorNode[In,X]
    right: ActorNode[X,Out]  



proc `~>`[A,X,B](left: ActorNode[A,X], right: ActorNode[X,B]): Edge[A,X,B] =
  (left, right)


proc node[In,Out](factory: ActorNodeFactory[In,Out]): ActorNode[In,Out] =
  ActorNode[In,Out](factory: factory)

let system = createActorSystem()

let noSender = system.createActor do (self: ActorRef[int], m: int):
  discard
  
proc mapNode[In,Out]( f: proc(x:In): Out ): ActorNode[In,Out] = 
  node[In,Out](
    proc (subscriber: ActorRef[Out]): Props[In] =
      return proc(self: ActorRef[In]) =
        self.become do (self: ActorRef[In], inp: In):
          subscriber.send(f(inp))
  )

proc sinkNode[In]( f: proc(x:In) ): ActorNode[In,int] =
  node[In,int](
    proc (subscriber: ActorRef[int]): Props[In] =
      return proc(self: ActorRef[In]) =
        self.become do (self: ActorRef[In], inp: In):
          f(inp)
  )


proc sourceNode[Out]( iter: iterator(): Out ): ActorNode[SourceCommand,Out] =
  node[SourceCommand,Out](
    proc (subscriber: ActorRef[Out]): Props[SourceCommand] =
      return proc(self: ActorRef[SourceCommand]) =
        self.become do (self: ActorRef[SourceCommand], e: SourceCommand):
          subscriber.send(iter())
  )

let src: ActorNode[SourceCommand,int]  = sourceNode[int](
  iterator(): int = 
    for i in 0..10: 
      yield i 
)
let sink = sinkNode[int]( (x: int) => echo(x) )
let map2 = mapNode[int,int] ( (x: int) => x-1 )
let map1 = mapNode[int,int] ( (x: int) => x*2 )

let sinkRef = system.createActor(sink.factory(noSender))
let map2Ref = system.createActor(map2.factory(sinkRef))
let map1Ref = system.createActor(map1.factory(map2Ref))
let srcRef  = system.createActor(src.factory(map1Ref))

# send a tick
for i in 0..10:
  srcRef.send(Next)


# for i in 0..10:
#   map1Ref.send(Envelope[int](message: i, sender: noSender))

# let mapNode    = node(map[int]())
# let sourceNode = node(sink[int]())

system.awaitTermination()

