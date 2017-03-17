# Shameless rip-off https://github.com/vegansk/nimfp/blob/master/src/fp/list.nim
# under MIT https://github.com/vegansk/nimfp/blob/master/LICENSE

# The MIT License (MIT)

# Copyright (c) 2015 Anatoly Galiulin

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

type
  ListNodeKind = enum
    lnkNil, lnkCons
  List*[T] = ref object
    ## List ADT
    case kind: ListNodeKind
    of lnkNil:
      discard
    of lnkCons:
      value: T
      next: List[T]

proc Cons*[T](head: T, tail: List[T]): List[T] =
  ## Constructs non empty list
  List[T](kind: lnkCons, value: head, next: tail)

proc Nil*[T](): List[T] =
  ## Constructs empty list
  List[T](kind: lnkNil)

proc head*[T](xs: List[T]): T =
  ## Returns list's head
  case xs.kind
  of lnkCons: return xs.value
  else: doAssert(xs.kind == lnkCons)
  
proc tail*[T](xs: List[T]): List[T] =
  ## Returns list's tail
  case xs.kind
  of lnkCons: xs.next
  else: xs


proc isEmpty*(xs: List): bool =
  ## Checks  if list is empty
  xs.kind == lnkNil

iterator items*[T](xs: List[T]): T =
  var cur = xs
  while not cur.isEmpty:
    yield cur.head
    cur = cur.tail

iterator pairs*[T](xs: List[T]): tuple[key: int, val: T] =
  var cur = xs
  var i = 0.int
  while not cur.isEmpty:
    yield (i, cur.head)
    cur = cur.tail
    inc i