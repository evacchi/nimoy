import future, queues, threadpool

type
  Message  = ref object
    value: int
    sender: Address
  Effect   = object
    effect: Behavior -> Behavior
  Behavior = object
    behavior: Message -> Effect
  Address  = ref object
    mailbox: Queue[Message]
    receive: Behavior
  ActorSystem = ref object
    addresses: seq[Address]


let Stay   = Effect( effect: proc (old: Behavior): Behavior = old )
proc Become(newB: Behavior): Effect =
  Effect( effect: proc (old: Behavior): Behavior = newB )


let Die =
  Become(Behavior(behavior:
    proc(m: Message): Effect =
      echo "discarding message "
      Stay
    )
  )

proc actorOf(self: var ActorSystem, initial: Behavior): Address =
  var address: Address
  address = Address(
    mailbox: initQueue[Message](),
    receive: initial
  )
  self.addresses.add(address)
  address

proc `!`(self: var Address, m: Message) =
  self.mailbox.add(m)
  # echo "received: ", self.mailbox

proc processActor(self: Address) =
  if (self.mailbox.len != 0):
    let msg = self.mailbox.pop()
    let eff = self.receive.behavior(msg)
    self.receive = eff.effect(self.receive)

var workQueue = initQueue[Address]()

proc run(self: ActorSystem): void =
  while true:
    # while workQueue.len != 0:
    #    workQueue.pop().processActor()
    for i in 0..self.addresses.len-1:
      var actorRef = self.addresses[i]
      if (actorRef.mailbox.len != 0):
        # workQueue.add(actorRef)
        processActor(actorRef)



var
  system = ActorSystem(addresses: @[])
  actor1: Address
  actor2: Address

actor1 = system.actorOf(Behavior(behavior:proc(m:Message): Effect =
  echo "actor1: ", m.value
  actor2 ! Message(value: m.value + 1, sender: actor1)
  Stay
))
actor2 = system.actorOf(Behavior(behavior:proc(m:Message): Effect =
 echo "actor2: ", m.value
 actor1 ! Message(value: m.value + 1, sender: actor2)
 Stay
))


actor1 ! Message(value: 1, sender: actor2)

system.run()


while true:
  discard
