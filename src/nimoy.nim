import sharedtables, sharedlist, deques, nimoypkg/tasks

type
  ActorId = int

  Actor = object
    id: ActorId
    mailbox: SharedChannel[Envelope]
    system:  ActorSystem
    behavior: ActorBehavior


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

proc createActorContext(system: ActorSystem, actor: Actor): ActorContext =
  ActorContext(self: actor, behavior: actor.behavior, system: system)  

proc createActorSystem(): ActorSystem =
  ActorSystem()

# proc createActor(system: var ActorSystem, id: ActorId, init: ActorInit): Actor =
#   var actor = Actor(id: id, mailbox: newSharedChannel[Envelope](), behavior: nop)
#   var currentContext = system.createActorContext(actor)
#   init(currentContext)
#   actor.behavior = currentContext.behavior
#   actor

proc send(actor: Actor, envelope: Envelope) = 
  actor.mailbox.send(envelope)


template createTask(initActorBody: untyped): auto =
  let r = (block:
    var channel = newSharedChannel[Envelope]()
    var receive: ActorBehavior = initActorBody
    var actor = Actor(mailbox: channel, behavior: receive)
    echo $(actor)
    let t = proc() {.thread.} =
      let (hasMsg, msg) = actor.mailbox.tryRecv()
      var context = actor.system.createActorContext(actor)
      if hasMsg:
        echo "receive:"
        context.behavior(context, msg)
        actor.behavior = context.behavior
        
    (actor, t))
  r


when isMainModule:
  var system = createActorSystem()
  var executor = createExecutor()        

  let (foo, tfoo) = (
    block:
      createTask:
        var count = 0
        proc done(context: var ActorContext, e: Envelope) =
          writeLine(stdout, "DONE.")

        proc receive(context: var ActorContext, e: Envelope) =
          writeLine(stdout, 
            "foo has received ", e.message, " from ", e.sender)
          e.sender.mailbox.send(Envelope(message: e.message + 1, sender: context.self))
          count += 1
          if count >= 10:
            context.become(done)

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



  executor.submit(tfoo)
  executor.submit(tbar)

  bar.send(Envelope(message: 1, sender: foo))

  executor.start()


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




  
