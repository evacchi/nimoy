# Nimoy <img align=right src="img/nimoy.png" alt="(Icon)" />

An experimental minimal actor library for Nim.

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

# wait
system.join()
```

## Features

- [Actor behavior hot-swapping](examples/become.nim)
- [Child actor spawning](examples/spawn.nim)
- [Pluggable execution strategies](src/nimoy/tasks.nim)

### Acknowledgements
Name is courtesy of @mfirry, logo design by @joevanard
