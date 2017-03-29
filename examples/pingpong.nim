import nimoy, nimoypkg/tasks

let ping = createActor[int] do (self: ActorRef[int], e: Envelope[int]):
  echo "ping has received ", e.message
  e.sender.send(Envelope[int](message: e.message + 1, sender: self))

let pong = createActor do (self: ActorRef[int], e: Envelope[int]):
  echo "pong has received ", e.message
  e.sender.send(Envelope[int](message: e.message + 1, sender: self))

var executor = createExecutor()

executor.submit(ping.toTask())
executor.submit(pong.toTask())

# kick it off 
pong.send(Envelope[int](message: 1, sender: ping))

# start the execution
executor.start()

