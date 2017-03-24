import sharedtables, sharedlist, deques, nimoypkg/tasks

type
  ActorId = int

  Actor = object
    id: ActorId
    mailbox: SharedChannel[Envelope]
    behavior: ActorBehavior
    system:   ActorSystem

  ActorRef = object
    id: ActorId
    mailbox: SharedChannel[Envelope]

  Message = int

  Envelope = object
    message:  Message
    sender:   Actor

  ActorContext = object
    self:     Actor
    behavior: ActorBehavior
    system:   ActorSystem

  ActorBehavior =
    proc(context: var ActorContext, envelope: Envelope)

  ActorInit =
    proc(context: var ActorContext)

  ActorSystem = object
    # table: SharedTable[ActorId, Actor]
    # ids: SharedList[ActorId]


proc nop(context: var ActorContext, envelope: Envelope) =
  writeLine(stdout, 
  context.self, ": Unitialized actor could not handle message ", envelope)

proc send(context: var ActorContext, message: Message, receiver: Actor) =
  let e = Envelope(
    message: message, 
    sender: context.self
  )
  receiver.mailbox.send(e)
  
proc become(context: var ActorContext, newBehavior: ActorBehavior) =
  context.behavior = newBehavior

proc createActorContext(system: ActorSystem, actorRef: Actor): ActorContext =
  ActorContext(self: actorRef, behavior: nop, system: system)  

proc createActorSystem(): ActorSystem =
  ActorSystem()

proc createActor(system: var ActorSystem, id: ActorId, init: ActorInit): Actor =
  var actor = Actor(id: id, mailbox: newSharedChannel[Envelope](), behavior: nop)
  var currentContext = system.createActorContext(actor)
  init(currentContext)
  actor.behavior = currentContext.behavior
  actor

proc send(actor: Actor, envelope: Envelope) = 
  actor.mailbox.send(envelope)

when isMainModule:
  var system = createActorSystem()


  # let barRef = system.createActor(200) do (context: var ActorContext):
  #   writeLine(stdout, "startup 200")
  #   context.send(Message(1), fooRef)

  #   # state
  #   var i = 1000

  #   proc done(context: var ActorContext, e: Envelope) =
  #     writeLine(stdout, "DONE.")

  #   proc receive(context: var ActorContext, e: Envelope) =
  #     writeLine(stdout, 
  #       context.self, " has received ", e.message, " from ", e.sender)
  #     context.send(Message(e.message + 1), e.sender)
  #     i = i - 1
  #     if (i <= 100):
  #       context.become(done)

  #   context.become(receive)

  # let bazRef = system.createActor(300) do (context: var ActorContext):
  #   writeLine(stdout, "startup 300")
  #   context.send(Message(3), fooRef)

  #   var i = 1000

  #   proc done(context: var ActorContext, e: Envelope) =
  #     writeLine(stdout, "DONE.")

  #   proc receive(context: var ActorContext, e: Envelope) =
  #     writeLine(stdout, context.self, " has received ", e.message, " from ", e.sender)
  #     context.send(Message(e.message + 1), e.sender)
  #     i = i - 1
  #     if (i <= 100):
  #       context.become(done)

  #   context.become(receive)


# proc createActor(system: var ActorSystem, id: ActorId, init: ActorInit): Actor =
#   var actor = Actor(id: id, mailbox: newSharedChannel[Envelope](), behavior: nop)
#   var currentContext = system.createActorContext(actor)
#   init(currentContext)
#   actor.behavior = currentContext.behavior
#   actor




  template createTask(initActorBody: untyped): auto =
    let r = (block:
      var channel = newSharedChannel[Envelope]()
      var actor = Actor(mailbox: channel)
      echo $(actor)
      let t = proc() {.thread.} =
        let receive: ActorBehavior = initActorBody
        let (hasMsg, msg) = actor.mailbox.tryRecv()
        var context = actor.system.createActorContext(actor)
        if hasMsg:
          echo "receive:"
          receive(context, msg)
          #receive = context.behavior
          
      (actor, t))
    r

  
  var executor = createExecutor()        

  let (foo, tfoo) = (
    block:
      createTask:
        proc receive(context: var ActorContext, e: Envelope) =
          writeLine(stdout, 
            "foo has received ", e.message, " from ", e.sender)
          e.sender.mailbox.send(Envelope(message: e.message + 1, sender: context.self))
        receive
      )

  let (bar, tbar) = (
    block:
      createTask:
        proc receive(context: var ActorContext, e: Envelope) =
          writeLine(stdout, 
            "bar has received ", e.message, " from ", e.sender)
          e.sender.send(Envelope(message: e.message + 1, sender: context.self))
          e.sender.send(Envelope(message: e.message - 1, sender: context.self))
        receive
      )



  # executor.submit(t)
  # executor.start()

  var w1 = initWorker(1)
  var w2 = initWorker(1)
  w1.submit(tbar)
  w2.submit(tfoo)

  bar.send(Envelope(message: 1, sender: foo))


  while true:
    discard 