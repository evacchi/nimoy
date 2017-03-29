import nimoy, nimoypkg/tasks

# ping receives at least 10 msgs then becomes "done"
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

# pong responds to ping
let pong = createActor do (self: ActorRef[int]):
  proc receive(self: ActorRef[int], e: Envelope[int]) =
    echo "pong has received ", e.message
    e.sender.send(Envelope[int](message: e.message + 1, sender: self))

  self.become(receive)


var executor = createExecutor()

executor.submit(ping.toTask())
executor.submit(pong.toTask())

# kick it off
pong.send(Envelope[int](message: 1, sender: ping))

# start the execution
executor.join()
