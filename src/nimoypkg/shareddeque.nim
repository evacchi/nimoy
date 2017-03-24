import locks, deques

type
  SharedDequeObj[T] = object
    deque: Deque[T]
    lock: Lock
  SharedDeque*[T] = ptr SharedDequeObj[T]

template withLock(t, x: untyped) =
  acquire(t.lock)
  x
  release(t.lock)

proc initSharedDeque*[A](initialSize: int = 4): SharedDeque[A] =
  result = cast[SharedDeque[A]](allocShared0(sizeof(SharedDeque[A])))
  initLock result.lock
  result.deque = initDeque[A](initialSize)

proc append*[T](shdeq: SharedDeque[T], item: T) =
  ## Add an `item` to the end of the `deq`.
  withLock(shdeq):
    shdeq.deque.addLast(item)

iterator items*[T](deq: SharedDeque[T]) : T =
  for item in deq[].deque.items:
    yield item

iterator pairs*[T](deq: SharedDeque[T]): tuple[key: int, val: T] =
  for i, v in deq[].deque.pairs:
    yield (i,v)
    
