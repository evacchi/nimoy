type
  Task* = proc()
  Executor* = object
    tasks*: seq[Task]

proc createExecutor*(): Executor =
  Executor(tasks: @[])

proc submit*(executor: var Executor, task: Task) =
  writeLine(stdout, "submitted task")
  executor.tasks.add(task)

proc start*(executor: var Executor) =
  while true:
    for t in executor.tasks:
      t()


