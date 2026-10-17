/** Enumerate recognized local and remote sources for coverage review. */
import swift
import codeql.swift.dataflow.FlowSources

from FlowSource source, string scope
where
  source.getLocation().getFile().getRelativePath().matches("Sources/%") and
  (source instanceof LocalFlowSource and scope = "local"
  or source instanceof RemoteFlowSource and scope = "remote")
select source.getLocation().getFile().getRelativePath() as path,
  source.getLocation().getStartLine() as line, scope + ": " + source.getSourceType() as kind
