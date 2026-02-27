# Benchmark Results: [Baseline | Post-Optimization]

**Date:** [date]
**Author:** [name]
**Branch:** [branch name]
**Commit:** [short SHA]

## Protocol

- **Warmup:** 10 iterations per query (results discarded)
- **Measurement:** 50 iterations per query with `"profile": true`
- **Primary metric:** p90 optimize time (value at index 45 of sorted measurements)

## Environment

- OpenSearch: [version/branch]
- JVM: [version]
- OS: [description]
- CPU: [description]
- RAM: [description]
- Disk: [SSD/HDD]

## Test Data

| Index | Documents | Fields | Mapping |
|-------|-----------|--------|---------|
| [name] | [count] | [count] | [keyword, integer, etc.] |

## Query Results

### Q1: Simple Projection
**Query:** `source=<index> | fields id, name`
**Warmup:** 10 iterations completed

| Stat | Analyze (ms) | Optimize (ms) | Execute (ms) | Format (ms) | Total (ms) |
|------|-------------|---------------|-------------|-------------|------------|
| min  |             |               |             |             |            |
| median |           |               |             |             |            |
| mean |             |               |             |             |            |
| **p90** |          |               |             |             |            |
| max  |             |               |             |             |            |

<details>
<summary>Raw measurements (50 runs)</summary>

| Run | Analyze (ms) | Optimize (ms) | Execute (ms) | Format (ms) | Total (ms) |
|-----|-------------|---------------|-------------|-------------|------------|
| 1   |             |               |             |             |            |
| ... |             |               |             |             |            |
| 50  |             |               |             |             |            |

</details>

### Q2: Eval + Sort + Limit
**Query:** `source=<index> | eval a = rand() | sort a | fields id | head 5`
**Warmup:** 10 iterations completed

[Same table structure as Q1]

### Q3: Filter + Eval + Sort
**Query:** `source=<index> | where value > 2.0 | eval score = value * 100 | sort score`
**Warmup:** 10 iterations completed

[Same table structure as Q1]

### Q4: Aggregation
**Query:** `source=<index> | stats avg(value) as avg_val by name`
**Warmup:** 10 iterations completed

[Same table structure as Q1]

### Q5: Multi-Eval + Filter + Sort + Limit
**Query:** `source=<index> | eval a = value * 2, b = a + 1 | where b > 5 | sort b | head 3`
**Warmup:** 10 iterations completed

[Same table structure as Q1]

## Summary

| Query | p90 Optimize (ms) | Median Optimize (ms) | Mean Optimize (ms) | p90 Total (ms) |
|-------|--------------------|---------------------|--------------------|-----------------|
| Q1    |                    |                     |                    |                 |
| Q2    |                    |                     |                    |                 |
| Q3    |                    |                     |                    |                 |
| Q4    |                    |                     |                    |                 |
| Q5    |                    |                     |                    |                 |
| **Avg** |                  |                     |                    |                 |

## Notes

[Any observations about variance, warmup effects, outliers, etc.]
