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
    workers: seq[Worker]
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

  while true:
    let (hasTask, t) = executor.channel.tryRecv()
    var workerId = 0
    if (hasTask):
      echo "executor got new task"
      executor.workers[workerId].submit(t)
      inc workerId
      workerId = workerId mod executor.workers.len
      
proc createExecutor*(workers: int): Executor =
  let e = cast[Executor](allocShared0(sizeof(ExecutorObj)))
  e.workers = @[]
  e.channel.open()
  for i in 0..<workers:
    echo i
    e.workers.add(createWorker(i))
  createThread(e.thread, executorLoop, e)
  e

proc submit*(executor: Executor, task: Task) =
  echo "task submitted"
  executor[].channel.send(task)


proc join*(executor: Executor) =
  executor.thread.joinThread()
