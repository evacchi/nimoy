import locks, conslist

type
  SharedDeque*[T] = object
    list: List[T]
    lock: Lock

template withLock(t, x: untyped) =
  acquire(t.lock)
  x
  release(t.lock)

proc initSharedDeque*[A](initialSize: int = 4): SharedDeque[A] =
  initLock result.lock
  result.list = Nil[A]()

proc prepend*[T](shdeq: var SharedDeque[T], item: T) =
  ## Add an `item` to the end of the `deq`.
  withLock(shdeq):
    shdeq.list = Cons(item, shdeq.list)

iterator items*[T](deq: SharedDeque[T]) : T =
  for item in deq.list:
    yield item

iterator pairs*[T](deq: SharedDeque[T]): tuple[key: int, val: T] =
  var i = 0.int
  for v in deq.list:
    yield (i,v) 
    inc i

