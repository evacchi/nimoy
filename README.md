# Nimoy <img align=right src="img/nimoy.png" alt="(Icon)" />

An experimental minimal actor library for Nim.

## Features

- Actor lifecycle control: [spawning children](examples/spawn.nim) and [killing actors](examples/kill.nim)
- Experimental support to [actor topologies](examples/topology.nim)
- Pluggable [execution strategies](src/nimoy/executors.nim)
- More to come...

## Examples

#### [Ping Pong](examples/pingpong.nim)

```nim
import nimoy

type
  # you can Ping someone that will Pong back
  Ping = object 
    replyTo: ActorRef[Pong]
  # you can Pong someone that will Ping back
  Pong = object
    replyTo: ActorRef[Ping]

let system = createActorSystem()

# a ping actor expects Pings, replies with Pongs
let ping = system.createActor() do (self: ActorRef[Ping], m: Ping):
  echo "ping received from ", m.replyTo
  m.replyTo ! Pong(replyTo: self)

# a pong actor expects Pongs, replies with Pings
let pong = system.createActor() do (self: ActorRef[Pong], m: Pong):
  echo "pong received from ", m.replyTo
  m.replyTo ! Ping(replyTo: self)

# kick it off
ping ! Ping(replyTo: pong)

# wait up to 1 second
system.awaitTermination(1)
```

#### [Behavior Hotswapping](examples/become.nim)

```nim
import nimoy

type
  IntMessage = object
    value: int
    replyTo: ActorRef[IntMessage]

let system = createActorSystem()

# ping receives at least 10 msgs then becomes "done"
let ping = system.initActor() do (self: ActorRef[IntMessage]):
  var count = 0
  proc done(m: IntMessage) =
    echo "DISCARD."

  proc receive(m: IntMessage) =
    echo "ping has received ", m.value
    m.replyTo ! IntMessage(value: m.value + 1, replyTo: self)
    count += 1
    if count >= 10:
      self.become(done)

  self.become(receive)

# pong responds to ping
let pong = system.initActor() do (self: ActorRef[IntMessage]):
  proc receive(m: IntMessage) =
    echo "pong has received ", m.value
    m.replyTo ! IntMessage(value: m.value + 1, replyTo: self)

  self.become(receive)


# kick it off
pong ! IntMessage(value: 1, replyTo: ping)

# wait up to 1 second
system.awaitTermination(1)
```

#### [Topologies](examples/topology.nim)

```nim
import future, nimoy, nimoy/topologies

#
# source ~> map1 ~> fanIn ~> map3 ~> broadcast ~> sink1
#    +~~~~> map2 ~~~~~^                 +~~~~> sink2
#  

let t = createTopology()
let sink1 = allocActorChannel[int]()
let sink2 = allocActorChannel[int]()

# declare output sinks
let sink1Ref = t.sinkRef((x: int) => sink1.send(x*100))
let sink2Ref = t.sinkRef((x: int) => sink2.send(x))

# broadcast to both sinks
let bref     = t.broadcastRef(sink1Ref, sink2Ref)

# map to the broadcast
let map3Ref  = t.nodeRef((x: int) => x+7,  bref)

# map to map3
let fanInRef = t.nodeRef((x: int) => ( echo("fan in = ", x); x ), map3Ref)

# two nodes that both go into fanIn
let map1Ref  = t.nodeRef((x: int) => x*2, fanInRef)
let map2Ref  = t.nodeRef((x: int) => x-1, fanInRef)

# send data to both the sources
for i in 0..10:
  map1Ref ! i
  map2Ref ! i

for i in 0..10:
  echo sink1.recv()
  echo sink2.recv()
```



### Acknowledgements
Name is courtesy of @mfirry, logo design by @joevanard
