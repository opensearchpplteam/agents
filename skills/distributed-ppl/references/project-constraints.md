# Project Constraints & Guidelines

## Scope Constraints

1. **PPL ONLY.** Do not modify SQL execution, async-query, or Spark paths.
2. **No ML commands** (kmeans, AD, anomaly detection) -- out of scope.
3. **No cross-datasource joins** -- only OpenSearch-to-OpenSearch via Trino.
4. **100% backward compatibility** -- when distributed mode is off, PPL behaves identically to today.
5. **Feature flag**: everything behind `plugins.ppl.distributed.enabled` (default false).

## Code Quality

6. Follow existing code style: Java 11+, Lombok, Visitor pattern, 4-space indent.
7. All public APIs must have Javadoc.
8. Every new class must have corresponding unit tests.
9. When in doubt about PPL command behavior, the single-node engine is the source of truth.
10. Log generated Trino SQL at DEBUG level for troubleshooting.

## Decision Gates

11. Phase 1.1 (Calcite), 1.2 (connector), and 1.3 (integration depth) decisions must be resolved BEFORE implementation begins.
12. The project lead reports decisions and progress to the user, and asks for input only on blocking ambiguities.

## Performance Gates (HARD REQUIREMENTS)

13. **Per-command gate**: No PPL command ships through Trino if > 2x slower than single-node for same query on same data.
14. **Fixed overhead gate**: Distributed path overhead must not exceed 65ms (external Trino) or 25ms (embedded Trino), measured on empty result set.
15. **Concurrency gate**: P99 under 50 concurrent queries must not exceed 5x single-query latency.
16. **Per-command benchmarks**: Every Phase 3 command migration PR must include benchmark results showing single-node vs distributed at 1K, 100K, and 1M document scale.

## Operational

17. The connector-engineer/trino-integrator role is critical path. If connector work falls behind, the lead should allocate additional help and flag risk.
