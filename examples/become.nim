import nimoy

type
  IntMessage = object
    value: int
    replyTo: ActorRef[IntMessage]

let system = createActorSystem()

# ping receives at least 10 msgs then becomes "done"
let ping = system.initActor() do (self: ActorRef[IntMessage]) -> Effect[IntMessage]:
  var count = 0
  proc done(m: IntMessage): Effect[IntMessage] =
    echo "DISCARD."
    stay[IntMessage]()

  proc receive(m: IntMessage): Effect[IntMessage] =
    echo "ping has received ", m.value
    m.replyTo ! IntMessage(value: m.value + 1, replyTo: self)
    count += 1
    if count >= 10:
      become[IntMessage](done)
    else:
      stay[IntMessage]()

  become[IntMessage](receive)

# pong responds to ping
let pong = system.createActor() do (self: ActorRef[IntMessage], m: IntMessage):
  echo "pong has received ", m.value
  m.replyTo ! IntMessage(value: m.value + 1, replyTo: self)

# kick it off
pong ! IntMessage(value: 1, replyTo: ping)

# wait up to 1 second
system.awaitTermination(1)
