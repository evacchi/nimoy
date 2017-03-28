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

  Effect[A] = object
    effect: proc(behavior: ActorBehavior[A]): ActorBehavior[A]


proc send[A](self: ActorRef[A], message: A, receiver: ActorRef[A]) =
  let e = Envelope(
    message: message,
    sender: self
  )
  cast[Actor](receiver).mailbox.send(e)


proc stay[A]: Effect[A] =
  Effect[A](effect: proc(oldBehavior: ActorBehavior[A]): ActorBehavior[A] = oldBehavior)
proc become[A](newBehavior: ActorBehavior[A]): Effect[A] =
  Effect[A](effect: proc(oldBehavior: ActorBehavior[A]): ActorBehavior[A] = newBehavior)

proc nop[A](self: ActorRef[A], envelope: Envelope[A]): Effect[A] =
  writeLine(stdout, "Unitialized actor could not handle message ", envelope)
  stay[A]()

proc send[A](self: ActorRef[A], message: A) =
  cast[Actor[A]](self).mailbox.send(Envelope[A](message: message, sender: self))

proc send[A](self: ActorRef[A], envelope: Envelope[A]) =
  cast[Actor[A]](self).mailbox.send(envelope)

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
      let effect = actor.behavior(actorRef, msg)
      actor.behavior = effect.effect(actor.behavior)

when isMainModule:

  let foo = createActor[int] do (self: ActorRef[int]) -> ActorBehavior[int]:
    var count = 0
    proc done(self: ActorRef[int], e: Envelope): Effect[int] =
      writeLine(stdout, "DISCARD.")
      stay[int]()

    proc receive(self: ActorRef[int], e: Envelope): Effect[int] =
      writeLine(stdout,
        "foo has received ", e.message)
      e.sender.send(e.message + 1)
      count += 1
      if count >= 10:
        become(done)
      else:
        stay[int]()

    return receive

  let bar = createActor[int] do (self: ActorRef[int]) -> ActorBehavior[int]:
    proc receive(self: ActorRef[int], e: Envelope[int]): Effect[int] =
      writeLine(stdout,
        "bar has received ", e.message)
      e.sender.send(e.message + 1)
      stay[int]()

    return receive

  var executor = createExecutor()
  executor.submit(foo.toTask())
  executor.submit(bar.toTask())

  bar.send(Envelope[int](message: 1, sender: foo))

  executor.start()
