import future, queues

type
  Message  = int
  Effect   = object
    effect: Behavior -> Behavior
  Behavior = object
    behavior: Message -> Effect
  Address  = ref object
    mailbox: Queue[Message]
    receive: Behavior
  ActorSystem = object
    addresses: seq[Address]


let Stay   = Effect( effect: proc (old: Behavior): Behavior = old )
proc Become(newB: Behavior): Effect =
  Effect( effect: proc (old: Behavior): Behavior = newB )


let Die =
  Become(Behavior(behavior:
    proc(m: Message): Effect =
      echo "discarding message ", m
      Stay
    )
  )

proc actorOf(self: var ActorSystem, initial: Behavior): Address =
  var address = Address(
    mailbox: initQueue[Message](),
    receive: initial
  )
  self.addresses.add(address)
  address

proc `!`(self: var Address, m: Message) =
  self.mailbox.add(m)

proc run(self: var ActorSystem): void =
  while true:
    for i in 0..self.addresses.len-1:
      var actorRef = self.addresses[i]
      if (actorRef.mailbox.len != 0):
        let eff = actorRef.receive.behavior(actorRef.mailbox.pop())
        actorRef.receive = eff.effect(actorRef.receive)

var
  system = ActorSystem(addresses: @[])
  actor1 = system.actorOf(Behavior(behavior:proc(m:Message): Effect =
    echo "actor1: ", m
    Stay
  ))
  actor2 = system.actorOf(Behavior(behavior:proc(m:Message): Effect =
     echo "actor2: ", m
     Stay
   ))


actor1 ! 1
actor2 ! 2
actor2 ! 3
actor1 ! 4

system.run()
