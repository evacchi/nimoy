import sharedtables, sharedlist, deques, nimoypkg/tasks

type
  ActorId = int

  Actor = object
    id: ActorId
    mailbox: Deque[Envelope]
    behavior: ActorBehavior

  ActorRef = object
    id: ActorId

  Message = int

  Envelope = object
    message: Message
    sender: ActorRef
    receiver: ActorRef

  ActorContext = object
    self: ActorRef
    outbox: seq[Envelope]
    behavior: ActorBehavior
    system: ActorSystem

  ActorBehavior =
    proc(context: var ActorContext, envelope: Envelope)

  ActorInit =
    proc(context: var ActorContext)

  ActorSystem = object
    table: SharedTable[ActorId, Actor]
    ids: SharedList[ActorId]




proc nop(context: var ActorContext, envelope: Envelope) =
  writeLine(stdout, 
  context.self, ": Unitialized actor could not handle message ", envelope)

proc send(context: var ActorContext, message: Message, receiver: ActorRef) =
  let e = Envelope(
    message: message, 
    sender: context.self, 
    receiver: receiver
  )
  context.outbox.add(e)

proc become(context: var ActorContext, newBehavior: ActorBehavior) =
  context.behavior = newBehavior

proc processContextOutbox(system: var ActorSystem, context: var ActorContext) =
  for e in context.outbox:
    system.table.withValue(e.receiver.id, actor):
      actor.mailbox.addLast(e)

proc processContext(system: var ActorSystem, context: var ActorContext) =
  system.table.withValue(context.self.id, actor):
    while actor.mailbox.len > 0:
      context.behavior = actor.behavior
      let e = actor.mailbox.popFirst()
      actor.behavior(context, e)
      actor.behavior = context.behavior

  system.processContextOutbox(context)


proc createActorContext(system: var ActorSystem, actorRef: ActorRef): ActorContext =
  ActorContext(self: actorRef, outbox: @[], behavior: nop, system: system)

proc process(system: var ActorSystem, actorRef: ActorRef) =
  var currentContext = system.createActorContext(actorRef)
  system.processContext(currentContext)

proc createActorSystem(): ActorSystem =
  ActorSystem(table: initSharedTable[ActorId, Actor](), ids: initSharedList[ActorId]())

proc createActor(system: var ActorSystem, id: ActorId,
                 init: ActorInit): ActorRef =
  var actor = Actor(id: id, mailbox: initDeque[Envelope](), behavior: nop)
  var actorRef = ActorRef(id: id)
  var currentContext = system.createActorContext(actorRef)
  system.ids.add(id)
  init(currentContext)
  actor.behavior = currentContext.behavior
  system.table[id] = actor
  system.processContextOutbox(currentContext)
  actorRef

proc createActor(context: var ActorContext, id: ActorId,
                 init: ActorInit): ActorRef =
  context.system.createActor(id, init)

when isMainModule:
  var system = createActorSystem()

  let fooRef = system.createActor(100) do (context: var ActorContext):
    writeLine(stdout, "startup 100")

    proc receive(context: var ActorContext, e: Envelope) =
      writeLine(stdout, 
        context.self, " has received ", e.message, " from ", e.sender)
      context.send(Message(e.message + 1), e.sender)

    context.become(receive)

  let barRef = system.createActor(200) do (context: var ActorContext):
    writeLine(stdout, "startup 200")
    context.send(Message(1), fooRef)

    # state
    var i = 1000

    proc done(context: var ActorContext, e: Envelope) =
      writeLine(stdout, "DONE.")

    proc receive(context: var ActorContext, e: Envelope) =
      writeLine(stdout, 
        context.self, " has received ", e.message, " from ", e.sender)
      context.send(Message(e.message + 1), e.sender)
      i = i - 1
      if (i <= 100):
        context.become(done)

    context.become(receive)

  let bazRef = system.createActor(300) do (context: var ActorContext):
    writeLine(stdout, "startup 300")
    context.send(Message(3), fooRef)

    var i = 1000

    proc done(context: var ActorContext, e: Envelope) =
      writeLine(stdout, "DONE.")

    proc receive(context: var ActorContext, e: Envelope) =
      writeLine(stdout, context.self, " has received ", e.message, " from ", e.sender)
      context.send(Message(e.message + 1), e.sender)
      i = i - 1
      if (i <= 100):
        context.become(done)

    context.become(receive)


  proc makeTask(aref: ActorRef): proc() =
    return proc() = 
      system.process(aref)

  var executor = createExecutor()
  for id in system.ids:
    let aref = ActorRef(id: id)
    let t = makeTask(aref)
    executor.submit(t)


  executor.start()

