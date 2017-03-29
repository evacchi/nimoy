import nimoy, nimoypkg/tasks

let ping = createActor[int] do (self: ActorRef[int]):
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

let pong = createActor do (self: ActorRef[int]):
  proc receive(self: ActorRef[int], e: Envelope[int]) =
    echo "pong has received ", e.message
    e.sender.send(Envelope[int](message: e.message + 1, sender: self))

  self.become(receive)


var executor = createExecutor()

executor.submit(ping.toTask())
executor.submit(pong.toTask())

pong.send(Envelope[int](message: 1, sender: ping))

executor.start()

