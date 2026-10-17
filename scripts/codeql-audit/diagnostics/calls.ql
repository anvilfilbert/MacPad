/** All project call sites: compare file access boundaries against sources and sinks. */
import swift

from ApplyExpr call
where call.getLocation().getFile().getRelativePath().matches("Sources/%")
select call.getLocation().getFile().getRelativePath() as path,
  call.getLocation().getStartLine() as line, call.toString() as target
