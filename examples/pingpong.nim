import nimoy, os

let system = createActorSystem()

let ping: ActorRef[int] = createActor[int,int](system) do (self:ActorRef[int]):
  self.become do (self: ActorRef[int], e: Envelope[int]):
    echo "ping has received ", e.message
    e.sender.send(Envelope[int](message: e.message + 1, sender: self))

let pong = system.createActor[int,int]() do (self: ActorRef[int], e: Envelope[int]):
  echo "pong has received ", e.message
  e.sender.send(Envelope[int](message: e.message + 1, sender: self))

# kick it off
pong.send(Envelope[int](message: 1, sender: ping))

# wait
system.awaitTermination(1)
