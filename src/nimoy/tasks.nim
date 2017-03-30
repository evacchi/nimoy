type
  Task* = proc() {.gcsafe.}

  WorkerId* = int
  WorkerObj* = object
    id:      WorkerId
    channel: Channel[Task]
    thread:  Thread[Worker]
    parent:  Executor
  Worker = ptr WorkerObj

  ExecutorObj* = object
    workers: seq[Worker]
    channel: Channel[Task]
    thread:  Thread[Executor]
  Executor* = ptr ExecutorObj


proc submit*(executor: Executor, task: Task) =
  executor.channel.send(task)

proc workerLoop(self: Worker) {.gcsafe.} =
  while true:
    let (hasTask, t) = self.channel.tryRecv()
    if (hasTask):
      t()
      self.parent.submit(t)

proc createWorker*(id: int, parent: Executor): Worker =
  result = cast[Worker](allocShared0(sizeof(WorkerObj)))
  result.id = id
  result.channel.open()
  result.parent = parent
  createThread(result.thread, workerLoop, result)

proc submit*(worker: Worker, task: Task) =
  worker.channel.send(task)

proc executorLoop(executor: Executor) {.gcsafe.} =
  echo "executor has started"
  var workerId = 0
  while true:
    let (hasTask, t) = executor.channel.tryRecv()
    if (hasTask):
      executor.workers[workerId].submit(t)
      workerId = (workerId + 1) mod executor.workers.len
      
proc createExecutor*(workers: int): Executor =
  result = cast[Executor](allocShared0(sizeof(ExecutorObj)))
  result.workers = @[]
  result.channel.open()
  for i in 0..<workers:
    let w = createWorker(i, result) 
    result.workers.add(w)
  createThread(result.thread, executorLoop, result)

proc join*(executor: Executor) =
  executor.thread.joinThread()
