import nimoy/tasks, nimoy/executors

type
  ActorObj*[A] = object
    sysbox: Channel[SystemMessage]
    mailbox: Channel[A]
    behavior: ActorBehavior[A]

  Actor*[A] = ptr ActorObj[A]
  ActorRef*[A] = object
    actor: Actor[A]

  SystemMessage* = enum
    sysKill
    
  Envelope*[A] = object
    message*:  A
    sender*:   ActorRef[A]

  ActorInit*[A] =
    proc(self: ActorRef[A])
    
  ActorBehavior*[A] =
    proc(message: A)

  ActorContextBehavior*[A] =
    proc(self: ActorRef[A], message: A)

  ActorSystem* = object
    executor: Executor

proc nop*[A](message: A) =
  echo "Unitialized actor could not handle message ", message

proc send*[A](receiver: ActorRef[A], message: A, sender: ActorRef[A]) =
  let e = Envelope(
    message: message,
    sender: sender
  )
  receiver.actor.mailbox.send(e)

proc become*[A](actorRef: ActorRef[A], newBehavior: ActorBehavior[A]) =
  actorRef.actor.behavior = newBehavior

proc send*[A](actor: Actor[A], message: A) =
  actor.mailbox.send(message)

proc send*[A](actorRef: ActorRef[A], message: A) =
  actorRef.actor.send(message)

proc send*[A](actor: Actor[A], sysMessage: SystemMessage) =
  actor.sysbox.send(sysMessage)

proc send*[A](actorRef: ActorRef[A], sysMessage: SystemMessage) =
  actorRef.actor.send(sysMessage)

template `!`*(receiver, message: untyped) =
  receiver.send(message)

proc createActor*[A](init: ActorInit[A]): ActorRef[A] =
  var actor = cast[Actor[A]](allocShared0(sizeof(ActorObj[A])))
  actor.sysbox.open()
  actor.mailbox.open()
  actor.behavior = nop
  let actorRef = ActorRef[A](actor: actor)
  init(actorRef)
  actorRef

proc destroyActor*[A](actor: Actor[A]) =
  deallocShared(actor)

proc createActor*[A](receive: ActorBehavior[A]): ActorRef[A] =    
  proc init(self: ActorRef[A]) =
    self.become(ActorBehavior[A](receive))

  createActor[A](init = init)

proc createActor*[A](receive: ActorContextBehavior[A]): ActorRef[A] =
  proc init(self: ActorRef[A]) =
    self.become do (message: A):
      receive(self, message)

  createActor[A](init = init)

proc toTask*[A](actorRef: ActorRef[A]): Task =
  return proc(): TaskStatus {.gcsafe.} =
    let actor = actorRef.actor
    let (hasSysMsg, sysMsg) = actor.sysbox.tryRecv()
    if hasSysMsg:
      case sysMsg
      of sysKill:
        destroyActor(actorRef.actor)
        taskFinished
    else:
      let (hasMsg, msg) = actor.mailbox.tryRecv()
      if hasMsg:
        actor.behavior(msg)
      taskContinue

proc createActorSystem*(executor: Executor): ActorSystem =
  result.executor = executor
  
proc createActorSystem*(): ActorSystem =
  createActorSystem(createSimpleExecutor(2))

proc awaitTermination*(system: ActorSystem) =
  system.executor.awaitTermination()

proc awaitTermination*(system: ActorSystem, maxSeconds: float) =
  system.executor.awaitTermination(maxSeconds)


proc initActor*[A](system: ActorSystem, init: ActorInit[A]): ActorRef[A] =
  let actorRef = createActor[A](init = init)
  let task = actorRef.toTask
  system.executor.submit(task)
  actorRef

proc createActor*[A](system: ActorSystem, receive: ActorBehavior[A]): ActorRef[A] =
  let actorRef = createActor[A](receive = receive)
  let task = actorRef.toTask
  system.executor.submit(task)
  actorRef

proc createActor*[A](system: ActorSystem, receive: ActorContextBehavior[A]): ActorRef[A] =
  let actorRef = createActor[A](receive = receive)
  let task = actorRef.toTask
  system.executor.submit(task)
  actorRef

