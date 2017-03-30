import nimoy/tasks

proc ciao() =
  stdout.writeLine "ciao"
proc hello() =
  stdout.writeLine "hello"
proc salut() =
  stdout.writeLine "salut"

proc main() =
  var executor = createExecutor(2)

  executor.submit(Task(ciao))
  executor.submit(Task(hello))
  executor.submit(Task(salut))

  executor.join()

main()
