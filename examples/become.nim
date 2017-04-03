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

# start the execution
system.awaitTermination(1)
