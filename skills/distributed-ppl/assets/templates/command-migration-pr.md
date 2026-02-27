## PPL Command: `{command_name}` -- Distributed Path Migration

### Translation
- PPL: `source=idx | {command_name} ...`
- Trino SQL: `{generated SQL}`
- Translation tier: {1/2/3}
- Fallback: {yes/no -- if yes, why}

### Benchmark Results

| Scale | Single-Node (ms) | Trino (ms) | Trino+Pushdown (ms) | Rows Transferred | Speedup |
|-------|------------------|------------|---------------------|-----------------|---------|
| 1K docs | | | | | |
| 100K docs | | | | | |
| 1M docs | | | | | |

### Performance Gate
- [ ] Not > 2x slower than single-node at any scale
- [ ] Aggregation within 1.5x of single-node (if applicable)
- [ ] Pushdown verified (rows transferred with pushdown < 10% of without)

### Tests Added
- [ ] Unit test: generated SQL pattern
- [ ] Round-trip test: PPL -> Trino SQL -> execute -> compare with single-node
- [ ] Edge cases: NULLs, empty results, nested fields, Unicode
