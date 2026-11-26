# Package
version       = "0.1.0"
author        = "jasagiri"
description   = "Algorithms, data structures and design patterns as functional, idempotent modern Nim: tested modules, agent skills and a training dataset, cited to free books"
license       = "Apache-2.0"
srcDir        = "src"
installExt    = @["nim"]

# Dependencies
requires "nim >= 2.4.2"

task test, "Run the test suite":
  exec "nim test"
