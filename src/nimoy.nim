import nimoy/tasks, nimoy/executors

type
  ActorObj*[A] = object
    sysbox: Channel[SystemMessage]
    mailbox: Channel[Envelope[A,any]]
    behavior: ActorBehavior[A]

  Actor*[A] = ptr ActorObj[A]
  ActorRef*[A] = object
    actor: Actor[A]

  SystemMessage* = enum
    sysKill
    
  Envelope*[A,B] = object
    message*:  A
    sender*:   ActorRef[B]

  ActorBehavior*[A,B] =
    proc(self: ActorRef[A], envelope: Envelope[A])

  ActorSystem* = object
    executor: Executor

proc nop*[A](self: ActorRef[A], envelope: Envelope[A]) =
  echo "Unitialized actor could not handle message ", envelope

proc send*[A](receiver: ActorRef[A], message: A, sender: ActorRef[A]) =
  let e = Envelope(
    message: message,
    sender: sender
  )
  receiver.actor.mailbox.send(e)

proc become*[A,B](actorRef: ActorRef[A], newBehavior: ActorBehavior[A,B]) =
  actorRef.actor.behavior = newBehavior

proc send*[A,B](actor: Actor[A,B], envelope: Envelope[A]) =
  actor.mailbox.send(envelope)

proc send*[A](actorRef: ActorRef[A], envelope: Envelope[A]) =
  actorRef.actor.send(envelope)

proc send*[A,B](actor: Actor[A,B], sysMessage: SystemMessage) =
  actor.sysbox.send(sysMessage)

proc send*[A](actorRef: ActorRef[A], sysMessage: SystemMessage) =
  actorRef.actor.send(sysMessage)

proc createActor*[A,B](init: proc(self: ActorRef[A])): ActorRef[A] =
  var actor = cast[Actor[A,B]](allocShared0(sizeof(ActorObj[A,B])))
  actor.sysbox.open()
  actor.mailbox.open()
  actor.behavior = nop
  let actorRef = ActorRef[A](actor: actor)
  init(actorRef)
  actorRef

proc createActor*[A,B](receive: ActorBehavior[A,B]): ActorRef[A] =
  createActor[A,B] do (self: ActorRef[A]):
    self.become(receive)

proc toTask*[A](actorRef: ActorRef[A]): Task =
  return proc(): TaskStatus {.gcsafe.} =
    let actor = actorRef.actor
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

proc awaitTermination*(system: ActorSystem) =
  system.executor.awaitTermination()

proc awaitTermination*(system: ActorSystem, maxSeconds: float) =
  system.executor.awaitTermination(maxSeconds)


proc createActor*[A,B](system: ActorSystem, init: proc(self: ActorRef[A])): ActorRef[A] =
  let actorRef = createActor[A,B](init)
  let task = actorRef.toTask
  system.executor.submit(task)
  actorRef

proc createActor*[A,B](system: ActorSystem, receive: ActorBehavior[A,B]): ActorRef[A] =
  let actorRef = createActor[A,B](receive)
  let task = actorRef.toTask
  system.executor.submit(task)
  actorRef
