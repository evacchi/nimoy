import nimoy/tasks

type
  ActorObj*[A] = object
    sysbox: Channel[SystemMessage]
    mailbox: Channel[Envelope[A]]
    behavior: ActorBehavior[A]

  Actor*[A] = ptr ActorObj[A]
  ActorRef*[A] = distinct pointer

  SystemMessage* = enum
    sysKill
    
  Envelope*[A] = object
    message*:  A
    sender*:   ActorRef[A]

  ActorBehavior*[A] =
    proc(context: ActorRef[A], envelope: Envelope[A])

  ActorSystem = object
    executor: Executor


proc nop*[A](self: ActorRef[A], envelope: Envelope[A]) =
  echo "Unitialized actor could not handle message ", envelope

proc send*[A](self: ActorRef[A], message: A, receiver: ActorRef[A]) =
  let e = Envelope(
    message: message,
    sender: self
  )
  cast[Actor](receiver).mailbox.send(e)

proc become*[A](actor: ActorRef[A], newBehavior: ActorBehavior[A]) =
  cast[Actor[A]](actor).behavior = newBehavior

proc send*[A](actor: ActorRef[A], envelope: Envelope[A]) =
  cast[Actor[A]](actor).mailbox.send(envelope)

proc send*[A](actor: Actor[A], envelope: Envelope[A]) =
  actor.mailbox.send(envelope)

proc send*[A](actor: Actor[A], sysMessage: SystemMessage) =
  actor.sysbox.send(sysMessage)

proc send*[A](actor: ActorRef[A], sysMessage: SystemMessage) =
  cast[Actor[A]](actor).sysbox.send(sysMessage)

proc createActor*[A](init: proc(self: ActorRef[A])): ActorRef[A] =
  var actor = cast[Actor[A]](allocShared0(sizeof(ActorObj[A])))
  actor.sysbox.open()
  actor.mailbox.open()
  actor.behavior = nop
  let actorRef = cast[ActorRef[A]](actor)
  init(actorRef)
  actorRef

proc createActor*[A](receive: ActorBehavior[A]): ActorRef[A] =
  createActor[A] do (self: ActorRef[int]):
    self.become(receive)

proc toTask*[A](actorRef: ActorRef[A]): Task =
  return proc(): TaskState {.gcsafe.} =
    let actor = cast[Actor[A]](actorRef)
    let (hasSysMsg, sysMsg) = actor.sysbox.tryRecv()
    if hasSysMsg:
      case sysMsg
      of sysKill:
        taskFinished
    else:
      let (hasMsg, msg) = actor.mailbox.tryRecv()
      if hasMsg:
        actor.behavior(actorRef, msg)
      taskContinue

proc createActorSystem*(executor: Executor): ActorSystem =
  result.executor = executor
  
proc createActorSystem*(): ActorSystem =
  createActorSystem(createSimpleExecutor(2))

proc join*(system: ActorSystem) =
  system.executor.join()

proc createActor*[A](system: ActorSystem, init: proc(self: ActorRef[A])): ActorRef[A] =
  let actorRef = createActor[A](init)
  let task = actorRef.toTask
  system.executor.submit(task)
  actorRef

proc createActor*[A](system: ActorSystem, receive: ActorBehavior[A]): ActorRef[A] =
  let actorRef = createActor[A](receive)
  let task = actorRef.toTask
  system.executor.submit(task)
  actorRef
