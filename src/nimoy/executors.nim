import tasks, tables, random, slist, options

proc createSimpleExecutor*(workers: int): Executor =
  proc workerLoop(self: Worker) {.thread.} =
    while true:
      var r: Option[ScheduledTask] = self.channel.dequeue()
      if r.isSome:
        var t = r.get
        t.status = t.task()
        # return back to the parent for rescheduling
        let command = 
          ExecutorCommand(
            kind: executorTaskReturned, 
            scheduledTask: t)
        self.parent.channel.enqueue(command)
        
  proc executorLoop(executor: Executor) {.thread.} =
    var workerId = 0
    var runningTasks = 0
    while true:
      # wait for task
      var r: Option[ExecutorCommand] = executor.channel.dequeue()
      if r.isSome:
        var command = r.get
        case command.kind
        of executorTaskSubmit:
          if executor.status != executorShuttingdown:
            inc runningTasks
            executor.workers[workerId].submit(command.submittedTask)
            workerId = (workerId + 1) mod executor.workers.len
        of executorTaskReturned:
          if command.scheduledTask.status == taskFinished:
            dec runningTasks
          else:
            executor.workers[workerId].submit(command.scheduledTask)
            workerId = (workerId + 1) mod executor.workers.len
        of executorShutdown:
          executor.status = executorShuttingdown
        of executorTerminate:
          executor.status = executorTerminated
          break

        if runningTasks <= 0:
          break

  let simpleStrategy = 
    ExecutorStrategy(
      executorLoop: executorLoop, 
        workerLoop: workerLoop)

  createExecutor(workers, simpleStrategy)

# proc createSimpleExecutor*(workers: int): Executor =
#   proc findFreeWorker(workerSet: var seq[bool]): int = 
#     # returns random if no worker is free
#     for workerId, isBusy in workerSet:
#       if not isBusy:
#         workerSet[workerId] = true 
#         return workerId
#     return random(workerSet.len)
    
#   proc workerLoop(self: Worker) {.thread.} =
#     while true:
#       var t = self.channel.recv()
#       t.status = t.task()
#       # return back to the parent for rescheduling
#       let command = 
#         ExecutorCommand(
#           kind: executorTaskReturned, 
#           scheduledTask: t)
#       self.parent.channel.send(command)
        
#   proc executorLoop(executor: Executor) {.thread.} =
#     #
#     # a simple executor that schedules submitted tasks
#     # on the first available worker, otherwise chooses at random.
#     #
#     # Keeps rescheduled tasks on the same thread.
#     #
#     var nWorkers = executor.workers.len
#     var taskId = 0
#     var scheduledTasks: Table[int, int] = initTable[int, int]()
#     var workerIsBusy: seq[bool] = newSeq[bool](nWorkers)

#     while true:
#       # wait for task
#       var command = executor.channel.recv()
#       case command.kind
#       of executorTaskSubmit:
#         if executor.status != executorShuttingdown:
#           # attach id to the freshly scheduled task 
#           var scheduledTask = command.submittedTask

#           let workerId = findFreeWorker(workerIsBusy)  
#           # add to the table, with its assigned worker
#           scheduledTask.id = taskId
#           scheduledTasks[scheduledTask.id] = workerId 
          
#           executor.workers[workerId].submit(scheduledTask)
#           inc taskId

#       of executorTaskReturned:
#         if command.scheduledTask.status == taskFinished:
#           scheduledTasks.del(command.scheduledTask.id)
#         else:
#           let assignedWorker = scheduledTasks[command.scheduledTask.id]
#           executor.workers[assignedWorker].submit(command.scheduledTask)
#       of executorShutdown:
#         executor.status = executorShuttingdown
#       of executorTerminate:
#         executor.status = executorTerminated
#         break

#       if scheduledTasks.len == 0:
#         break

#   let simpleStrategy = 
#     ExecutorStrategy(
#       executorLoop: executorLoop, 
#         workerLoop: workerLoop)

#   createExecutor(workers, simpleStrategy)
