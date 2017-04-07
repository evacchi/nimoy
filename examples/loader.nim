import nimoy, nimoy/executors, os, sets

type
  # define a family of messages for the loader
  LoaderMessageKind = enum
    loaderStart
    loaderFinished
  
  LoaderMessage = object 
    case kind: LoaderMessageKind
    of loaderStart:
      loadFile: string
    of loaderFinished:
      loadedFile: string

proc longThreadBlockingRoutine(file: string) =
  sleep(1000)

proc createLoaderWorker(system: ActorSystem, parent: ActorRef[LoaderMessage]): ActorRef[LoaderMessage] =
  #
  # Calls a thread blocking routine upon receiving the load message,
  # then terminates
  #
  system.createActor() do (self: ActorRef[LoaderMessage], m: LoaderMessage):
    case m.kind:
    of loaderStart:
      longThreadBlockingRoutine(m.loadFile)
      parent ! LoaderMessage(kind: loaderFinished, loadedFile: m.loadFile)
      self ! sysKill
    of loaderFinished:
      # only handles loaderStart messages
      discard

proc createLoader(system: ActorSystem, files: seq[string]): ActorRef[LoaderMessage] =
  #
  # Spawns an actor for each file name, 
  # waits for all the workers for "files" to terminate, 
  # then terminates itself.
  # 
  system.initActor() do (self: ActorRef[LoaderMessage]):
    # We initialize the actor using the longer form (initActor),
    # useful to define actor-local state.
    
    var pending = files.len
    for f in files:
      self ! LoaderMessage(kind: loaderStart, loadFile: f)

    self.become do (m: LoaderMessage):
      case m.kind:
      of loaderStart:
        # spawn worker, forward m
        echo "Loading file ", m.loadFile, "..."
        system.createLoaderWorker(parent = self) ! m
      of loaderFinished:
        pending -= 1
        echo "Loaded ", m.loadedFile, "."
        if pending == 0:
          self ! sysKill


let executor = createSimpleExecutor(4) # 4 threads
let system = createActorSystem(executor)

let loader = system.createLoader( @["foo", "bar", "baz", "qux", "quux"] )

system.awaitTermination()
