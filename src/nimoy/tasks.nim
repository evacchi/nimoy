type

  Task* = proc(): TaskState {.gcsafe.}
  TaskState* = enum
    taskStarted
    taskContinue
    taskFinished

  ExecutorTask* = object
    task: Task
    state: TaskState

  WorkerId* = int
  WorkerObj* = object
    id:      WorkerId
    channel: Channel[ExecutorTask]
    thread:  Thread[Worker]
    parent:  Executor
  Worker = ptr WorkerObj
  WorkerLoop = proc(self: Worker) {.thread.}

  ExecutorCommandKind = enum
    eckShutdown
    eckSubmit
  
  ExecutorCommand = object
    case kind: ExecutorCommandKind
    of eckSubmit: 
      task: ExecutorTask
    of eckShutdown:
      discard

  ExecutorObj* = object
    workers: seq[Worker]
    channel: Channel[ExecutorCommand]
    thread:  Thread[Executor]
  Executor* = ptr ExecutorObj
  ExecutorLoop = proc(self: Executor) {.thread.}

  ExecutorStrategy = object
    executorLoop: ExecutorLoop
    workerLoop: WorkerLoop

proc toExecutorTask*(task: Task): ExecutorTask =
  ExecutorTask(task: task, state: taskStarted)

proc join*(executor: Executor) =
  executor.thread.joinThread()

proc submit*(worker: Worker, task: ExecutorTask) =
  worker.channel.send(task)

proc submit(executor: Executor, task: ExecutorTask) =
  executor.channel.send(ExecutorCommand(kind: eckSubmit, task: task))

proc submit*(executor: Executor, task: Task) =
  executor.submit(task.toExecutorTask)

proc shutdown*(executor: Executor) =
  executor.channel.send(ExecutorCommand(kind: eckShutdown))


proc simpleWorker*(self: Worker) {.thread.} =
  while true:
    # poll for task
    let (hasTask, t) = self.channel.tryRecv()
    if (hasTask):
      let result = t.task()
      case result 
        of taskStarted, taskContinue:
          # return back to the parent for rescheduling
          self.parent.submit(t)
        of taskFinished:
          discard  

proc simpleExecutor*(executor: Executor) {.thread.} =
  echo "executor has started"
  var workerId = 0
  while true:
    # poll for task
    let command = executor.channel.recv()
    case command.kind
    of eckSubmit:
      executor.workers[workerId].submit(command.task)
      workerId = (workerId + 1) mod executor.workers.len
    of eckShutdown:
      break

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