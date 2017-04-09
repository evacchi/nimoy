import times, os

type
  Task* = proc(): TaskStatus {.gcsafe.}
  TaskStatus* = enum
    taskStarted
    taskContinue
    taskFinished

  ScheduledTask* = object
    id*: int
    task*: Task
    status*: TaskStatus

  ExecutorCommandKind* = enum
    executorTaskSubmit
    executorTaskReturned
    executorShutdown
    executorTerminate

  ExecutorCommand* = object
    case kind*: ExecutorCommandKind
    of executorTaskSubmit: 
      submittedTask*: ScheduledTask
    of executorTaskReturned: 
      scheduledTask*: ScheduledTask
    of executorShutdown:
      discard
    of executorTerminate:
      discard

  ExecutorStrategy* = object
    executorLoop*: ExecutorLoop
    workerLoop*: WorkerLoop

  ExecutorStatus* = enum
    executorRunning
    executorShuttingdown
    executorTerminated

  ExecutorObj* = object
    workers*: seq[Worker]
    channel*: Channel[ExecutorCommand]
    thread*:  Thread[Executor]
    status*:   ExecutorStatus
  Executor* = ptr ExecutorObj
  ExecutorLoop* = proc(self: Executor) {.thread.}

  WorkerId* = int
  WorkerObj* = object
    id*:      WorkerId
    channel*: Channel[ScheduledTask]
    thread*:  Thread[Worker]
    parent*:  Executor
  Worker* = ptr WorkerObj
  WorkerLoop* = proc(self: Worker) {.thread.}

proc toScheduledTask*(task: Task): ScheduledTask =
  ScheduledTask(id: -1, task: task, status: taskStarted)

proc submit*(worker: Worker, task: ScheduledTask) =
  worker.channel.send(task)

proc createWorker*(id: int, workerLoop: WorkerLoop, parent: Executor): Worker =
  result = cast[Worker](allocShared0(sizeof(WorkerObj)))
  result.id = id
  result.channel.open()
  result.parent = parent
  createThread(result.thread, workerLoop, result)

proc awaitTermination*(executor: Executor) =
  executor.thread.joinThread()

proc awaitTermination*(executor: Executor, maxSeconds: float) =
  let initial = epochTime()
  var current = initial
  while current - initial < maxSeconds:
    sleep(500)
    current = epochTime()

proc submit(executor: Executor, task: ScheduledTask) =
  executor.channel.send(ExecutorCommand(kind: executorTaskSubmit, submittedTask: task))

proc submit*(executor: Executor, task: Task) =
  executor.submit(task.toScheduledTask)

proc shutdown*(executor: Executor) =
  executor.channel.send(ExecutorCommand(kind: executorShutdown))

proc terminate*(executor: Executor) =
  executor.channel.send(ExecutorCommand(kind: executorTerminate))

proc createExecutor*(workers: int, executorStrategy: ExecutorStrategy): Executor =
  result = cast[Executor](allocShared0(sizeof(ExecutorObj)))
  result.workers = @[]
  result.channel.open()
  result.status = executorRunning
  for i in 0..<workers:
    let w = createWorker(i, executorStrategy.workerLoop, result) 
    result.workers.add(w)
  createThread(result.thread, executorStrategy.executorLoop, result)
