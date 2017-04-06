import nimoy/tasks, nimoy/executors, future

type
  ActorObj*[A] = object
    sysbox:   Channel[SystemMessage]
    mailbox:  Channel[A]
    behavior: EffectfulBehavior[A]

  Actor*[A] = ptr ActorObj[A]
  ActorRef*[A] = object
    actor: Actor[A]

  SystemMessage* = enum
    sysKill
    
  Behavior*[A] =
    proc(message: A)

  EffectKind = enum
    effStop
    effStay
    effBecome
  Effect*[A] = object
    case kind: EffectKind
    of effStop:
      discard
    of effStay:
      discard
    of effBecome:
      behavior: EffectfulBehavior[A] 

  ContextBehavior*[A] =
    proc(self: ActorRef[A], message: A)
  
  EffectfulBehavior*[A] =
    proc(message: A): Effect[A]
  
  ActorSystem = object
    executor: Executor


proc stay*[A](): Effect[A] =
  Effect[A](kind: effStay)

proc stop*[A](): Effect[A] =
  Effect[A](kind: effStop)

proc nop*[A](message: A): Effect[A] =
  echo "Unitialized actor could not handle message ", message
  stay[A]()

proc become*[A](behavior: EffectfulBehavior[A]): Effect[A] =
  Effect[A](kind: effBecome, behavior: behavior)

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

proc createActor*[A](init: proc(self: ActorRef[A]): Effect[A]): ActorRef[A] =
  var actor = cast[Actor[A]](allocShared0(sizeof(ActorObj[A])))
  actor.sysbox.open()
  actor.mailbox.open()
  actor.behavior = nop
  result = ActorRef[A](actor: actor)
  let eff = init(result)
  case eff.kind:
  of effStop:
    discard
  of effStay:
    discard
  of effBecome:
    actor.behavior = eff.behavior
  
  

proc createActor*[A](receive: EffectfulBehavior[A]): ActorRef[A] =    
  proc init(self: ActorRef[A]): Effect[A] =
    let effect = Behavior[A](receive)
    become(effect.behavior)

  createActor[A](init = init)

proc createActor*[A](receive: Behavior[A]): ActorRef[A] =    
  proc init(self: ActorRef[A]): Effect[A] =
    become(Behavior[A](receive))

  createActor[A](init = init)

proc createActor*[A](receive: ContextBehavior[A]): ActorRef[A] =
  proc init(self: ActorRef[A]): Effect[A] =
    become do (message: A) -> Effect[A]:
      receive(self, message)
      stay[A]()

  createActor[A](init = init)

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
        let eff = actor.behavior(msg)
        case eff.kind:
        of effStop:
          taskContinue
        of effStay:
          taskContinue
        of effBecome:
          actor.behavior = eff.behavior
          taskContinue
      else:
        taskContinue

proc createActorSystem*(executor: Executor): ActorSystem =
  result.executor = executor
  
proc createActorSystem*(): ActorSystem =
  createActorSystem(createSimpleExecutor(2))

proc awaitTermination*(system: ActorSystem) =
  system.executor.awaitTermination()

proc awaitTermination*(system: ActorSystem, maxSeconds: float) =
  system.executor.awaitTermination(maxSeconds)


proc initActor*[A](system: ActorSystem, init: proc(self: ActorRef[A]): Effect[A]): ActorRef[A] =
  let actorRef = createActor[A](init = init)
  let task = actorRef.toTask
  system.executor.submit(task)
  actorRef

proc createActor*[A](system: ActorSystem, receive: Behavior[A]): ActorRef[A] =
  let actorRef = createActor[A](receive = receive)
  let task = actorRef.toTask
  system.executor.submit(task)
  actorRef

proc createActor*[A](system: ActorSystem, receive: ContextBehavior[A]): ActorRef[A] =
  let actorRef = createActor[A](receive = receive)
  let task = actorRef.toTask
  system.executor.submit(task)
  actorRef

