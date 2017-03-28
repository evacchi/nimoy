import sharedtables, sharedlist, deques, nimoypkg/tasks

type

  ActorObj[A] = object
    mailbox: Channel[Envelope[A]]
    behavior: ActorBehavior[A]

  Actor[A] = ptr ActorObj[A]
  ActorRef[A] = distinct pointer

  Envelope[A] = object
    message:  A
    sender:   ActorRef[A]

  ActorBehavior[A] =
    proc(self: ActorRef[A], envelope: Envelope[A]): Effect[A]

  Effect[A] = proc(behavior: ActorBehavior[A]): ActorBehavior[A]



proc send[A](self: ActorRef[A], message: A, receiver: ActorRef[A]) =
  let e = Envelope(
    message: message,
    sender: self
  )
  cast[Actor](receiver).mailbox.send(e)

proc stay[A](oldBehavior: ActorBehavior[A]): ActorBehavior[A] = oldBehavior
proc become[A](newBehavior: ActorBehavior[A]): Effect[A] =
  return proc(oldBehavior: ActorBehavior[A]): ActorBehavior[A] = newBehavior

proc nop[A](self: ActorRef[A], envelope: Envelope[A]): Effect[A] =
  writeLine(stdout, "Unitialized actor could not handle message ", envelope)
  stay[A]


# proc become[A](actor: ActorRef[A], newBehavior: ActorBehavior[A]) =
#   cast[Actor[A]](actor).behavior = newBehavior

proc send[A](actor: ActorRef[A], envelope: Envelope[A]) =
  cast[Actor[A]](actor).mailbox.send(envelope)

proc send[A](actor: Actor[A], envelope: Envelope[A]) =
  actor.mailbox.send(envelope)

proc createActor[A](init: proc(self: ActorRef[A]): ActorBehavior[A]): auto =
  var actor = cast[Actor[A]](allocShared0(sizeof(ActorObj[A])))
  actor.mailbox.open()
  actor.behavior = nop[A]
  let actorRef = cast[ActorRef[A]](actor)
  actor.behavior = init(actorRef)
  actorRef


proc toTask[A](actorRef: ActorRef[A]): auto =
  return proc() {.gcsafe.} =
    let actor = cast[Actor[A]](actorRef)
    let (hasMsg, msg) = actor.mailbox.tryRecv()
    if hasMsg:
      actor.behavior(actorRef, msg)

when isMainModule:
  var executor = createExecutor()

  let foo = createActor[int] do (self: ActorRef[int]) -> ActorBehavior[int]:
    var count = 0
    proc done(self: ActorRef[int], e: Envelope): Effect[Int] =
      writeLine(stdout, "DISCARD.")
      stay[int]

    proc receive(self: ActorRef[int], e: Envelope): Effect[Int] =
      writeLine(stdout,
        "foo has received ", e.message)
      e.sender.send(Envelope(message: e.message + 1, sender: self))
      count += 1
      if count >= 10:
        become(done)
      else:
        stay[int]

    return receive

  let bar = createActor[int] do (self: ActorRef[int]) -> ActorBehavior[int]:
    proc receive(self: ActorRef[int], e: Envelope[int]) =
      writeLine(stdout,
        "bar has received ", e.message)
      e.sender.send(Envelope[int](message: e.message + 1, sender: self))

    return receive




  executor.submit(foo.toTask())
  executor.submit(bar.toTask())

  bar.send(Envelope[int](message: 1, sender: foo))

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
