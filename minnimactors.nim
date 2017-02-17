import future, queues, threadpool, lockqueues, options, os

type
  ActorObj = object
    receive: Behavior
  ActorRef = ref ActorObj

  Message = ref object
    value: int
  ActorContext = ref object
    self: ActorRef
    outbox: seq[Envelope]
  Effect = object
    effect: Behavior -> Behavior

  Envelope = (ActorRef, Message)
  Result = ref object
    outbox: seq[Envelope]
    effect: Effect

  Behavior = object
    behavior: (var ActorContext, Envelope) -> Effect
    
proc Become(newB: Behavior): Effect =
  Effect( effect: proc (old: Behavior): Behavior = newB )

let Stay = Effect(effect: proc (old: Behavior): Behavior = old )

proc send(ctx: ActorContext, dest: ActorRef, msg: Message) =
  ctx.outbox.add((dest, msg))

proc Actor(): ActorRef =
  var behavior: Behavior = Behavior( behavior:
    proc (ctx: var ActorContext, e: Envelope): Effect =
      let (sender, m) = e
      echo $(m.value)
      ctx.send(ctx.self, Message(value: m.value + 1))
      Stay
  )
  ActorRef(receive: behavior)


proc foo(): ActorContext =
  let a = Actor()
  var ac = ActorContext(self: a, outbox: @[])
  let m = Message(value: 1)
  let eff = a.receive.behavior(ac, (a,m))
  ac
let fv = spawn foo()
let r = ^fv
echo $(r.outbox[0][1].value)
