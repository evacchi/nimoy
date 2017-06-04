import nimoy/tasks, nimoy/executors, nimoy/slist, options

type

  ActorInit*[A] =
    proc(self: ActorRef[A])
    
  ActorBehavior*[A] =
    proc(message: A)

  ActorContextBehavior*[A] =
    proc(ctx: ActorRef[A], message: A)

  ActorChannel[A] = object
    channel:  SharedList[A]
    behavior: ActorBehavior[A]

  SystemMessage* = enum
    sysKill
  
  Actor*[A] = object
    sys:  ActorChannel[SystemMessage]
    main: ActorChannel[A]

  ActorRef*[A] = ptr Actor[A]
    
  Envelope*[A] = object
    message*:  A
    sender*:   ActorRef[A]

  ActorSystem* = object
    executor: Executor

proc nop*[A](message: A) =
  echo "Unitialized actor could not handle message ", message

proc become*[A](actorRef: ActorRef[A], newBehavior: ActorBehavior[A]) =
  actorRef.main.behavior = newBehavior
  let env = rawEnv(newBehavior)
  let r = cast[RootRef](env)
  GC_ref(r)


proc send*[A](actorChannel: ActorChannel[A], message: A) =
  actorChannel.channel.enqueue(message)

proc tryRecv*[A](actorChannel: ActorChannel[A]): tuple[dataAvailable: bool, msg: A] =
  let ch = actorChannel.channel
  let r = ch.dequeue()
  result.dataAvailable = r.isSome
  if r.isSome:
    result.msg = r.get

#proc recv*[A](actorChannel: ActorChannel[A]): A =
#  actorChannel.channel.recv()

# proc send*[A](actor: Actor[A], message: A) =
#   actor.main.send(message)

proc send*[A](actorRef: ActorRef[A], message: A) =
  assert actorRef!=nil  
  actorRef.main.send(message)

# proc send*[A](actor: Actor[A], sysMessage: SystemMessage) =
#   actor.sys.send(sysMessage)

proc send*[A](actorRef: ActorRef[A], sysMessage: SystemMessage) =
  actorRef.sys.send(sysMessage)

template `!`*(receiver, message: untyped) =
  receiver.send(message)

proc allocActorChannel*[A](): ActorChannel[A] =
  result.channel = initSharedList[A]()
  result.behavior = nop

proc destroyActorChannel*[A](actorChannel: ActorChannel[A]) =
  deallocShared(actorChannel)

proc allocActor*[A](): ActorRef[A] =
  result = cast[ActorRef[A]](allocShared0(sizeof(Actor[A])))
  result.main = allocActorChannel[A]()
  result.sys  = allocActorChannel[SystemMessage]()

proc destroyActor*[A](actor: Actor[A]) =
  discard
  #deallocShared(actor.main)
  #deallocShared(actor.sys)

proc createActor*[A](init: ActorInit[A]): ActorRef[A] =
  result = allocActor[A]()
  init(result)

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
  proc actorTask(pp: pointer): TaskStatus =
    assert pp != nil
    let actorRef = cast[ActorRef[A]](pp)
    let (hasSysMsg, sysMsg) = actorRef.sys.tryRecv()
    if hasSysMsg:
      case sysMsg
      of sysKill:
        #destroyActor(actorRef)
        taskFinished
    else:
      let (hasMsg, msg) = actorRef.main.tryRecv()
      if hasMsg:
        actorRef.main.behavior(msg)
      taskContinue
  return Task(p:actorTask, pp: actorRef)

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

