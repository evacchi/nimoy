# Nimoy <img align=right src="img/nimoy.png" alt="(Icon)" />

An experimental minimal actor library for Nim.

## Examples

#### [Ping Pong](examples/pingpong.nim)

```nim
import nimoy

let system = createActorSystem()

let ping = system.createActor() do (self: ActorRef[int], e: Envelope[int]):
  echo "ping has received ", e.message
  e.sender.send(Envelope[int](message: e.message + 1, sender: self))

let pong = system.createActor() do (self: ActorRef[int], e: Envelope[int]):
  echo "pong has received ", e.message
  e.sender.send(Envelope[int](message: e.message + 1, sender: self))

# kick it off
pong.send(Envelope[int](message: 1, sender: ping))

# wait up to 1 second
system.awaitTermination(1)
```

#### [Behavior Hotswapping](examples/become.nim)

```nim
import nimoy

let system = createActorSystem()

# ping receives at least 10 msgs then becomes "done"
let ping = system.createActor() do (self: ActorRef[int]):
  var count = 0
  proc done(self: ActorRef[int], e: Envelope[int]) =
    echo "DISCARD."

  proc receive(self: ActorRef[int], e: Envelope[int]) =
    echo "ping has received ", e.message
    e.sender.send(Envelope[int](message: e.message + 1, sender: self))
    count += 1
    if count >= 10:
      self.become(done)

  self.become(ActorBehavior[int](receive))

# pong responds to ping
let pong = system.createActor() do (self: ActorRef[int]):
  proc receive(self: ActorRef[int], e: Envelope[int]) =
    echo "pong has received ", e.message
    e.sender.send(Envelope[int](message: e.message + 1, sender: self))

  self.become(receive)


# kick it off
pong.send(Envelope[int](message: 1, sender: ping))

# wait up to 1 second
system.awaitTermination(1)
```


## More Features

- [Child actor spawning](examples/spawn.nim)
- [Killing actors](examples/kill.nim)
- [Pluggable execution strategies](src/nimoy/tasks.nim)
- More to come...

### Acknowledgements
Name is courtesy of @mfirry, logo design by @joevanard
