import nimoy

let system = createActorSystem()

let ping = system.createActor() do (self: ActorRef[int], e: Envelope[int]):
  echo "ping has received ", e.message
  if (e.message != 10):
    e.sender.send(Envelope[int](message: e.message + 1, sender: self))
  else:
    echo "DON'T YOU DARE SENDING 10!"
    e.sender.send(sysKill)
    # next message won't be delivered
    e.sender.send(Envelope[int](message: e.message + 1, sender: self))
    # self-destruct
    self.send(sysKill)

let pong = system.createActor() do (self: ActorRef[int], e: Envelope[int]):
  echo "pong has received ", e.message
  e.sender.send(Envelope[int](message: e.message + 1, sender: self))

# kick it off
pong.send(Envelope[int](message: 1, sender: ping))

# wait
system.awaitTermination()
