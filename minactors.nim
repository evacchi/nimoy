import future, queues

type
  Message  = int
  Effect   = object
    effect: Behavior -> Behavior
  Behavior = object
    behavior: Message -> Effect
  Address  = object
    mailbox: Queue[Message]
    receive: Behavior


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

proc Actor(initial: Behavior): Address =
  Address(
    mailbox: initQueue[Message](),
    receive: initial
  )

proc `!`(self: var Address, m: Message) =
  self.mailbox.add(m)

proc run(self: var Address): void =
  let eff = self.receive.behavior(self.mailbox.pop())
  self.receive = eff.effect(self.receive)
  if self.mailbox.len != 0:
    self.run()

var
 actor = Actor(Behavior(behavior:proc(m:Message): Effect =
    echo "ciao ", m
    Stay
  ))

actor ! 1
actor ! 2
actor ! 3
actor ! 4

run(actor)
