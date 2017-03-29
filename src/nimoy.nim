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
    proc(context: ActorRef[A], envelope: Envelope[A])


proc nop[A](self: ActorRef[A], envelope: Envelope[A]) =
  writeLine(stdout, "Unitialized actor could not handle message ", envelope)

proc send[A](self: ActorRef[A], message: A, receiver: ActorRef[A]) =
  let e = Envelope(
    message: message,
    sender: self
  )
  cast[Actor](receiver).mailbox.send(e)

proc become[A](actor: ActorRef[A], newBehavior: ActorBehavior[A]) =
  cast[Actor[A]](actor).behavior = newBehavior


proc send[A](sender: ActorRef[A], message: A) =
  cast[Actor[A]](sender).mailbox.send(Envelope[A](message: message, sender: sender))

proc send[A](actor: ActorRef[A], envelope: Envelope[A]) =
  cast[Actor[A]](actor).mailbox.send(envelope)

proc send[A](actor: Actor[A], envelope: Envelope[A]) =
  actor.mailbox.send(envelope)

proc createActor[A](init: proc(self: ActorRef[A])): auto =
  var actor = cast[Actor[A]](allocShared0(sizeof(ActorObj[A])))
  actor.mailbox.open()
  actor.behavior = nop
  let actorRef = cast[ActorRef[A]](actor)
  init(actorRef)
  actorRef


proc toTask[A](actorRef: ActorRef[A]): auto =
  return proc() {.gcsafe.} =
    let actor = cast[Actor[A]](actorRef)
    let (hasMsg, msg) = actor.mailbox.tryRecv()
    if hasMsg:
      actor.behavior(actorRef, msg)



when isMainModule:

  let foo = createActor[int] do (self: ActorRef[int]):
    var count = 0
    proc done(self: ActorRef[int], e: Envelope[int]) =
      echo "DISCARD."

    proc receive(self: ActorRef[int], e: Envelope[int]) =
      echo "foo has received ", e.message
      e.sender.send(e.message + 1)
      count += 1
      if count >= 10:
        self.become(done)

    self.become(ActorBehavior[int](receive))

  let bar = createActor do (self: ActorRef[int]):
    proc receive(self: ActorRef[int], e: Envelope[int]) =
      echo "bar has received ", e.message
      e.sender.send(e.message + 1)

    self.become(receive)


  var executor = createExecutor()

  executor.submit(foo.toTask())
  executor.submit(bar.toTask())

  bar.send(Envelope[int](message: 1, sender: foo))

  executor.start()

