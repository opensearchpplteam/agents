# PPL Command Translatability Matrix

## Core Commands

| PPL Command | Trino SQL Equivalent | Complexity | Lucene Pushdown | Tier |
|-------------|---------------------|------------|-----------------|------|
| source | SELECT * FROM table | Trivial | N/A (table scan) | 1 |
| where | WHERE condition | Trivial | Yes (Term/Range/Bool Query) | 1 |
| eval | SELECT *, expr AS alias | Low | No | 1 |
| fields | SELECT field_list | Trivial | Yes (_source filter) | 1 |
| rename | SELECT field AS new_name | Trivial | No | 1 |
| stats | SELECT agg_func GROUP BY | Low | Yes (terms/stats/date_histogram agg) | 1 |
| sort | ORDER BY | Trivial | Yes (OS sort clause) | 1 |
| head/limit | LIMIT | Trivial | Yes (size parameter) | 1 |
| fillnull | COALESCE | Trivial | No | 1 |
| rare | GROUP BY + ORDER BY ASC + LIMIT | Low | Partial (terms agg) | 1 |
| top | GROUP BY + ORDER BY DESC + LIMIT | Low | Partial (terms agg) | 1 |
| join | JOIN ... ON | Low | No (Trino handles) | 1 |
| lookup | LEFT JOIN on lookup table | Low | No (Trino handles) | 1 |

## Window Function Commands

| PPL Command | Trino SQL Equivalent | Complexity | Lucene Pushdown | Tier |
|-------------|---------------------|------------|-----------------|------|
| dedup | ROW_NUMBER() OVER (PARTITION BY keys ORDER BY ...) + WHERE rn=1 | Medium | No (full materialization) | 2 |
| eventstats | aggregate OVER (PARTITION BY ...) preserving all rows | Medium | No (full materialization) | 2 |
| trendline | Moving avg via windowed AVG/SUM with ROWS BETWEEN | Medium | No (full materialization) | 2 |

## Complex Commands

| PPL Command | Trino SQL Equivalent | Complexity | Lucene Pushdown | Tier |
|-------------|---------------------|------------|-----------------|------|
| expand | CROSS JOIN UNNEST for arrays | Medium | No | 3 |
| flatten | Lateral flatten / UNNEST | Medium | No | 3 |
| parse/grok | regexp_extract / Trino regex | High | No | 3 |
| rex | regexp_extract | Medium | No | 3 |
| patterns | Custom UDF or post-processing | High | No | 3 |
| fieldsummary | Multiple agg funcs per column | High | Partial (multi-agg) | 3 |
| append | UNION ALL of subqueries | Medium | No | 3 |

## Additional Commands (from CalciteRelNodeVisitor)

The following are handled by CalciteRelNodeVisitor but not in the original matrix:

| PPL Command | Notes | Tier |
|-------------|-------|------|
| appendcol | Subsearch variant | 3 |
| bin/span | Histogram bucketing -> date_histogram or range | 2 |
| describe | Metadata query -> information_schema | 3 |
| existsSubquery | EXISTS subquery | 2 |
| inSubquery | IN subquery | 2 |
| scalarSubquery | Scalar subquery | 2 |
| correlation | Time-series correlation -> window functions | 3 |

## Execution Venue Recommendation

| Venue | When to Use | Commands |
|-------|-------------|----------|
| **Lucene-native** | Single-index, pushdown-friendly | where, stats (simple), sort+limit |
| **Trino** | Cross-index, large datasets, joins | join, lookup, multi-index queries |
| **Hybrid** | Filter in Lucene, complex ops in Trino | where + stats (complex), where + dedup |
| **Fallback** | Cannot translate to SQL | patterns (if no UDF), custom commands |

## Per-Command Performance Expectation

| Command | <10K docs | 100K-1M docs | >1M docs |
|---------|-----------|--------------|----------|
| where (with pushdown) | Single-node faster | Comparable | Trino faster |
| stats (with pushdown) | Single-node faster | Comparable | Trino faster |
| join | Single-node faster | Break-even | Trino 3-10x faster |
| dedup (window func) | Single-node faster | Single-node faster | Trino faster |
| sort + limit (with pushdown) | Single-node faster | Comparable | Trino faster |
