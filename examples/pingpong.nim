import nimoy, os

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
system.awaitTermination(1)
