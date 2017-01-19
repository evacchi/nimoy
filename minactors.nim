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
      var actorRef = self.addresses[0]
      if (actorRef.mailbox.len != 0):
        let eff = actorRef.receive.behavior(actorRef.mailbox.pop())
        actorRef.receive = eff.effect(actorRef.receive)

var
 system = ActorSystem(addresses: @[])
 actor = system.actorOf(Behavior(behavior:proc(m:Message): Effect =
    echo "ciao ", m
    Stay
  ))


actor ! 1
actor ! 2
actor ! 3
actor ! 4

system.run()
