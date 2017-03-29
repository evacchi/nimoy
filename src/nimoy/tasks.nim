import locks

type
  Task*    = proc() {.gcsafe.}

  WorkerId* = int

  WorkerObj* = object
    id:      WorkerId
    channel: Channel[Task]
    thread:  Thread[Worker]

  Worker = ptr WorkerObj

  ExecutorObj* = object
    workers: array[2, Worker]
    channel: Channel[Task]
    thread:  Thread[Executor]

  Executor* = ptr ExecutorObj


proc workerLoop(worker: Worker) {.gcsafe.} =
  echo "worker #", $(worker[].id), " has started"
  var tasks: seq[Task] = @[]
  while true:
    let (hasTask, t) = worker[].channel.tryRecv()
    if (hasTask):
      echo "worker #", $(worker[].id), " got new task"
      tasks.add(t)
      t()
    else:
      for t in tasks:
        t()


proc createWorker*(id: int): Worker =
  let w = cast[Worker](allocShared0(sizeof(WorkerObj)))
  w.id = id
  w.channel.open()
  createThread(w.thread, workerLoop, w)
  w

proc submit*(worker: Worker, task: Task) =
  echo "task submitted to worker"
  worker[].channel.send(task)


proc executorLoop(executor: Executor) {.gcsafe.} =
  echo "executor has started"
  var tasks: seq[Task] = @[]
  var counter = 0
  var w1 = createWorker(1)
  var w2 = createWorker(2)

  while true:
    let (hasTask, t) = executor[].channel.tryRecv()
    if (hasTask):
      echo "executor got new task"
      if counter mod 2 == 0:
        w1.submit(t)
      else:
        w2.submit(t)
      inc counter


proc createExecutor*(): Executor =
  let e = cast[Executor](allocShared0(sizeof(ExecutorObj)))
  e.channel.open()
  createThread(e.thread, executorLoop, e)
  e

proc submit*(executor: Executor, task: Task) =
  echo "task submitted"
  executor[].channel.send(task)


proc join*(executor: Executor) =
  executor.thread.joinThread()
