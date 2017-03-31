import nimoy/tasks

proc ciao(): TaskState =
  echo "ciao"
  taskFinished
  
proc hello(): TaskState =
  echo "hello"
  taskFinished

proc salut(): TaskState =
  echo "salut"
  taskFinished

proc main() =
  var executor = createSimpleExecutor(2)

  executor.submit(ciao)
  executor.submit(hello)
  executor.submit(salut)

  executor.shutdown()
  executor.join()

main()
