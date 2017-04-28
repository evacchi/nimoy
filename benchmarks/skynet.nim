import nimoy, nimoy/executors, times, os, nimoy/slist, options

# Result: 499999500000 in 37.46313095092773 s.
type
  MessageKind = enum
    msgRun
    msgStart
    msgNum
  Message = object
    case kind: MessageKind
    of msgStart: 
      num:  int
      size: int
    of msgRun:
      runNum: int
    of msgNum:
      myNum: int
    
proc MessageStart(num, size: int): Message = 
  result.kind = msgStart
  result.num  = num
  result.size = size
  
proc MessageRun(num: int): Message  = 
  result.kind    = msgRun
  result.runNum  = num

proc MessageNum(num: int): Message  = 
  result.kind  = msgNum
  result.myNum = num

proc nanoTime(): float = 
  epochTime()

const SIZE  = 1_000_000
const WIDTH = 10

let executor = createSimpleExecutor(2)
let system = createActorSystem(executor)

proc Skynet(parent: ActorRef[Message]): ActorInit[Message] =
  proc init(self: ActorRef[Message]) =
    var todo = WIDTH
    var count = 0

    proc receive(m: Message) = 
      case m.kind
      of msgStart:
        if m.size == 1:
          parent ! MessageNum(m.num)
          self.send(sysKill)
        else:
          for i in 0..<WIDTH:
            let newSize = (m.size/WIDTH).int
            let sub = m.num  + i * newSize
            #echo ( sub, ", ", newSize)
            system.initActor(Skynet(self)) ! MessageStart(sub, newSize)

      of msgNum:
        todo -= 1
        count += m.myNum
        if todo == 0:
          #echo count        
          parent ! MessageNum(count)
          self.send(sysKill)
        
      of msgRun:
        discard
    
    self.become(receive)

  return init


proc Root(self: ActorRef[Message]) = 
  var n = 0
  var start = nanoTime()

  self.become do (m: Message): 
    if m.kind == msgRun:
      system.initActor(Skynet(self)) ! MessageStart(0, SIZE)
    elif m.kind == msgNum:
      let diffs = (nanoTime() - start)
      echo("Result: ", m.myNum, " in ", diffs, " s.")
      self.send(sysKill) # terminate


let root = system.initActor(Root) 
root ! MessageRun(0)
# # var x: array[1000_000, Actor[Message]]
# # echo sizeof(Channel[int])
# # for i in 0..<1000_000:
# #   x[i] = allocActor[Message]()#createActor(Skynet(system, root))
system.awaitTermination()

# var l = initSharedList[int]()
# for i in 0..<1000_000:
#   #echo i
#   l.enqueue(i)

# for i in 0..<1000_000:
#   let x = l.dequeue()
#   l.enqueue(x.get)
#   # if x.isSome:
#   #   echo x.get

#l.enqueue(100)

echo GC_getStatistics()
#dumpNumberOfInstances()

echo "DONE"
sleep(10)