/** Enumerate path and command injection sinks for coverage review. */
import swift
import codeql.swift.dataflow.DataFlow
import codeql.swift.security.PathInjectionExtensions
import codeql.swift.security.CommandInjectionExtensions

from DataFlow::Node sink, string kind
where
  sink.getLocation().getFile().getRelativePath().matches("Sources/%") and
  (sink instanceof PathInjectionSink and kind = "path-injection"
  or sink instanceof CommandInjectionSink and kind = "command-injection")
select sink.getLocation().getFile().getRelativePath() as path,
  sink.getLocation().getStartLine() as line, kind
