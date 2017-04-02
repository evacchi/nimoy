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
    eckReschedule
  
  ExecutorCommand = object
    case kind: ExecutorCommandKind
    of eckSubmit: 
      submittedTask: ExecutorTask
    of eckReschedule: 
      scheduledTask: ExecutorTask
    of eckShutdown:
      discard

  ExecutorState = enum
    esWorking
    esShutdown

  ExecutorObj* = object
    workers: seq[Worker]
    channel: Channel[ExecutorCommand]
    thread:  Thread[Executor]
    state:   ExecutorState
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

proc reschedule(executor: Executor, task: ExecutorTask) =
  executor.channel.send(ExecutorCommand(kind: eckReschedule, scheduledTask: task))

proc submit(executor: Executor, task: ExecutorTask) =
  executor.channel.send(ExecutorCommand(kind: eckSubmit, submittedTask: task))

proc submit*(executor: Executor, task: Task) =
  executor.submit(task.toExecutorTask)

proc shutdown*(executor: Executor) =
  executor.channel.send(ExecutorCommand(kind: eckShutdown))


proc simpleWorker*(self: Worker) {.thread.} =
  while true:
    # poll for task
    var (hasTask, t) = self.channel.tryRecv()
    if (hasTask):
      let result = t.task()
      t.state = result
      # return back to the parent for rescheduling
      self.parent.reschedule(t)
      
proc simpleExecutor*(executor: Executor) {.thread.} =
  echo "executor has started"
  var workerId = 0
  var runningTasks = 0
  while true:
    # wait for task
    var command = executor.channel.recv()
    case command.kind
    of eckSubmit:
      if executor.state != esShutdown:
        var task = command.submittedTask
        inc runningTasks
        executor.workers[workerId].submit(task)
        workerId = (workerId + 1) mod executor.workers.len
    of eckReschedule:
      if command.scheduledTask.state == taskFinished:
        dec runningTasks
      else:
        executor.workers[workerId].submit(command.scheduledTask)
        workerId = (workerId + 1) mod executor.workers.len
    of eckShutdown:
      executor.state = esShutdown

    if runningTasks <= 0:
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
  result.state = esWorking
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