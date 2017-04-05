import nimoy

type
  # you can Ping someone that will Pong back
  Ping = object 
    sender: ActorRef[Pong]
  # you can Pong someone that will Ping back
  Pong = object
    sender: ActorRef[Ping]

let system = createActorSystem()

# a ping actor expects Pings, replies with Pongs
let ping = system.createActor() do (self: ActorRef[Ping], m: Ping):
  echo "ping received from ", m.sender
  m.sender.send(Pong(sender: self))

# a pong actor expects Pongs, replies with Pings
let pong = system.createActor() do (self: ActorRef[Pong], m: Pong):
  echo "pong received from ", m.sender
  m.sender.send(Ping(sender: self))

# kick it off
ping.send(Ping(sender: pong))

# wait up to 1 second
system.awaitTermination(1)
