import sequtils, sharedlist, os, locks

type
  Task*    = proc() {.gcsafe.}
  TaskList = seq[Task]

  SharedChannel*[T] = ptr Channel[T]
  WorkerChannel*   = SharedChannel[Task]
  WorkerId*        = int
  WorkerThread*    = ptr Thread[(WorkerId, WorkerChannel)]


  Worker* = object
    id:      WorkerId
    channel: WorkerChannel
    thread:  WorkerThread

  Executor* = object
    tasks*: TaskList
    lock:   Lock
    workers: array[2, Worker]

proc newSharedChannel*[T](): SharedChannel[T] =
  result = cast[WorkerChannel](allocShared0(sizeof(Channel[Task])))
  result[].open()

proc peek[T](c: SharedChannel[T]): int =
  c[].peek()

proc tryRecv*[T](c: SharedChannel[T]): (bool, T) =
  c[].tryRecv()

proc recv[T](c: SharedChannel[T]): T =
  c[].recv()

proc send*[T](c: SharedChannel[T], t: T) =
  c[].send(t)

proc createExecutor*(): Executor =
  result.tasks = @[]

proc submit*(executor: var Executor, task: Task) =
  echo "task submitted"
  executor.tasks.add(task)

proc worker(workerData: (WorkerId, WorkerChannel)) {.gcsafe.} =
  let (id, channel) = workerData
  echo "worker #", $id, " has started"
  var tasks: seq[Task] = @[]
  while true:
    sleep(100)
    let (hasTask, t) = channel[].tryRecv()
    if (hasTask):
      echo "worker #", $id, " got new task"
      tasks.add(t)
      t()
    else:
      for t in tasks:
        t()


proc initWorker*(id: int): Worker =
  result.id = id
  result.channel = newSharedChannel[Task]()
  result.thread = cast[WorkerThread](allocShared0(sizeof(Thread[Worker])))

  createThread(result.thread[], worker, (id, result.channel))

proc submit*(worker: var Worker, task: Task) =
  echo "task submitted to worker"
  worker.channel.send(task)


proc start*(executor: var Executor) =
  var w1 = initWorker(1)
  var w2 = initWorker(2)
  sleep(100)
  var i = 0
  for t in executor.tasks.items:
    echo "send task ", $i
    if i mod 2 == 0:
      w1.submit(t)
    else:
      w2.submit(t)
    inc i

  while true:
    discard


when isMainModule:
  proc ciao() =
    stdout.writeLine "ciao"
  proc hello() =
    stdout.writeLine "hello"
  proc salut() =
    stdout.writeLine "salut"

  proc main() =
    var executor = createExecutor()

    executor.submit(Task(ciao))
    executor.submit(Task(hello))
    executor.submit(Task(salut))

    executor.start()

  var thread: Thread[void]
  createThread(thread, main)
