---
name: distributed-ppl
description: >
  Orchestrates the distributed PPL query engine project: PPL -> Calcite RelNode -> Trino SQL.
  Coordinates architecture decisions (Phase 1), implementation (Phases 2-3), testing (Phase 4),
  and operationalization (Phase 5). Spawns phase-specific sub-teams as needed.
  Scope: PPL only. SQL, async/Spark, cross-datasource joins, and ML commands are out of scope.
---

# Distributed PPL Query Engine: Project Orchestration

## 1 Mission

You are the **project lead** for building a distributed PPL query engine that translates
PPL queries through Calcite RelNode into Trino SQL for distributed execution on Trino.

**Output directory:** `~/oss/ppl/distributed-ppl/`

### Core Architecture

```
PPL text
  -> ANTLR Parser -> AST
  -> Analyzer (existing)
  -> Calcite RelNode tree (extend existing CalcitePlanContext + CalciteRelNodeVisitor)
  -> RelNode -> Trino SQL translator (extend existing UnifiedQueryTranspiler)
  -> Execute on Trino (Trino handles all distributed execution)
  -> Results back to OpenSearch PPL response format
```

### Why This Approach

- Trino is a proven distributed SQL engine with an existing OpenSearch connector
- Calcite RelNode is already extensively used in this codebase (CalciteRelNodeVisitor: 3,743 lines, 45+ visitor methods)
- UnifiedQueryTranspiler already converts RelNode to SQL using configurable SqlDialect
- OpenSearchSparkSqlDialect demonstrates the pattern for adding Trino as a new dialect
- Avoids building a custom distributed runtime inside OpenSearch

### What Already Exists (DO NOT REBUILD)

The codebase has extensive Calcite integration. Study these before planning work:

- `core/.../calcite/CalciteRelNodeVisitor.java` -- 3,743 lines, 45 visitor methods covering nearly all PPL commands
- `core/.../calcite/CalcitePlanContext.java` -- Framework configuration, RelBuilder, RexBuilder management
- `core/.../calcite/CalciteRexNodeVisitor.java` -- Expression translation
- `core/.../calcite/CalciteAggCallVisitor.java` -- Aggregation translation
- `api/.../UnifiedQueryTranspiler.java` -- RelNode -> SQL via RelToSqlConverter with configurable dialect
- `api/.../UnifiedQueryPlanner.java` -- Full pipeline: PPL string -> parse -> AST -> RelNode
- `api/.../compiler/UnifiedQueryCompiler.java` -- Compiles RelNode into executable PreparedStatement
- `ppl/.../calcite/OpenSearchSparkSqlDialect.java` -- Custom dialect pattern (model for TrinoSqlDialect)
- `benchmarks/.../UnifiedQueryBenchmark.java` -- JMH benchmark for transpilation time
- `core/.../calcite/plan/rule/` -- Optimization rules (PPLDedupConvertRule, PPLAggregateConvertRule, etc.)
- `core/.../calcite/udf/` -- User-defined functions (10+ implementations)
- `core/.../calcite/type/` -- Custom type system (8 type classes)
- `ppl/src/test/.../calcite/` -- 55 dedicated Calcite PPL test files

**Phase 2.1 (PPL->RelNode) is largely DONE. The remaining work is Trino-specific dialect adaptation and connector integration, NOT building the translation framework from scratch.**

## 2 Project Phases

| Phase | Description | Blocking Decision | Skill |
|-------|-------------|-------------------|-------|
| 1.1 | Calcite role evaluation | Calcite as IR / optimizer / skip? | `/distributed-ppl-phase1` |
| 1.2 | Trino-Lucene connector strategy | Strategy A/B/C/D? | `/distributed-ppl-phase1` |
| 1.3 | Trino integration depth | Level 1-5? | `/distributed-ppl-phase1` |
| 1.4 | PPL command coverage analysis | Per-command translation plan | `/distributed-ppl-phase1` |
| 2.1-2.2 | PPL -> RelNode -> Trino SQL | -- | `/distributed-ppl-translate` |
| 2.3-2.4 | Trino execution bridge + connector | -- | `/distributed-ppl-connector` |
| 3.x | PPL command migration (Tiers 1-3) | -- | `/distributed-ppl-translate` |
| 4.x | Testing and benchmarking | -- | `/distributed-ppl-qa` |
| 5.x | Configuration, explain, observability | -- | Lead handles directly |

## 3 Team Sizing (IMPORTANT)

Do NOT spawn 8 agents simultaneously. Communication overhead scales with team size.
Maximum 3 concurrent agents per phase:

| Phase | Team | Rationale |
|-------|------|-----------|
| 1 (design) | Lead + 1 infra-architect | Design needs depth, not parallelism |
| 2 (implementation) | Lead + ppl-translator + trino-integrator | Two independent workstreams |
| 3 (migration + QA) | Lead + ppl-translator + qa-validator | Incremental test as commands migrate |
| 5 (ops) | Lead alone (or + 1 helper) | Configuration plumbing |

### Agent Design Principles

1. **No senior/junior splits** -- Claude agents have identical capability regardless of title
2. **Sole authorship + review** -- One agent writes, lead reviews. No co-authorship (too expensive)
3. **File-based handoffs** -- Write artifacts to known paths, don't relay via messages
4. **Phase-based spawning** -- Spawn agents for current phase, shut down when done
5. **Skills for repeatable patterns** -- Benchmarks, SQL verification, pushdown testing are skills

## 4 Performance Gates (MANDATORY)

Read `references/performance-requirements.md` for full details. Hard gates:

1. **No regression for small queries**: < 10K docs must NOT route to distributed path
2. **Fixed overhead**: < 65ms (external Trino) or < 25ms (embedded Trino)
3. **Aggregation parity**: Trino+pushdown within 1.5x of single-node
4. **Join advantage**: 3x faster than single-node for 100K+ rows per side
5. **P99 concurrency**: Under 50 concurrent queries, P99 < 5x single-query
6. **Per-command gate**: No command ships if > 2x slower than single-node

Every Phase 3 PR must include benchmark results.

## 5 Critical Corrections from promot.md

The original prompt (promot.md) contains factual errors. Agents must be aware:

1. **Trino does NOT use Calcite internally.** Trino has its own IR (PlanNode), optimizer, and type system. Direct RelNode-to-PlanNode conversion requires mapping two different IRs. SQL string handoff may be the pragmatic choice.

2. **The Calcite decision (Phase 1.1) has been partially answered by the codebase.** The team already chose Calcite as IR and built the pipeline (UnifiedQueryTranspiler, UnifiedQueryPlanner). Phase 1.1 should evaluate whether to extend this existing infrastructure for Trino, not debate from scratch.

3. **Connector work is in a DIFFERENT repository.** The Trino OpenSearch connector lives in `https://github.com/trinodb/trino` (plugin/trino-opensearch). Work in this repo builds the PPL->SQL translation and execution bridge. Connector enhancement requires a Trino fork or upstream contribution.

## 6 Scope Constraints

1. PPL ONLY. Do not modify SQL execution, async-query, or Spark paths.
2. No ML commands (kmeans, AD, anomaly detection) -- out of scope.
3. No cross-datasource joins -- only OpenSearch-to-OpenSearch via Trino.
4. 100% backward compatibility -- when distributed mode is off, PPL is identical to today.
5. Feature flag: everything behind `plugins.ppl.distributed.enabled` (default false).
6. Follow existing code style: Java 11+, Lombok, Visitor pattern, 4-space indent.
7. Every new class must have corresponding unit tests.
8. When in doubt, the single-node engine is the source of truth -- match it exactly.
9. Log generated Trino SQL at DEBUG level.

## 7 Configuration (Phase 5)

```
plugins.ppl.distributed.enabled          (boolean, default false)
plugins.ppl.distributed.trino.url        (string, Trino JDBC URL)
plugins.ppl.distributed.trino.catalog    (string, OpenSearch catalog in Trino)
plugins.ppl.distributed.trino.schema     (string, default schema)
plugins.ppl.distributed.trino.user       (string, Trino auth user)
plugins.ppl.distributed.trino.pool.size  (int, default 10)
plugins.ppl.distributed.trino.timeout    (duration, default 60s)
plugins.ppl.distributed.auto_route       (boolean, default false)
plugins.ppl.distributed.auto_route.threshold  (long, determined by benchmarks)
plugins.ppl.distributed.fallback.commands     (string list, commands that always run locally)
```

## 8 References

- `references/architecture-context.md` -- Current PPL architecture and limitations
- `references/ppl-command-matrix.md` -- Per-command Trino SQL translatability
- `references/performance-requirements.md` -- Performance budget and gates
- `references/trino-connector-strategies.md` -- Connector strategy options A-D
- `references/trino-integration-levels.md` -- Integration depth options 1-5
- `references/task-dependency-graph.md` -- Phase and task dependencies
- `references/project-constraints.md` -- Hard rules and guidelines
