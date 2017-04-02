import nimoy/tasks

type
  ActorObj*[A] = object
    system: ActorSystem[A]
    parent: ActorRef[A]
    sysbox: Channel[SystemMessage]
    mailbox: Channel[Envelope[A]]
    behavior: ActorBehavior[A]
    children: seq[ActorRef[A]]

  Actor*[A] = ptr ActorObj[A]
  ActorRef*[A] = distinct pointer

  SystemMessage* = enum
    sysKill
    
  Envelope*[A] = object
    message*:  A
    sender*:   ActorRef[A]

  ActorBehavior*[A] =
    proc(context: ActorRef[A], envelope: Envelope[A])

  ActorSystem[A] = object
    executor: Executor
    children: seq[ActorRef[A]]

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

proc system[A](actorRef: ActorRef[A]): ActorSystem[A] =
  cast[Actor[A]](actorRef).system

proc parent[A](actorRef: ActorRef[A]): ActorRef[A] =
  cast[Actor[A]](actorRef).parent

proc allocActor[A](system: ActorSystem[A], parent: ActorRef[A], init: proc(self: ActorRef[A])): ActorRef[A] =
  var actor = cast[Actor[A]](allocShared0(sizeof(ActorObj[A])))
  actor.sysbox.open()
  actor.mailbox.open()
  actor.children = @[]
  actor.behavior = nop
  actor.system = system
  actor.parent = parent
  if cast[pointer](parent) != nil:
    cast[Actor[A]](parent).children.add(result)

  result = cast[ActorRef[A]](actor)
  init(result)

proc createActor*[A](parent: ActorRef[A], init: proc(self: ActorRef[A])): ActorRef[A] =
  result = allocActor[A](system = parent.system, parent = parent, init = init)
  let task = result.toTask
  parent.system.executor.submit(task)

proc createActor*[A](parent: ActorRef[A], receive: ActorBehavior[A]): ActorRef[A] =
    result = createActor[A](system = parent.system, parent = parent) do (self: ActorRef[A]):
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

proc createActorSystem*[A](executor: Executor): ActorSystem[A] =
  result.executor = executor
  result.children = @[]

  
proc createActorSystem*[A](): ActorSystem[A] =
  createActorSystem[A](createSimpleExecutor(2))

proc join*(system: ActorSystem) =
  system.executor.join()

proc createActor*[A](system: ActorSystem[A], init: proc(self: ActorRef[A])): ActorRef[A] =
  let actorRef = allocActor[A](system, nil, init)
  let task = actorRef.toTask
  system.executor.submit(task)
  actorRef

proc createActor*[A](system: ActorSystem[A], receive: ActorBehavior[A]): ActorRef[A] =
  createActor[A](system, 
    proc (self: ActorRef[A]) =
      self.become(receive))

