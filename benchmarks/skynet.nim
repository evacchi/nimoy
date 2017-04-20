import nimoy, nimoy/executors, times

type
  MessageKind = enum
    msgRun
    msgStart
    msgNum
  Message = object
    case kind: MessageKind
    of msgStart: 
      level: int
      num:   int
    of msgRun:
      runNum: int
    of msgNum:
      myNum: int
    
proc MessageStart(level: int, num: int): Message = 
  result.kind  = msgStart
  result.level = level
  result.num   = num

proc MessageRun(num: int): Message  = 
  result.kind    = msgRun
  result.runNum  = num

proc MessageNum(num: int): Message  = 
  result.kind  = msgNum
  result.myNum = num

proc nanoTime(): float = 
  cpuTime()


const TOTAL = 8

proc Skynet(system: ActorSystem, parent: ActorRef[Message]): ActorInit[Message] =
  proc init(self: ActorRef[Message]) =
    var todo = TOTAL
    var count = 0

    proc receive(m: Message) = 
      case m.kind
      of msgStart:
        if m.level == 1:
          parent ! MessageNum(m.num)
          self.send(sysKill)

        else:
          let start = m.num * TOTAL
          for i in 0..<TOTAL:
            #echo ( (m.level - 1), ", ", (start + i))
            system.initActor(Skynet(system, self)) ! MessageStart(m.level - 1, start + i)

      of msgNum:
        todo -= 1
        count += m.myNum
        if todo == 0:
          parent ! MessageNum(count)
          self.send(sysKill)
        
      of msgRun:
        discard
    
    self.become(receive)

  return init


proc Root(system: ActorSystem): ActorInit[Message] =
  proc init(self: ActorRef[Message]) = 
    proc startRun(n: int)

    proc receive(m: Message) = 
      if m.kind == msgRun:
        startRun(m.runNum)

    proc waiting(n: int, start: float): ActorBehavior[Message] =
      proc waitingReceive(m: Message) =
        if m.kind == msgNum:
          let diffs = (nanoTime() - start)
          echo("Result: ", m.myNum, " in ", diffs, " s.")
          if n == 0:
            self.send(sysKill) # terminate
          else:
            startRun(m.myNum)
      result = waitingReceive


    proc startRun(n: int) =
      let start = nanoTime()
      system.initActor(Skynet(system, self)) ! MessageStart(7,0)
      self.become(waiting(n-1, start))

    self.become(receive)

  result = init

let executor = createSimpleExecutor(TOTAL*2)
let system = createActorSystem(executor)
system.initActor(Root(system)) ! MessageRun(1)
system.awaitTermination()
