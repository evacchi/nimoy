import queues, locks, options

type 
  LockQueue*[T] = object
    queue: ptr Queue[T]
    lock: ptr Lock

proc len*[T](q: LockQueue[T]): int =
  q.queue[].len


proc initLockQueue*[T](initialSize: int = 4, maxSize: int = 1000): LockQueue[T] =
  var lock = cast[ptr Lock](alloc0(sizeof(Lock)))
  initLock(lock[]) 
  var q = LockQueue[T](
    queue: cast[ptr Queue[T]](alloc0(sizeof(Queue[T]))),
    lock: lock
  )
  q.queue[] = initQueue[T](initialSize)
  q
  
proc add*[T](q: var LockQueue[T], item: T) =
  acquire(q.lock[]) 
  q.queue[].add(item)
  release(q.lock[]) 

proc pop*[T](q: var LockQueue[T]): Option[T] =
  acquire(q.lock[]) 
  result = 
    if (q.len == 0):
      none(T)
    else:
      some(q.queue[].pop())
  release(q.lock[]) 

proc destroy*[T](q: LockQueue[T]) =
  dealloc(q.queue[])
  dealloc(q.lock[])

# var 
#   t1: Thread[void]
#   t2: Thread[void]
#   q = initLockQueue[int]()


# createThread(t1, proc() =
#   while true:
#     q.add(10)
# )
# while true:
#   echo q.pop()
#   echo q.pop()
#   echo q.pop()
#   echo q.pop()


