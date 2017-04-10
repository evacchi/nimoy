# Package

version       = "0.1.0"
author        = "Edoardo Vacchi"
description   = "Minimal experimental nim actor implementation"
license       = "Apache2"

# Dependencies

requires "nim >= 0.16.0"
srcDir = "src"

proc buildExample(example: string) =
  echo "\nBuilding ", example, "..."
  exec "nim c "           &
       "--hints:off "     &
       "--linedir:on "    &
       "--stacktrace:on " &
       "--linetrace:on "  &
       "--debuginfo "     &
       "--threads:on "    &
       "--path:src examples/" & example & ".nim"

task pingpong, "compile pingpong":
  buildExample("pingpong")

task become, "compile become":
  buildExample("become")

task spawn, "compile spawn":
  buildExample("spawn")
  
task kill, "compile kill":
  buildExample("kill")

task topology, "compile topology":
  --hints: off
  --threads:on
  --linedir: on
  --stacktrace: on
  --linetrace: on
  --debuginfo
  --path: "src"
  setCommand "c", "examples/topology.nim"

task hellotasks, "compile hellotasks":
  buildExample("hellotasks")

task loader, "compile loader":
  buildExample("loader")

task examples, "compile all the examples":
  pingpongTask()
  becomeTask()
  spawnTask()
  killTask()
  hellotasksTask()
  loaderTask()
  