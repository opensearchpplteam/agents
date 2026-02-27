# Performance Requirements

Performance is a FIRST-CLASS CONCERN. A distributed engine slower than single-node
for common queries adds operational complexity for negative value.

## Performance Budget Per Query

| Layer | Budget | Notes |
|-------|--------|-------|
| PPL parse + analyze | <5ms | Existing, fixed |
| PPL -> RelNode | <5ms | In-memory IR |
| RelNode -> Trino SQL | <5ms | String generation |
| Trino submission | <10ms | JDBC/REST call (0ms if embedded) |
| Trino parse + plan | <20ms | Redundant work (0ms if Level 3+) |
| Trino -> connector | <5ms | Split planning |
| Connector -> OpenSearch | <10ms | REST/transport (0ms if local) |
| Lucene execution | variable | Data-dependent |
| Result transport back | variable | Data-dependent |
| Result conversion | <5ms | Type mapping |
| **TOTAL FIXED OVERHEAD** | **<65ms** | **Level 1 (external Trino)** |
| **TOTAL FIXED OVERHEAD** | **<25ms** | **Level 3 (embedded+direct)** |

For a 50ms single-node query, 65ms overhead makes it 115ms (2.3x regression).
This is unacceptable for small queries. Auto-routing threshold must account for this.

## Hard Performance Gates

### Gate 1: No Regression for Small Queries
Queries on < 10K documents must NOT be routed to distributed path by default.

### Gate 2: Break-Even Point
Team must determine exact document count where distributed > single-node.
Estimate: 100K-500K docs depending on query type. This sets `auto_route.threshold`.

### Gate 3: Aggregation Parity
`stats count() by field` on 1M docs via Trino WITH pushdown must complete
within 1.5x of single-node. Without pushdown: 10-100x slower (unacceptable).

### Gate 4: Join Advantage
Cross-index joins on 100K+ rows per side must be at least 3x faster than
single-node nested-loop. This is the key win for Trino.

### Gate 5: Sort + Limit
`sort field | head 100` on 10M docs via Trino must be faster than single-node.
Requires connector to push sort down to Lucene per shard.

### Gate 6: P99 Latency
P99 of distributed path (excluding Lucene) must not exceed 200ms.
P99 under 50 concurrent queries must not exceed 5x single-query latency.

### Gate 7: Per-Command Gate
No PPL command ships through Trino if > 2x slower than single-node for same query.

## Pushdown Impact Matrix

| Operation | With Pushdown | Without Pushdown |
|-----------|--------------|-----------------|
| filter (where) | Lucene query: fast, only matching docs transferred | Full scan + Trino filter: 10-1000x slower |
| aggregation (stats) | OS agg API: fast, only agg results transferred | Full scan + Trino aggregate: 100-10000x slower |
| sort + limit | OS sort + size: only top-N docs | Full scan + Trino sort: 10-100x slower |
| projection (fields) | _source filter: less network I/O | Full docs fetched: 2-10x more data |

**CONCLUSION:** Without connector pushdown for at least filter + agg, the Trino path
is strictly worse than single-node for ALL queries.

## Benchmark Suite

### Micro-benchmarks
- PPL -> RelNode translation time (per command type)
- RelNode -> Trino SQL generation time
- Trino SQL submission + result retrieval overhead (no data)
- Connector pushdown DSL generation time

### Single-Operation Benchmarks (1K, 100K, 1M, 10M docs)
- `source=idx | where status='ok'` (filter only)
- `source=idx | stats count() by status` (aggregation)
- `source=idx | sort timestamp | head 100` (sort + limit)
- `source=idx | eval x=a+b | fields x,c` (eval + project)
- `source=idx | dedup user_id` (window + filter)

### Multi-Operation Benchmarks (1M docs)
- `source=idx | where status='ok' | stats avg(latency) by region`
- `source=idx | join left=idx2 on user_id | stats count() by region`
- `source=idx | where ts > '2024-01-01' | sort latency | head 1000`
- `source=idx | stats count() by status | where count > 100`

### Per-Command Comparison Matrix
For each benchmark, report:
- Single-node engine latency (ms)
- Trino path latency (ms)
- Trino path with pushdown latency (ms)
- Rows transferred to Trino (with and without pushdown)
- Speedup ratio (or regression ratio)
