/**
 * @name Local input reaches a file path (review only)
 * @description Enumerates shipped local-source flows for manual review; normal editor file selection is not a vulnerability.
 * @kind path-problem
 * @problem.severity recommendation
 * @precision medium
 * @id macpad-audit/local-path-flow-review
 */

import swift
import codeql.swift.dataflow.DataFlow
import codeql.swift.dataflow.FlowSources
import codeql.swift.dataflow.TaintTracking
import codeql.swift.security.PathInjectionExtensions

module LocalPathConfig implements DataFlow::ConfigSig {
  predicate isSource(DataFlow::Node source) {
    source instanceof LocalFlowSource and
    source.getLocation().getFile().getRelativePath().matches("Sources/%")
  }

  predicate isSink(DataFlow::Node sink) {
    sink instanceof PathInjectionSink and
    sink.getLocation().getFile().getRelativePath().matches("Sources/%")
  }

  predicate isBarrier(DataFlow::Node barrier) { barrier instanceof PathInjectionBarrier }

  predicate isAdditionalFlowStep(DataFlow::Node first, DataFlow::Node second) {
    any(PathInjectionAdditionalFlowStep step).step(first, second)
  }
}

module LocalPathFlow = TaintTracking::Global<LocalPathConfig>;
import LocalPathFlow::PathGraph

from LocalPathFlow::PathNode source, LocalPathFlow::PathNode sink
where LocalPathFlow::flowPath(source, sink)
select sink.getNode(), source, sink,
  "Review this flow from $@. User-authorized file access is expected editor behavior, not automatically a vulnerability.",
  source.getNode(), "a modeled local input"
