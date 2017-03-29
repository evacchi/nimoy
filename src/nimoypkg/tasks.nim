import os, locks

type
  Task*    = proc() {.gcsafe.}
  TaskList = seq[Task]

  WorkerId* = int

  WorkerObj* = object
    id:      WorkerId
    channel: Channel[Task]
    thread:  Thread[Worker]


  Worker = ptr WorkerObj

  Executor* = object
    tasks*: TaskList
    lock:   Lock
    workers: array[2, Worker]


proc createExecutor*(): Executor =
  result.tasks = @[]

proc submit*(executor: var Executor, task: Task) =
  echo "task submitted"
  executor.tasks.add(task)

proc worker(worker: Worker) {.gcsafe.} =
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


proc initWorker*(id: int): Worker =
  let w = cast[Worker](allocShared0(sizeof(WorkerObj)))
  w[].id = id
  w[].channel.open()

  createThread(w[].thread, worker, w)
  return w

proc submit*(worker: Worker, task: Task) =
  echo "task submitted to worker"
  worker[].channel.send(task)


proc start*(executor: var Executor) =
  var w1 = initWorker(1)
  var w2 = initWorker(2)
  var i = 0
  for t in executor.tasks.items:
    echo "send task ", $i
    if i mod 2 == 0:
      w1.submit(t)
    else:
      w2.submit(t)
    inc i

  while true:
    discard
