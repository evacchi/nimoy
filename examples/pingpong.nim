import nimoy

type
  Ping = object
    sender: ActorRef[Pong]
  Pong = object
    sender: ActorRef[Ping]

let system = createActorSystem()

let ping = system.createActor() do (self: ActorRef[Ping], m: Ping):
  echo "ping received from ", m.sender
  m.sender.send(Pong(sender: self))

let pong = system.createActor() do (self: ActorRef[Pong], m: Pong):
  echo "pong received from ", m.sender
  m.sender.send(Ping(sender: self))

# kick it off
ping.send(Ping(sender: pong))

# wait up to 1 second
system.awaitTermination(1)
