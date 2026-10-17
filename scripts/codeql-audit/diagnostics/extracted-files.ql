/** Enumerate project Swift files with extracted AST locations, not just archived source. */
import swift

from File file
where
  file.getRelativePath().matches("Sources/%.swift") and
  (exists(Decl declaration | declaration.getLocation().getFile() = file)
  or exists(Expr expression | expression.getLocation().getFile() = file))
select file.getRelativePath() as path, file.getNumberOfLinesOfCode() as lines
