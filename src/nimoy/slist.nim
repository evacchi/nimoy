#
#
#            Nim's Runtime Library
#        (c) Copyright 2015 Andreas Rumpf
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.
#

## Shared list support.


import
  locks, options

const
  ElemsPerNode = 100

type
  SharedListNode[A] = ptr object
    next, prev: SharedListNode[A]
    value: A

  SharedList*[A] = ptr object ## generic shared list
    first, last: SharedListNode[A]
    lock: Lock

template withLock(t, x: untyped) =
  assert t!=nil
  acquire(t[].lock)
  x
  release(t[].lock)


proc initSharedList*[A](): SharedList[A] =
  result = cast[type result](allocShared0(sizeof(result[])))
  initLock(result[].lock)
  result.first = nil
  result.last  = nil

proc allocNode[A](): SharedListNode[A] =
  result = cast[type result](allocShared0(sizeof(result[])))
proc deallocNode[A](node: SharedListNode[A]): A =
  result = node.value
  deallocShared(node)

proc enqueue[A](node: SharedListNode[A], y: A): SharedListNode[A] =
  result = allocNode[A]()
  result.value = y
  result.prev = node
  node.next = result

proc enqueue*[A](x: SharedList[A]; y: A) =
  assert x!=nil
  withLock(x):
    if x.last == nil:
      assert(x.first == nil)
      var node = allocNode[A]()
      node.value = y
      x.first = node
      x.last = node
    else:
      x.last = x.last.enqueue(y)
      
# proc isEmpty(x: var SharedList[A]): bool =
#   withLock(x):
#     result = x.head == nil or x.d.len == 0

proc dequeue*[A](x: SharedList[A]): Option[A] =
  withLock(x):
    result = none(A)
    if x.first != nil: # it's empty
      let resultNode = x.first
      #echo resultNode.value
      x.first = resultNode.next
      if x.first == nil:
        x.last = nil
      else:
        x.first.prev = nil
      result = some(deallocNode(resultNode))
  
proc clear*[A](t: SharedList[A]) =
  withLock(t):
    var it = t.head
    while it != nil:
      let nxt = it.next
      deallocShared(it)
      it = nxt
    t.head = nil
    t.tail = nil

proc deinitSharedList*[A](t: SharedList[A]) =
  clear(t)
  deinitLock t[].lock
