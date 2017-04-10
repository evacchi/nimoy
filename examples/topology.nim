import future, nimoy, nimoy/topologies

#
# source ~> map1 ~> fanIn ~> map3 ~> broadcast ~> sink1
#    +~~~~> map2 ~~~~~^                 +~~~~> sink2
#  

let t = createTopology()

let sink1Ref = t.sinkRef((x: int) => echo("sink1 = ", x))
let sink2Ref = t.sinkRef((x: int) => echo("sink2 = ", x))
let bref     = t.broadcastRef(sink1Ref, sink2Ref)
let map3Ref  = t.nodeRef((x: int) => x+7,  bref)
let fanInRef = t.nodeRef((x: int) => ( echo("fan in = ", x); x ), map3Ref)
let map2Ref  = t.nodeRef((x: int) => x-1, fanInRef)
let map1Ref  = t.nodeRef((x: int) => x*2, fanInRef)

# send input
for i in 0..10:
  map1Ref ! i

t.awaitTermination()

