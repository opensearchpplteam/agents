---
name: distributed-ppl-connector
description: >
  Trino OpenSearch connector enhancement and execution bridge implementation. Covers
  Phase 2.3 (Trino execution bridge in OpenSearch), Phase 2.4 (connector pushdown
  enhancement), and pushdown testing. CRITICAL PATH: without connector pushdown, the
  distributed engine is strictly worse than single-node for all queries.
---

# Distributed PPL: Connector & Execution Bridge

## 1 Mission

You are the **infrastructure team lead** implementing two tightly coupled components:

1. **Trino Execution Bridge** (Phase 2.3): The `TrinoExecutionEngine` in this repo that
   submits Trino SQL and converts results back to OpenSearch PPL format
2. **Connector Enhancement** (Phase 2.4): Pushdown operations in the Trino OpenSearch
   connector (external repo: trinodb/trino)

**This is the critical path.** Without effective connector pushdown, Trino must full-scan
every document and is strictly worse than single-node for ALL queries. Filter pushdown
alone can reduce data transfer 10-1000x. Aggregation pushdown can reduce it 100-10000x.

**Output directory:** `~/oss/ppl/distributed-ppl/connector/`

## 2 Prerequisites

- Phase 1.2 (connector strategy) and 1.3 (integration depth) MUST be finalized
- Read Phase 1 decision documents
- Read `references/opensearch-pushdown-api.md` for OpenSearch Query DSL patterns
- Read `references/trino-connector-spi.md` for Trino connector extension points
- Read `.claude/skills/distributed-ppl/references/performance-requirements.md`

## 3 Repository Boundaries

**Work in THIS repo (opensearch-project/sql):**
- TrinoExecutionEngine implementing ExecutionEngine interface
- TrinoResultConverter (Trino results -> ExprValue rows)
- TrinoClient (JDBC connection pool, error mapping, cancellation)
- Configuration settings, explain support
- Integration tests

**Work in EXTERNAL repo (trinodb/trino or a fork):**
- Connector pushdown enhancements (filter, agg, sort, limit, projection)
- Shard-aware split generation
- Data type mapping improvements
- Transport layer (scroll/PIT API, batch sizing, back-pressure)

The team must document clearly which changes go where.

## 4 Team Structure

| Agent | Role | Focus | Subagent Type |
|-------|------|-------|---------------|
| `trino-integrator` | Execution bridge + connector engineer | Builds both bridge and connector | general-purpose |

The lead coordinates with the translation team for API contracts and reviews all work.

### Spawn Prompt: trino-integrator

```
You are "trino-integrator" on the distributed-ppl-connector team. You build both the
Trino execution bridge (in this repo) and evaluate/prototype connector pushdown
enhancements (for the Trino OpenSearch connector).

YOUR WORK:
1. Phase 2.3: Build TrinoExecutionEngine
   - Implement ExecutionEngine interface
   - JDBC connection pooling with configurable pool size
   - Pre-warm connections on plugin startup
   - Error mapping: Trino errors -> meaningful PPL errors
   - Query cancellation: propagate cancel from OpenSearch to Trino
   - TrinoResultConverter: Trino ResultSet -> ExprValue rows
   - Measure fixed overhead (target: <65ms external, <25ms embedded)

2. Phase 2.4: Connector Pushdown (in order of value)
   - P0: Filter pushdown (Term, Range, Bool -> OpenSearch Query DSL)
   - P0: Aggregation pushdown (terms, stats, date_histogram -> OS Agg DSL)
   - P1: Sort pushdown (ORDER BY -> OS sort clause)
   - P1: Limit pushdown (LIMIT -> OS size parameter)
   - P2: Projection pushdown (column selection -> _source filtering)

Key files in this repo:
- ppl/src/main/java/org/opensearch/sql/ppl/PPLService.java (entry point to modify)
- core/src/main/java/org/opensearch/sql/executor/ExecutionEngine.java (interface)

Read Phase 1 decisions for chosen connector strategy and integration depth.
Write code, tests, and pushdown coverage reports.
Send progress updates to team-lead when milestones complete.
```

## 5 Execution Bridge Design (Phase 2.3)

Shape depends on Phase 1.3 integration depth decision:

### If Level 1 (External Trino)
- TrinoExecutionEngine implements ExecutionEngine
- TrinoClient: JDBC connection pool with configurable size
- Pre-warm pool on plugin startup
- Connection health checks
- Query timeout propagation

### If Level 2 (Embedded Trino)
- EmbeddedTrinoEngine: Manages Trino lifecycle in OpenSearch JVM
- In-process query submission API
- Shared memory result passing (no serialization)
- Strict memory limits for Trino portion of heap

### If Level 3+ (Extracted/Direct)
- DirectPlanSubmitter: Constructs Trino PlanNode from RelNode
- (Note: Trino does NOT use Calcite -- this requires custom IR mapping)

### Common for All Levels
- TrinoResultConverter: Trino types -> ExprValue types
- Error mapping: translate Trino errors to PPL errors
- Query cancellation bridge
- Overhead target: measure with empty result set

## 6 Connector Pushdown Priority

| Priority | Operation | OpenSearch Translation | Expected Reduction |
|----------|-----------|----------------------|-------------------|
| P0 | Filter | bool/term/range/nested Query DSL | 10-1000x rows |
| P0 | Aggregation | terms/stats/date_histogram Agg DSL | 100-10000x rows |
| P1 | Sort | sort clause | 10-100x with limit |
| P1 | Limit | size parameter | Direct row reduction |
| P2 | Projection | _source filtering | 2-10x data volume |

### Per-Pushdown Workflow

For each operation:
1. Implement Trino plan node -> OpenSearch Query DSL translation
2. Verify correct DSL for all predicate types
3. Measure rows transferred: with pushdown vs without
4. Test with varied data (nulls, nested, multi-value, high cardinality)
5. Verify shard-aware split generation (1 split per shard)

## 7 Data Type Mapping

| OpenSearch | Trino | Pushdown Notes |
|-----------|-------|----------------|
| keyword | VARCHAR | TermQuery, TermsQuery |
| text | VARCHAR | MatchQuery (limited) |
| integer/long | INTEGER/BIGINT | PointRangeQuery |
| float/double | REAL/DOUBLE | PointRangeQuery |
| date | TIMESTAMP | RangeQuery with format |
| boolean | BOOLEAN | TermQuery |
| nested | ROW | NestedQuery |
| ip | VARCHAR | CidrQuery |
| geo_point | geometry/VARCHAR | GeoBoundingBoxQuery |

## 8 Shard-Aware Splits

- Map 1 Trino split to 1 OpenSearch shard for maximum parallelism
- Use scroll/PIT + search_after for paginated reads per split
- Tune batch size (benchmark: 1K, 5K, 10K docs per batch)
- Implement back-pressure from Trino to OpenSearch
- Monitor for imbalanced shard sizes (warn on stragglers)

## 9 References

- `references/opensearch-pushdown-api.md`
- `references/trino-connector-spi.md`
- Parent skill: `.claude/skills/distributed-ppl/references/performance-requirements.md`
- Parent skill: `.claude/skills/distributed-ppl/references/trino-connector-strategies.md`
