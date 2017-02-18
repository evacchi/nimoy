import sharedtables, deques

type
  ActorId = int
  
  ActorRef = object
    id: ActorId 

  ActorSystem = object 
    table: SharedTable[ActorId, Actor]

  ActorContext = object
    self: ActorRef
    outbox: Deque[Envelope]
    behavior: ActorBehavior
  
  Message = int
  
  Envelope = object
    message: Message
    sender: ActorRef
    receiver: ActorRef

  ActorBehavior = proc(context: var ActorContext, envelope: Envelope)
  ActorInit     = proc(context: var ActorContext)

  Actor = object
    id: ActorId
    mailbox: Deque[Envelope]
    behavior: ActorBehavior


proc send(context: var ActorContext, message: Message, receiver: ActorRef) =
    let e = Envelope(message: message, sender: context.self, receiver: receiver)
    context.outbox.addLast(e)

proc nop(context: var ActorContext, envelope: Envelope) =
  writeLine(stdout, context.self, ": Unhandled message ", envelope)

proc become(context: var ActorContext, newBehavior: ActorBehavior) =
    context.behavior = newBehavior


proc processContext(system: var ActorSystem, currentContext: var ActorContext) =
  system.table.withValue(currentContext.self.id, actor):
    if actor.mailbox.len > 0:
      currentContext.behavior = actor.behavior
      let e = actor.mailbox.popFirst()
      actor.behavior(currentContext, e)
      actor.behavior = currentContext.behavior 

  for e in currentContext.outbox:
    system.table.withValue(e.receiver.id, actor):
      actor.mailbox.addLast(e)

  
proc createActorContext(actorRef: ActorRef): ActorContext =
  ActorContext(self: actorRef, outbox: initDeque[Envelope](), behavior: nop) 

proc createActor(system: var ActorSystem, id: ActorId, 
                 init: ActorInit): ActorRef =
  var actor = Actor(mailbox: initDeque[Envelope]())
  var actorRef = ActorRef(id: id)
  var currentContext = createActorContext(actorRef)
  init(currentContext)
  actor.behavior = currentContext.behavior
  system.table[id] = actor
  system.processContext(currentContext)
  actorRef

proc process(system: var ActorSystem, id: ActorId) =
  let actorRef = ActorRef(id: id)
  var currentContext = createActorContext(actorRef)
  system.processContext(currentContext)

proc createActorSystem(): ActorSystem =
  ActorSystem(table: initSharedTable[ActorId, Actor]())

var system = createActorSystem()
let fooRef = system.createActor(100) do (context: var ActorContext):
  writeLine(stdout, "startup 100")

  proc receive(context: var ActorContext, e: Envelope) =
    writeLine(stdout, context.self, " has received ", e.message, " from ", e.sender)
    context.send(Message(e.message + 1), e.sender)

  context.become(receive)



let barRef = system.createActor(200) do (context: var ActorContext):
  writeLine(stdout, "startup 200")
  context.send(Message(1), fooRef)

  # state
  var i = 1000

  proc receive2(context: var ActorContext, e: Envelope) =
    writeLine(stdout, "DONE.")

  proc receive(context: var ActorContext, e: Envelope) =
    writeLine(stdout, context.self, " has received ", e.message, " from ", e.sender)
    context.send(Message(e.message + 1), e.sender)
    i = i - 1
    if (i <= 100):
      context.become(receive2)
        
  
  context.become(receive)


var t1,t2: Thread[void]



createThread(t1, proc() {.thread.} = 
  while true:
    system.process(fooRef.id)
)
createThread(t2, proc() {.thread.} = 
  while true:
    system.process(barRef.id)
)



joinThreads(t1,t2)
