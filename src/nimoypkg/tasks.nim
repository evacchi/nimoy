import conslist, sequtils, shareddeque

type
  Task* = proc()
  TaskList = SharedDeque[Task]
  Executor* = object
    tasks*: TaskList
    threads: array[2, Thread[TaskList]]

proc createExecutor*(): Executor =
  var list = initSharedDeque[Task]()
  Executor(tasks: list)

proc submit*(executor: var Executor, task: Task) =
  writeLine(stdout, "submitted task")
  executor.tasks.prepend(task)

proc workerEven(tasks: TaskList) =
  while true:
    for i, t in tasks:
      if i mod 2 == 0:
        t()
        
proc workerOdd(tasks: TaskList) =
  while true:
    for i, t in tasks:
      if i mod 2 == 1:
        t()

proc start*(executor: var Executor) =
  createThread(executor.threads[0], workerEven, executor.tasks)
  createThread(executor.threads[1], workerOdd, executor.tasks)
  joinThread(executor.threads[0])
