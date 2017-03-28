import sharedtables, sharedlist, deques, nimoypkg/tasks

type
  ActorId = int

  ActorObj = object
    id: ActorId
    mailbox: Channel[Envelope]
    behavior: ActorBehavior

  Actor = ptr ActorObj
  ActorRef = distinct pointer

  Message = int

  Envelope = object
    message:  Message
    sender:   ActorRef

  ActorBehavior =
    proc(context: ActorRef, envelope: Envelope)


proc nop(self: ActorRef, envelope: Envelope) =
  writeLine(stdout, "Unitialized actor could not handle message ", envelope)

proc send(self: ActorRef, message: Message, receiver: ActorRef) =
  let e = Envelope(
    message: message,
    sender: self
  )
  cast[Actor](receiver).mailbox.send(e)

proc become(actor: ActorRef, newBehavior: ActorBehavior) =
  cast[Actor](actor).behavior = newBehavior

proc send(actor: ActorRef, envelope: Envelope) =
  cast[Actor](actor).mailbox.send(envelope)

proc send(actor: Actor, envelope: Envelope) =
  actor.mailbox.send(envelope)

proc createActor(init: proc(self: ActorRef)): auto =
  var actor = cast[Actor](allocShared0(sizeof(ActorObj)))
  actor.mailbox.open()
  actor.behavior = nop
  let actorRef = cast[ActorRef](actor)
  init(actorRef)
  actorRef


proc toTask(actorRef: ActorRef): auto =
  return proc() {.gcsafe.} =
    let actor = cast[Actor](actorRef)
    let (hasMsg, msg) = actor.mailbox.tryRecv()
    if hasMsg:
      actor.behavior(actorRef, msg)



when isMainModule:
  var executor = createExecutor()

  let foo = createActor do (self: ActorRef):
    var count = 0
    proc done(self: ActorRef, e: Envelope) =
      writeLine(stdout, "DISCARD.")

    proc receive(self: ActorRef, e: Envelope) =
      writeLine(stdout,
        "foo has received ", e.message)
      e.sender.send(Envelope(message: e.message + 1, sender: self))
      count += 1
      if count >= 10:
        self.become(done)

    self.become(receive)

  let bar = createActor do (self: ActorRef):
    proc receive(self: ActorRef, e: Envelope) =
      writeLine(stdout,
        "bar has received ", e.message)
      e.sender.send(Envelope(message: e.message + 1, sender: self))

    self.become(receive)




  executor.submit(foo.toTask())
  executor.submit(bar.toTask())

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
