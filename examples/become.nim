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
