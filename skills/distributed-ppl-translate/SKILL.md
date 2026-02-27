---
name: distributed-ppl-translate
description: >
  Implements PPL -> Calcite RelNode -> Trino SQL translation pipeline. Covers Phase 2.1
  (PPL to RelNode gap analysis), Phase 2.2 (Trino SQL dialect), and Phase 3 (per-command
  migration with round-trip testing and benchmarking). Each command migration includes
  translation, pushdown verification, and per-command benchmarking.
---

# Distributed PPL: Translation Implementation

## 1 Mission

You are the **translation team lead** implementing the PPL -> Calcite RelNode -> Trino SQL
pipeline. Most of the PPL -> RelNode translation already exists (CalciteRelNodeVisitor).
Your primary work is:

1. **Gap analysis**: Identify what CalciteRelNodeVisitor is missing for Trino
2. **Trino SQL dialect**: Create OpenSearchTrinoSqlDialect (model after OpenSearchSparkSqlDialect)
3. **Per-command migration**: Verify each PPL command works E2E through the Trino path
4. **Performance gating**: Benchmark each command; fallback if > 2x slower

**Output directory:** `~/oss/ppl/distributed-ppl/translate/`

## 2 Prerequisites

Before starting:
- Phase 1 decisions MUST be finalized (especially 1.1 Calcite role)
- Read Phase 1 decision documents at `~/oss/ppl/distributed-ppl/phase1/`
- Read `references/trino-sql-dialect.md` for Trino SQL syntax
- Read `references/ppl-relnode-mapping.md` for translation patterns

## 3 Key Existing Infrastructure

**DO NOT rebuild. Extend these:**

| Component | File | What It Does |
|-----------|------|-------------|
| CalciteRelNodeVisitor | `core/.../calcite/CalciteRelNodeVisitor.java` | PPL AST -> RelNode (45 visitors, 3,743 lines) |
| CalcitePlanContext | `core/.../calcite/CalcitePlanContext.java` | Manages RelBuilder, RexBuilder, framework config |
| UnifiedQueryTranspiler | `api/.../transpiler/UnifiedQueryTranspiler.java` | RelNode -> SQL string via RelToSqlConverter |
| UnifiedQueryPlanner | `api/.../UnifiedQueryPlanner.java` | PPL string -> parse -> AST -> RelNode pipeline |
| OpenSearchSparkSqlDialect | `ppl/.../calcite/OpenSearchSparkSqlDialect.java` | Custom dialect pattern (model for Trino) |
| UnifiedQueryBenchmark | `benchmarks/.../UnifiedQueryBenchmark.java` | JMH benchmark for transpilation time |

The main NEW work is creating `OpenSearchTrinoSqlDialect` and verifying each PPL command's
generated SQL is valid and efficient for Trino's optimizer.

## 4 Team Structure

| Agent | Role | Focus | Subagent Type |
|-------|------|-------|---------------|
| `translator` | PPL-to-Trino engineer | Implements dialect and fills translation gaps | general-purpose |

The lead reviews translations, resolves edge cases, and enforces performance gates.

### Spawn Prompt: translator

```
You are "translator" on the distributed-ppl-translate team. You implement the Trino SQL
dialect and per-command translation for the distributed PPL engine.

YOUR WORK:
1. Create OpenSearchTrinoSqlDialect extending Calcite's TrinoSqlDialect
   - Model after: ppl/.../calcite/OpenSearchSparkSqlDialect.java
   - Map PPL-specific functions to Trino equivalents
2. Audit CalciteRelNodeVisitor for any Trino-incompatible RelNode patterns
3. For each PPL command (Tier 1 first, then 2, then 3):
   - Verify the generated Trino SQL is valid
   - Write unit tests verifying SQL output
   - Write round-trip tests (PPL -> Trino SQL -> execute -> compare with single-node)

Key files:
- core/.../calcite/CalciteRelNodeVisitor.java (3,743 lines -- the core translator)
- api/.../transpiler/UnifiedQueryTranspiler.java (RelNode -> SQL converter)
- ppl/.../calcite/OpenSearchSparkSqlDialect.java (dialect pattern to follow)
- ppl/src/test/.../calcite/ (55 existing test files -- add Trino variants)

Read the Phase 1.4 command coverage matrix for translation priorities.
Write code and tests. Send progress updates to team-lead when milestones complete.
```

## 5 Translation Tiers

### Tier 1: Direct Translation (highest priority)

Commands mapping cleanly to SQL:
`source`, `where`, `eval`, `fields`, `rename`, `sort`, `head`/`limit`, `fillnull`,
`stats` (count, sum, avg, min, max, dc) with GROUP BY,
`rare`, `top` (GROUP BY + ORDER BY + LIMIT),
`join`, `lookup` (standard SQL JOINs)

### Tier 2: Window Function Translation

Commands requiring SQL window functions:
- `dedup` -> ROW_NUMBER() OVER (PARTITION BY keys ORDER BY ...) + WHERE rn = 1
- `eventstats` -> aggregate OVER (PARTITION BY ...) without collapsing rows
- `trendline` -> moving average via windowed AVG/SUM with ROWS BETWEEN

**Performance note:** Window functions require full data materialization in Trino
(cannot be pushed to Lucene). Only beneficial on LARGE datasets.

### Tier 3: Complex Translation

Commands needing creative SQL mapping:
- `expand`/`flatten` -> CROSS JOIN UNNEST for array fields
- `parse`/`grok`/`rex` -> regexp_extract() in Trino, may need UDF for grok patterns
- `patterns` -> Custom Trino UDF or fallback to local execution
- `fieldsummary` -> Wide aggregation (COUNT, MIN, MAX, AVG, DISTINCT per column)
- `append` -> UNION ALL of independently translated subqueries

## 6 Per-Command Workflow

For EACH PPL command:

1. **Verify RelNode**: Check CalciteRelNodeVisitor handles it correctly
2. **Generate SQL**: Run through UnifiedQueryTranspiler with TrinoSqlDialect
3. **Validate SQL**: Confirm Trino SQL is syntactically and semantically valid
4. **Test**: Round-trip test (PPL -> Trino SQL -> execute -> compare with single-node)
5. **Benchmark**: Run at 1K, 100K, 1M docs; record single-node vs Trino times
6. **Gate**: If Trino path > 2x slower, command must fall back to local execution

## 7 Trino SQL Considerations

- Trino uses double-quotes for identifiers (not backticks)
- Trino-specific syntax: UNNEST, ROW_NUMBER(), regexp_extract()
- Map OpenSearch types: text/keyword -> VARCHAR, nested -> ROW/ARRAY, date -> TIMESTAMP
- Generate optimizer-friendly SQL (avoid unnecessary subqueries)
- Use parameterized queries where possible
- Trino does NOT support all SQL features equally -- check Trino docs for limitations

## 8 Fallback Strategy

Commands that cannot be translated to valid Trino SQL:
- Execute on the existing single-node engine (no regression)
- Log a warning indicating the command prevented distributed execution
- Configure via `plugins.ppl.distributed.fallback.commands`
- Track fallback commands for future Trino UDF development

## 9 References

- `references/trino-sql-dialect.md`
- `references/ppl-relnode-mapping.md`
- Parent skill: `.claude/skills/distributed-ppl/references/ppl-command-matrix.md`
- Parent skill: `.claude/skills/distributed-ppl/references/performance-requirements.md`
