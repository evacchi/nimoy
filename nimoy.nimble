# Package

version       = "0.1.0"
author        = "Edoardo Vacchi"
description   = "Minimal experimental nim actor implementation"
license       = "Apache2"

# Dependencies

requires "nim >= 0.16.0"

srcDir = "src"

task pingpong, "compile pingpong":
  --hints: off
  --threads:on
  --linedir: on
  --stacktrace: on
  --linetrace: on
  --debuginfo
  --path: "src"
  setCommand "c", "examples/pingpong.nim"

task become, "compile become":
  --hints: off
  --threads:on
  --linedir: on
  --stacktrace: on
  --linetrace: on
  --debuginfo
  --path: "src"
  setCommand "c", "examples/become.nim"

task spawn, "compile spawn":
  --hints: off
  --threads:on
  --linedir: on
  --stacktrace: on
  --linetrace: on
  --debuginfo
  --path: "src"
  setCommand "c", "examples/spawn.nim"

task kill, "compile kill":
  --hints: off
  --threads:on
  --linedir: on
  --stacktrace: on
  --linetrace: on
  --debuginfo
  --path: "src"
  setCommand "c", "examples/kill.nim"

task hellotasks, "compile hellotasks":
  --hints: off
  --threads:on
  --linedir: on
  --stacktrace: on
  --linetrace: on
  --debuginfo
  --path: "src"
  setCommand "c", "examples/hellotasks.nim"
