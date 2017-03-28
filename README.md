#  <img align=right src="img/nimoy.png" alt="Nimoy Icon" /> Nimoy

An experimental minimal actor library for Nim.

```nim
  # foo receives at least 10 msgs then becomes "done"
  let foo = createActor[int] do (self: ActorRef[int]):
    var count = 0
    proc done(self: ActorRef[int], e: Envelope) =
      writeLine(stdout, "DISCARD.")

    proc receive(self: ActorRef[int], e: Envelope) =
      writeLine(stdout,
        "foo has received ", e.message)
      e.sender.send(Envelope(message: e.message + 1, sender: self))
      count += 1
      if count >= 10:
        self.become(done)

    self.become(receive)

  # bar responds to foo
  let bar = createActor do (self: ActorRef[int]):
    proc receive(self: ActorRef[int], e: Envelope[int]) =
      writeLine(stdout,
        "bar has received ", e.message)
      e.sender.send(Envelope[int](message: e.message + 1, sender: self))

    self.become(receive)



  var executor = createExecutor()
  executor.submit(foo.toTask())
  executor.submit(bar.toTask())

  # kick it off 
  bar.send(Envelope[int](message: 1, sender: foo))

  # start the execution
  executor.start()

```
