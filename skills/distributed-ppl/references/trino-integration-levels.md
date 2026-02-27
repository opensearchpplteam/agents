# Trino Integration Depth Levels

## The Problem

The "send Trino SQL over JDBC" approach has overhead:

```
PPL -> RelNode -> Trino SQL string
-> JDBC network call to Trino coordinator
-> Trino parses SQL string (redundant -- we had IR)
-> Trino analyzes and resolves types (redundant -- we did this)
-> Trino optimizes into logical plan (we had RelNode, now re-planned)
-> Trino creates physical plan with splits
-> Workers execute via connector -> REST to OpenSearch
-> Results flow back through 3 network boundaries
```

## Level 1: TRINO AS EXTERNAL SERVICE (simplest)

Send Trino SQL over JDBC/REST to a separate Trino cluster.

**Pros:** Clean separation; independent Trino upgrades; well-understood
**Cons:** Maximum overhead (double-parse, double-plan, 3 network hops);
requires operating separate Trino cluster; cold-start latency

**Overhead estimate:** ~65ms fixed

## Level 2: EMBEDDED TRINO (library inside OpenSearch)

Embed Trino coordinator (optionally workers) in OpenSearch JVM.
Submit queries via in-process API instead of JDBC.

**Pros:** No external cluster; eliminates one network hop; single deployment;
connector can use local transport
**Cons:** JVM resource contention; version coupling; classloader complexity;
Trino may not be designed for embedding; still double-parses

**Overhead estimate:** ~40ms fixed

## Level 3: EXTRACT TRINO OPTIMIZER + PLAN DIRECTLY

Feed Calcite RelNode directly into Trino's optimizer, skip SQL generation.

**IMPORTANT: Trino does NOT use Calcite internally.** Trino has its own IR
(io.trino.sql.planner.plan.PlanNode), its own optimizer, and its own type system.
Direct RelNode-to-PlanNode conversion requires mapping between two different IRs.

**Pros:** Eliminates redundant parse/analyze/plan; tightest integration
**Cons:** Deep coupling to Trino internals; PlanNode is not public API;
significant reverse-engineering; maintenance on every Trino upgrade

**Overhead estimate:** ~25ms fixed

## Level 4: EXTRACT TRINO PHYSICAL OPERATORS ONLY

Don't use Trino as whole engine -- extract specific operators OpenSearch lacks:
- Distributed HashJoin operator
- Distributed Exchange/Shuffle operator
- Distributed Sort (merge sort across partitions)
- Window function execution engine

Integrate into OpenSearch's execution framework.

**Pros:** Best performance; no redundancy; operators in OS JVM with Lucene access
**Cons:** Extremely complex; Trino operators depend on Trino's memory/task system;
may require reimplementation; maintenance nightmare

## Level 5: TRINO-INSPIRED CUSTOM OPERATORS

Study Trino's operators and reimplement natively in OpenSearch:
- DistributedHashJoin
- ShuffleExchange
- MergeSortGather
as OpenSearch PhysicalPlan operators using OpenSearch transport.

**Pros:** No Trino dependency; native to OpenSearch; optimized for Lucene
**Cons:** Building distributed query engine from scratch; massive effort

## Investigation Required

a) How deeply can Trino be embedded?
   - Is there a trino-core that can run in-process?
   - What does startup sequence require? (discovery, catalog)
   - Can coordinator run without separate discovery service?

b) Can we bypass Trino's SQL parser?
   - Trino's PlanNode (io.trino.sql.planner.plan.PlanNode) -- accessible?
   - Can we construct PlanNode trees programmatically?
   - Is there a public API for submitting plans instead of SQL?

c) What is the true overhead of each approach?
   - Benchmark: embedded vs external vs direct
   - For simple `where + stats`, what % is overhead?

d) What Trino physical operators do we actually need?
   - For PPL without ML and without cross-datasource joins:
     HashJoin, Exchange, MergeSort, WindowOperator
   - Is reimplementing 4 operators feasible?

## Evaluation Criteria

| Criterion | L1 | L2 | L3 | L4 | L5 |
|-----------|----|----|----|----|-----|
| Implementation effort | Low | Medium | High | Very High | Extreme |
| Fixed overhead | ~65ms | ~40ms | ~25ms | ~10ms | ~5ms |
| Operational complexity | High (separate cluster) | Medium | Medium | Low | Low |
| Trino coupling | Low | Medium | High | Very High | None |
| Maintenance burden | Low | Medium | High | Very High | High |
