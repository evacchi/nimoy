import nimoy, future

type
  ActorProto[A] =
    proc(self: ActorRef[A])

  ActorNodeFactory[In, Out] =
    proc(subscriber: ActorRef[Out]): ActorProto[Out]
  
  ActorNode[In, Out] = object
    factory: ActorNodeFactory[In, Out]
  
#   Edge[A,B] = tuple
#     left: ActorNode[A]
#     right: ActorNode[B]


# proc `~>`[A,B](left: ActorNode[A], right: ActorNode[B]): Edge[A,B] =
#   (left, right)


proc node[In,Out](factory: ActorNodeFactory[In,Out]): ActorNode[In,Out] =
  ActorNode[In,Out](factory: factory)

let system = createActorSystem()

let noSender = system.createActor do (self: ActorRef[void], e: Envelope[void]):
  discard
  
proc mapNode[In,Out]( f: proc(x:In): Out ): ActorNode[In,Out] = 
  node[In,Out](
    proc (subscriber: ActorRef[Out]): ActorProto[In] =
      return proc(self: ActorRef[In]) =
        self.become do (self: ActorRef[In], e: Envelope[In]):
          subscriber.send(Envelope[Out](message: f(e.message), sender: self))
  )

proc sinkNode[In]( f: proc(x:In) ): ActorNode[In,void] =
  node[In,void](
    proc (subscriber: ActorRef[void]): ActorProto[In] =
      return proc(self: ActorRef[In]) =
        self.become do (self: ActorRef[In], e: Envelope[In]):
          f(e.message)
  )


type 
  Pull = void

proc sourceNode[Out]( iter: iterator(): Out ): ActorNode[void,Out] =
  node[void,Out](
    proc (subscriber: ActorRef[Out]): ActorProto[void] =
      return proc(self: ActorRef[void]) =
        self.become do (self: ActorRef[void], e: Envelope[void]):
          subscriber.send(Envelope[Out](message: iter(), sender: self))
  )




let src: ActorNode[void,int]  = sourceNode[int](
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
  srcRef.send(Envelope[void]())


# for i in 0..10:
#   map1Ref.send(Envelope[int](message: i, sender: noSender))

# let mapNode    = node(map[int]())
# let sourceNode = node(sink[int]())

system.awaitTermination()

