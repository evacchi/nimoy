import nimoy/tasks, nimoy/executors

type

  ActorInit*[A] =
    proc(self: ActorRef[A])
    
  ActorBehavior*[A] =
    proc(message: A)

  ActorContextBehavior*[A] =
    proc(ctx: ActorRef[A], message: A)

  ActorChannelObj[A] = object
    channel:  Channel[A]
    behavior: ActorBehavior[A]

  ActorChannel[A] = ptr ActorChannelObj[A]

  SystemMessage* = enum
    sysKill
  
  Actor*[A] = object
    sys:  ActorChannel[SystemMessage]
    main: ActorChannel[A]

  ActorRef*[A] = object
    actor: Actor[A]
    
  Envelope*[A] = object
    message*:  A
    sender*:   ActorRef[A]

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
  actorRef.actor.main.behavior = newBehavior

proc send*[A](actorChannel: ActorChannel[A], message: A) =
  actorChannel.channel.send(message)

proc tryRecv*[A](actorChannel: ActorChannel[A]): tuple[dataAvailable: bool, msg: A] =
  actorChannel.channel.tryRecv()

proc recv*[A](actorChannel: ActorChannel[A]): A =
  actorChannel.channel.recv()

proc send*[A](actor: Actor[A], message: A) =
  actor.main.send(message)

proc send*[A](actorRef: ActorRef[A], message: A) =
  actorRef.actor.send(message)

proc send*[A](actor: Actor[A], sysMessage: SystemMessage) =
  actor.sys.send(sysMessage)

proc send*[A](actorRef: ActorRef[A], sysMessage: SystemMessage) =
  actorRef.actor.send(sysMessage)

template `!`*(receiver, message: untyped) =
  receiver.send(message)

proc allocActorChannel*[A](): ActorChannel[A] =
  result = cast[ActorChannel[A]](allocShared0(sizeof(ActorChannelObj[A])))
  result.channel.open()
  result.behavior = nop

proc destroyActorChannel*[A](actorChannel: ActorChannel[A]) =
  deallocShared(actorChannel)

proc allocActor[A](): Actor[A] =
  result.main = allocActorChannel[A]()
  result.sys  = allocActorChannel[SystemMessage]()

proc destroyActor*[A](actor: Actor[A]) =
  deallocShared(actor.main)
  deallocShared(actor.sys)

proc createActor*[A](init: ActorInit[A]): ActorRef[A] =
  var actor = allocActor[A]()
  let actorRef = ActorRef[A](actor: actor)
  init(actorRef)
  actorRef

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
    let (hasSysMsg, sysMsg) = actor.sys.tryRecv()
    if hasSysMsg:
      case sysMsg
      of sysKill:
        destroyActor(actorRef.actor)
        taskFinished
    else:
      let (hasMsg, msg) = actor.main.tryRecv()
      if hasMsg:
        actor.main.behavior(msg)
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

