import sharedtables, deques

type
  ActorId = int
  
  ActorRef = object
    path: ActorId 
  
  Message = int
  
  Envelope = object
    message: Message
    sender: ActorRef

  Actor = object
    path: ActorId
    mailbox: Deque[Envelope]


proc send(table: var SharedTable[ActorId, Actor], fromRef: ActorRef, toRef: ActorRef, message: Message) =
  table.withValue(toRef.path, actor):
    let e = Envelope(message: message, sender: fromRef)
    actor.mailbox.addLast(e)

proc createActor(table: var SharedTable[ActorId, Actor], path: ActorId): ActorRef =
  var actor = Actor(mailbox: initDeque[Envelope]())
  table[path] = actor
  ActorRef(path: path)

proc process(table: var SharedTable[ActorId, Actor], path: ActorId) =
  table.withValue(path, actor):
    while actor.mailbox.len > 0:
      let e = actor.mailbox.popFirst()
      writeLine(stdout, path, " has received ", e.message, " from ", e.sender)


var system = initSharedTable[ActorId, Actor]()
let fooRef = system.createActor(100)
let barRef = system.createActor(200)



var t1,t2: Thread[void]

system.send(fooRef, barRef, Message(1))
system.send(barRef, fooRef, Message(2))

createThread(t1, proc() {.thread.} = 
  while true:
    system.process(fooRef.path)
    system.send(fooRef, barRef, Message(3))
)
createThread(t2, proc() {.thread.} = 
  while true:
    system.process(barRef.path)
    system.send(barRef, fooRef, Message(4))
)



joinThreads(t1,t2)
