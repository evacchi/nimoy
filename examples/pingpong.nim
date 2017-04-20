import nimoy

type
  # you can Ping someone that will Pong back
  Ping = object 
    replyTo: ActorRef[Pong]
  # you can Pong someone that will Ping back
  Pong = object
    replyTo: ActorRef[Ping]

let system = createActorSystem()

# a ping actor expects Pings, replies with Pongs
let ping = system.initActor do (self: Actor[Ping]):
  self.main.onReceive do (m: Ping): 
    echo "ping received from ", m.replyTo
    m.replyTo ! Pong(replyTo: self.toRef)

# a pong actor expects Pongs, replies with Pings
let pong = system.initActor do (self: Actor[Pong]):
  self.main.onReceive do (m: Pong): 
    echo "pong received from ", m.replyTo
    m.replyTo ! Ping(replyTo: self.toRef)

# kick it off
ping ! Ping(replyTo: pong)

# wait up to 1 second
system.awaitTermination(1)
