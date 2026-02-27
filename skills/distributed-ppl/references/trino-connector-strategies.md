# Trino-Lucene Connector Strategies

## The Problem

Trino's existing OpenSearch connector (trino-opensearch) has limited pushdown:
- Does NOT push down: aggregations, complex filters, sorting, joins, nested traversal
- Only basic term/range queries pushed down
- All rows fetched, then processed in Trino workers

This means `source=index | stats count() by status` would:
- Current engine: push entire aggregation to OpenSearch (one API call)
- Naive Trino: fetch ALL documents, aggregate in Trino (terrible)

## Strategy A: ENHANCE THE TRINO OPENSEARCH CONNECTOR

Fork or extend trino-opensearch to push down more operations:
- Add aggregation pushdown: Trino AggregateNode -> OpenSearch aggregation DSL
- Add sort pushdown: Trino SortNode -> OpenSearch sort
- Add complex filter pushdown: SQL WHERE -> bool/nested/script queries
- Add projection pushdown: _source filtering or stored fields

**Pros:** Trino remains execution engine; operations execute on Lucene where efficient
**Cons:** Significant connector development; must keep in sync with Trino/OS versions

## Strategy B: CUSTOM TRINO CONNECTOR WITH DEEP LUCENE INTEGRATION

New connector from scratch that is Lucene-aware:
- Expose OpenSearch shards as Trino splits (one split per shard)
- Shard-level scan with local filter pushdown via Lucene Query API
- Use Lucene's native collector framework for aggregations
- Leverage doc values for columnar reads (fast scans)
- Leverage BKD trees for numeric/date range predicates

**Pros:** Maximum performance; direct Lucene access avoids REST overhead
**Cons:** Very complex; tight Lucene coupling; version sensitivity; needs shard access

## Strategy C: HYBRID -- OPENSEARCH AS SMART DATA SOURCE

Keep Trino as coordinator, but for Lucene-friendly operations generate
OpenSearch Query DSL sub-queries via REST:
- Trino handles: cross-index joins, window functions, UNION
- OpenSearch handles: filtered scans, aggregations, sorted+limited scans
- Connector translates Trino plan nodes to highest-level OS REST calls

**Pros:** Balanced complexity; leverages existing OS APIs; no Lucene coupling
**Cons:** REST overhead; some double-optimization; limited by OS REST API

## Strategy D: SPLIT EXECUTION MODEL

Analyze PPL query to route parts to different engines:
- Stage 1: Push scan + filter + aggregation to OpenSearch (native)
- Stage 2: Feed intermediate results to Trino for joins, windows, cross-index ops
- TrinoExecutionEngine becomes hybrid: sometimes calls OS, sometimes routes through Trino

**Pros:** Best of both worlds; Lucene handles what it excels at
**Cons:** Complex query splitting logic; two execution paths to maintain

## Lucene Capabilities to Leverage

| Capability | Use For | Pushdown Priority |
|-----------|---------|-------------------|
| Inverted index | Term/phrase lookups -> WHERE clauses | P0 |
| Doc values | Columnar storage -> sort/agg | P0 |
| BKD trees | Numeric/date range -> range filters | P0 |
| Global ordinals | Fast terms aggregation -> stats...by | P0 |
| Nested documents | Parent/child queries -> nested field access | P1 |
| Scroll/PIT API | Paginated access -> reliable data feed | P1 |
| _search_after | Deep pagination -> cursor-based streaming | P1 |

## Evaluation Criteria

For each strategy, evaluate:
1. Implementation effort (person-months)
2. Performance with top 10 PPL query patterns
3. Maintenance burden (version coupling, upstream sync)
4. Pushdown coverage (what % of common queries benefit?)
5. Compatibility with chosen integration depth (Level 1-5)
