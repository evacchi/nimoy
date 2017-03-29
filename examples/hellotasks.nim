proc ciao() =
  stdout.writeLine "ciao"
proc hello() =
  stdout.writeLine "hello"
proc salut() =
  stdout.writeLine "salut"

proc main() =
  var executor = createExecutor()

  executor.submit(Task(ciao))
  executor.submit(Task(hello))
  executor.submit(Task(salut))

  executor.start()

main()

