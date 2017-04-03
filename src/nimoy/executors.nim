import tasks

proc createSimpleExecutor*(workers: int): Executor =
  proc workerLoop(self: Worker) {.thread.} =
    while true:
      var t = self.channel.recv()
      t.status = t.task()
      # return back to the parent for rescheduling
      let command = 
        ExecutorCommand(
          kind: executorTaskReturned, 
          scheduledTask: t)
      self.parent.channel.send(command)
        
  proc executorLoop(executor: Executor) {.thread.} =
    var workerId = 0
    var runningTasks = 0
    while true:
      # wait for task
      var command = executor.channel.recv()
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

      if runningTasks <= 0:
        break

  let simpleStrategy = 
    ExecutorStrategy(
      executorLoop: executorLoop, 
        workerLoop: workerLoop)

  createExecutor(workers, simpleStrategy)
