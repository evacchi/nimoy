type
  Task* = proc() {.gcsafe.}

  WorkerId* = int
  WorkerObj* = object
    id:      WorkerId
    channel: Channel[Task]
    thread:  Thread[Worker]
    parent:  Executor
  Worker = ptr WorkerObj
  WorkerLoop = proc(self: Worker) {.thread.}

  ExecutorObj* = object
    workers: seq[Worker]
    channel: Channel[Task]
    thread:  Thread[Executor]
  Executor* = ptr ExecutorObj
  ExecutorLoop = proc(self: Executor) {.thread.}

  ExecutorStrategy = object
    executorLoop: ExecutorLoop
    workerLoop: WorkerLoop

proc join*(executor: Executor) =
  executor.thread.joinThread()

proc submit*(worker: Worker, task: Task) =
  worker.channel.send(task)

proc submit*(executor: Executor, task: Task) =
  executor.channel.send(task)

proc simpleWorker(self: Worker) {.thread.} =
  while true:
    # poll for task
    let (hasTask, t) = self.channel.tryRecv()
    if (hasTask):
      t()
      # return back to the parent for rescheduling
      self.parent.submit(t)

proc simpleExecutor(executor: Executor) {.thread.} =
  echo "executor has started"
  var workerId = 0
  while true:
    # poll for task
    let (hasTask, t) = executor.channel.tryRecv()
    if (hasTask):
      # submit to next worker
      executor.workers[workerId].submit(t)
      workerId = (workerId + 1) mod executor.workers.len

proc createWorker*(id: int, workerLoop: WorkerLoop, parent: Executor): Worker =
  result = cast[Worker](allocShared0(sizeof(WorkerObj)))
  result.id = id
  result.channel.open()
  result.parent = parent
  createThread(result.thread, workerLoop, result)

proc createExecutor*(workers: int, executorStrategy: ExecutorStrategy): Executor =
  result = cast[Executor](allocShared0(sizeof(ExecutorObj)))
  result.workers = @[]
  result.channel.open()
  for i in 0..<workers:
    let w = createWorker(i, executorStrategy.workerLoop, result) 
    result.workers.add(w)
  createThread(result.thread, executorStrategy.executorLoop, result)

proc createSimpleExecutor*(workers: int): Executor =
  let simpleStrategy = 
    ExecutorStrategy(
      executorLoop: simpleExecutor, 
      workerLoop: simpleWorker)

  createExecutor(workers, simpleStrategy)