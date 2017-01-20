import future, queues, threadpool

{.experimental.}

type
  Flaffo = ref object
    mailbox: ref seq[int]


  Message  = ref object
    value: int
    sender: Address
  Effect   = object
    effect: Behavior -> Behavior
  Behavior = object
    behavior: Message -> Effect
  AddressObj = object
    mailbox: ref Queue[Message]
    receive: Behavior
  Address  = ref AddressObj
  ActorSystem = ref object
    addresses: seq[Address]


proc Become(newB: Behavior): Effect =
  Effect( effect: proc (old: Behavior): Behavior = newB )

proc become(behavior: proc(m: Message):Effect): Effect =
  let b = Behavior(behavior: behavior)
  Effect( effect: proc (old: Behavior): Behavior = b )


proc behavior(behavior: proc(m: Message):Effect): Behavior =
  Behavior(behavior: behavior)


let Stay   = Effect(effect: proc (old: Behavior): Behavior = old )


let Die =
  Become(Behavior(behavior:
    proc(m: Message): Effect =
      echo "discarding message "
      Stay
    )
  )

proc actorOf(self: var ActorSystem, initial: Address -> Behavior): Address =
  var address: Address = new AddressObj
  address.mailbox = new Queue[Message]
  address.mailbox[] = initQueue[Message]()
  address.receive = initial(address)
  self.addresses.add(address)
  address

proc makeActor(self: var ActorSystem, initial: (Address, Message) -> Effect): Address =
  self.actorOf( 
    proc (address: Address): Behavior = 
      behavior do (message: Message) -> Effect: 
        initial(address, message)
  )

proc `!`(self: var Address, m: Message) =
  self.mailbox.add(m)
  # echo "received: ", self.mailbox

proc processActor(self: Address) =
  if (self.mailbox[].len != 0):
    let msg = self.mailbox[].pop()
    let eff = self.receive.behavior(msg)
    let beh = eff.effect(self.receive)
    self.receive = beh

var workQueue = initQueue[Address]()

proc run(self: ActorSystem): void =
  while true:
    while workQueue.len != 0:
      let aref = workQueue.pop()
      processActor(aref)
    for i in 0..self.addresses.len-1:
      var actorRef = self.addresses[i]
      if (actorRef.mailbox[].len != 0):
        workQueue.add(actorRef)
        # processActor(actorRef)


var
  system = ActorSystem(addresses: @[])
  actor1 = system.makeActor do (self: Address, m: Message) -> Effect:
    echo "received first message"
    m.sender ! Message(value: m.value+1, sender: self)
    # actor2 ! Message(value: 5, sender: actor1)
    become do (m: Message) -> Effect:
      echo "actor1: ", m.value
      m.sender ! Message(value: m.value+1, sender: self)
      Stay
    

  actor2 = system.makeActor do (self: Address, m: Message) -> Effect:
    echo "actor2: ", m.value
    m.sender ! Message(value: m.value + 1, sender: self)
    Stay


proc mainLoop() =
  # var thread: Thread[ActorSystem]
  # createThread(thread, run, system)
  system.run
  while true:
    discard




# system.run()
actor1 ! Message(value: 1, sender: actor1)
actor2 ! Message(value: 3, sender: actor2)

mainLoop()

