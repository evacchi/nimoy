import nimoy

type
  IntMessage = object
    value: int
    sender: ActorRef[IntMessage]

let system = createActorSystem()

let ping = system.createActor() do (self: ActorRef[IntMessage], m: IntMessage):
  echo "ping has received ", m.value
  if m.value != 10:
    m.sender.send(IntMessage(value: m.value + 1, sender: self))
  else:
    let pingChild = system.createActor() do (self: ActorRef[IntMessage], m: IntMessage):
      echo "pingChild has received ", m.value
      m.sender.send(IntMessage(value: m.value + 1, sender: self))
    pingChild.send(m)


let pong = system.createActor() do (self: ActorRef[IntMessage], m: IntMessage):
  echo "pong has received ", m.value  
  m.sender.send(IntMessage(value: m.value + 1, sender: self))

# kick it off
pong.send(IntMessage(value: 1, sender: ping))

# wait
system.awaitTermination(1)
