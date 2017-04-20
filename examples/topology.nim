import future, nimoy, nimoy/topologies

#
# source ~> map1 ~> fanIn ~> map3 ~> broadcast ~> sink1
#    +~~~~> map2 ~~~~~^                 +~~~~> sink2
#

let t = createTopology()
let sink1 = allocActorChannel[int]()
let sink2 = allocActorChannel[int]()

# declare output sinks
let sink1Ref = t.sinkRef((x: int) => sink1.send(x*100))
let sink2Ref = t.sinkRef((x: int) => sink2.send(x))

# broadcast to both sinks
let bref     = t.broadcastRef(sink1Ref, sink2Ref)

# map to the broadcast
let map3Ref  = t.nodeRef((x: int) => x+7,  bref)

# map to map3
let fanInRef = t.nodeRef((x: int) => ( echo("fan in = ", x); x ), map3Ref)

# two nodes that both go into fanIn
let map1Ref  = t.nodeRef((x: int) => x*2, fanInRef)
let map2Ref  = t.nodeRef((x: int) => x-1, fanInRef)

# send data to both the sources
for i in 0..10:
  map1Ref ! i
  map2Ref ! i

for i in 0..10:
  echo sink1.recv()
  echo sink2.recv()
