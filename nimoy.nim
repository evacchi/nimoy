import sharedtables, deques

type
  ActorId = int
  
  ActorRef = object
    path: ActorId 

  ActorSystem = object 
    table: SharedTable[ActorId, Actor]

  ActorContext = object
    self: ActorRef
    outbox: Deque[Envelope]
  
  Message = int
  
  Envelope = object
    message: Message
    sender: ActorRef
    receiver: ActorRef

  ActorBehavior = proc(context: var ActorContext, envelope: Envelope)
  ActorInit     = proc(context: var ActorContext): ActorBehavior

  Actor = object
    path: ActorId
    mailbox: Deque[Envelope]
    behavior: ActorBehavior


proc send(context: var ActorContext, message: Message, receiver: ActorRef) =
    let e = Envelope(message: message, sender: context.self, receiver: receiver)
    context.outbox.addLast(e)


proc processContext(system: var ActorSystem, currentContext: var ActorContext) =
  system.table.withValue(currentContext.self.path, actor):
    if actor.mailbox.len > 0:
      let e = actor.mailbox.popFirst()
      actor.behavior(currentContext, e) 

  for e in currentContext.outbox:
    system.table.withValue(e.receiver.path, actor):
      actor.mailbox.addLast(e)

proc createActor(system: var ActorSystem, path: ActorId, 
                 init: ActorInit): ActorRef =
  var actor = Actor(mailbox: initDeque[Envelope]())
  var actorRef = ActorRef(path: path)
  var currentContext = ActorContext(self: actorRef, outbox: initDeque[Envelope]()) 
  actor.behavior = init(currentContext)
  system.table[path] = actor
  system.processContext(currentContext)
  actorRef

proc process(system: var ActorSystem, path: ActorId) =
  let currentRef = ActorRef(path: path)
  var currentContext = ActorContext(self: currentRef, outbox: initDeque[Envelope]()) 
  system.processContext(currentContext)

proc createActorSystem(): ActorSystem =
  ActorSystem(table: initSharedTable[ActorId, Actor]())

var system = createActorSystem()
let fooRef = system.createActor(100, proc (context: var ActorContext): ActorBehavior =
  writeLine(stdout, "startup 100")
  return proc (context: var ActorContext, e: Envelope) =
      writeLine(stdout, context.self, " has received ", e.message, " from ", e.sender)
      context.send(Message(e.message + 1), e.sender)
  )

let barRef = system.createActor(200, proc (context: var ActorContext): ActorBehavior =
  writeLine(stdout, "startup 200")
  context.send(Message(1), fooRef)
  return proc (context: var ActorContext, e: Envelope) =
    writeLine(stdout, context.self, " has received ", e.message, " from ", e.sender)
    context.send(Message(e.message + 1), e.sender)
  )


#system.table.withValue(100, actor):
#  actor.mailbox.addLast(Envelope(message: Message(1), sender: barRef, receiver: fooRef))

var t1,t2: Thread[void]



createThread(t1, proc() {.thread.} = 
  while true:
    system.process(fooRef.path)
)
createThread(t2, proc() {.thread.} = 
  while true:
    system.process(barRef.path)
)



joinThreads(t1,t2)
