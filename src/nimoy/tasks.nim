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
  result = cast[Worker](allocShared0(sizeof(WorkerObj)))
  result.id = id
  result.channel.open()
  createThread(result.thread, workerLoop, result)

proc submit*(worker: Worker, task: Task) =
  echo "task submitted to worker"
  worker.channel.send(task)


proc executorLoop(executor: Executor) {.gcsafe.} =
  echo "executor has started"
  while true:
    let (hasTask, t) = executor.channel.tryRecv()
    var workerId = 0
    if (hasTask):
      echo "executor got new task"
      executor.workers[workerId].submit(t)
      workerId = (workerId + 1) mod executor.workers.len
      
proc createExecutor*(workers: int): Executor =
  result = cast[Executor](allocShared0(sizeof(ExecutorObj)))
  result.workers = @[]
  result.channel.open()
  for i in 0..<workers:
    result.workers.add(createWorker(i))
  createThread(result.thread, executorLoop, result)

proc submit*(executor: Executor, task: Task) =
  echo "task submitted"
  executor.channel.send(task)


proc join*(executor: Executor) =
  executor.thread.joinThread()
