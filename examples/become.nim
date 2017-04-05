import nimoy

type
  IntMessage = object
    value: int
    sender: ActorRef[IntMessage]

let system = createActorSystem()

# ping receives at least 10 msgs then becomes "done"
let ping = system.createActor() do (self: ActorRef[IntMessage]):
  var count = 0
  proc done(self: ActorRef[IntMessage], m: IntMessage) =
    echo "DISCARD."

  proc receive(self: ActorRef[IntMessage], m: IntMessage) =
    echo "ping has received ", m.value
    m.sender.send(IntMessage(value: m.value + 1, sender: self))
    count += 1
    if count >= 10:
      self.become(done)

  self.become(receive)

# pong responds to ping
let pong = system.createActor() do (self: ActorRef[IntMessage]):
  proc receive(self: ActorRef[IntMessage], m: IntMessage) =
    echo "pong has received ", m.value
    m.sender.send(IntMessage(value: m.value + 1, sender: self))

  self.become(receive)


# kick it off
pong.send(IntMessage(value: 1, sender: ping))

# wait up to 1 second
system.awaitTermination(1)
