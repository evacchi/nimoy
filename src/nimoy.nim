import nimoy/tasks, nimoy/executors

type

  ActorInit*[A] =
    proc(self: Actor[A])
    
  ActorBehavior*[A] =
    proc(message: A)

  ActorChannelObj[A] = object
    channel:  Channel[A]
    behavior: ActorBehavior[A]

  ActorChannel[A] = ptr ActorChannelObj[A]

  SystemMessage* = enum
    sysKill
  
  Actor*[A] = object
    sys:  ActorChannel[SystemMessage]
    main*: ActorChannel[A]

  ActorRef*[A] = object
    channel: ActorChannel[A]

  ActorSystem* = object
    executor: Executor

proc nop*[A](message: A) =
  echo "Unitialized actor could not handle message ", message

proc toRef*[A](actorChannel: ActorChannel[A]): ActorRef[A] =
  ActorRef[A](channel: actorChannel)

proc toRef*[A](actor: Actor[A]): ActorRef[A] =
  ActorRef[A](channel: actor.main)

proc becomeOLD*[A](channel: ActorChannel[A], newBehavior: ActorBehavior[A]) =
  channel.behavior = newBehavior

proc onReceive*[A](channel: ActorChannel[A], newBehavior: ActorBehavior[A]) =
  channel.behavior = newBehavior

proc send*[A](actorChannel: ActorChannel[A], message: A) =
  actorChannel.channel.send(message)

proc tryRecv*[A](actorChannel: ActorChannel[A]): tuple[dataAvailable: bool, msg: A] =
  actorChannel.channel.tryRecv()

proc recv*[A](actorChannel: ActorChannel[A]): A =
  actorChannel.channel.recv()

proc send*[A](actorRef: ActorRef[A], message: A) =
  actorRef.channel.send(message)

proc send*[A](actor: Actor[A], message: A) =
  actor.main.send(message)

proc send*[A](actor: Actor[A], sysMessage: SystemMessage) =
  actor.sys.send(sysMessage)

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

proc createActor*[A](init: ActorInit[A]): Actor[A] =
  result = allocActor[A]()
  init(result)

proc createActor*[A](receive: ActorBehavior[A]): Actor[A] =    
  proc init(self: Actor[A]) =
    self.main.onReceive(ActorBehavior[A](receive))

  createActor[A](init = init)

proc toTask*[A](actor: Actor[A]): Task =
  return proc(): TaskStatus {.gcsafe.} =
    let (hasSysMsg, sysMsg) = actor.sys.tryRecv()
    if hasSysMsg:
      case sysMsg
      of sysKill:
        destroyActor(actor)
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
  let actor = createActor[A](init = init)
  let task = actor.toTask
  system.executor.submit(task)
  result.channel = actor.main

proc createActor*[A](system: ActorSystem, receive: ActorBehavior[A]): ActorRef[A] =
  let actor = createActor[A](receive = receive)
  let task = actor.toTask
  system.executor.submit(task)
  result.channel = actor.main
