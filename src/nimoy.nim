import sharedtables, sharedlist, deques, nimoypkg/tasks

type
  ActorId = int

  Actor = object
    id: ActorId
    mailbox: SharedChannel[Envelope]
    behavior: ActorBehavior

  Message = int

  Envelope = object
    message:  Message
    sender:   Actor

  ActorBehavior =
    proc(context: var Actor, envelope: Envelope)


proc nop(self: var Actor, envelope: Envelope) =
  writeLine(stdout, self, ": Unitialized actor could not handle message ", envelope)

proc send(self: var Actor, message: Message, receiver: Actor) =
  let e = Envelope(
    message: message,
    sender: self
  )
  receiver.mailbox.send(e)

proc become(actor: var Actor, newBehavior: ActorBehavior) =
  actor.behavior = newBehavior

# proc createActor(system: var ActorSystem, id: ActorId, init: ActorInit): Actor =
#   var actor = Actor(id: id, mailbox: newSharedChannel[Envelope](), behavior: nop)
#   var currentContext = system.createActorContext(actor)
#   init(currentContext)
#   actor.behavior = currentContext.behavior
#   actor

proc send(actor: Actor, envelope: Envelope) =
  actor.mailbox.send(envelope)


proc makeTask(init: proc(self: var Actor)): auto =
  var channel = newSharedChannel[Envelope]()
  var actor = Actor(mailbox: channel, behavior: nop)
  init(actor)
  echo $(actor)
  let t = proc() {.gcsafe.} =
    let (hasMsg, msg) = actor.mailbox.tryRecv()
    if hasMsg:
      actor.behavior(actor, msg)


  (actor, t)

when isMainModule:
  var executor = createExecutor()

  let (foo, tfoo) = makeTask do (self: var Actor):
    var count = 0
    proc done(self: var Actor, e: Envelope) =
      writeLine(stdout, "DONE.")

    proc receive(self: var Actor, e: Envelope) =
      writeLine(stdout,
        "foo has received ", e.message, " from ", e.sender)
      e.sender.mailbox.send(Envelope(message: e.message + 1, sender: self))
      count += 1
      if count >= 10:
        self.become(done)

    self.become(receive)

  let (bar, tbar) = makeTask do (self: var Actor):
    proc receive(self: var Actor, e: Envelope) =
      writeLine(stdout,
        "bar has received ", e.message, " from ", e.sender)
      e.sender.send(Envelope(message: e.message + 1, sender: self))
      e.sender.send(Envelope(message: e.message - 1, sender: self))

    self.become(receive)




  executor.submit(tfoo)
  executor.submit(tbar)

  bar.send(Envelope(message: 1, sender: foo))

  executor.start()


  # let barRef = system.createActor(200) do (context: var ActorContext):
  #   writeLine(stdout, "startup 200")
  #   context.send(Message(1), fooRef)

  #   # state
  #   var i = 1000

  #   proc done(context: var ActorContext, e: Envelope) =
  #     writeLine(stdout, "DONE.")

  #   proc receive(context: var ActorContext, e: Envelope) =
  #     writeLine(stdout,
  #       context.self, " has received ", e.message, " from ", e.sender)
  #     context.send(Message(e.message + 1), e.sender)
  #     i = i - 1
  #     if (i <= 100):
  #       context.become(done)

  #   context.become(receive)

  # let bazRef = system.createActor(300) do (context: var ActorContext):
  #   writeLine(stdout, "startup 300")
  #   context.send(Message(3), fooRef)

  #   var i = 1000

  #   proc done(context: var ActorContext, e: Envelope) =
  #     writeLine(stdout, "DONE.")

  #   proc receive(context: var ActorContext, e: Envelope) =
  #     writeLine(stdout, context.self, " has received ", e.message, " from ", e.sender)
  #     context.send(Message(e.message + 1), e.sender)
  #     i = i - 1
  #     if (i <= 100):
  #       context.become(done)

  #   context.become(receive)


# proc createActor(system: var ActorSystem, id: ActorId, init: ActorInit): Actor =
#   var actor = Actor(id: id, mailbox: newSharedChannel[Envelope](), behavior: nop)
#   var currentContext = system.createActorContext(actor)
#   init(currentContext)
#   actor.behavior = currentContext.behavior
#   actor
