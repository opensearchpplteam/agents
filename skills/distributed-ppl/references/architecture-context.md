# Current PPL Architecture Context

## Execution Pipeline (Today)

The OpenSearch PPL plugin executes entirely on a single coordinating node:

```
PPL text -> ANTLR Parser -> AST -> Analyzer -> LogicalPlan -> Planner
-> PhysicalPlan -> OpenSearchExecutionEngine (single-node, in-memory)
```

## Key Components

| Component | Location | Purpose |
|-----------|----------|---------|
| RestPPLQueryAction | `plugin/src/.../rest/` | REST entry point |
| TransportPPLQueryAction | `plugin/src/.../transport/` | Transport entry point |
| PPLService.execute() | `ppl/src/.../PPLService.java` | Main orchestrator |
| AstBuilder | `ppl/src/.../parser/AstBuilder.java` | ANTLR parse tree -> AST |
| Analyzer | `core/src/.../analysis/Analyzer.java` | Type checking, symbol resolution |
| CalciteRelNodeVisitor | `core/src/.../calcite/CalciteRelNodeVisitor.java` | AST -> Calcite RelNode (3,743 lines, 45+ visitors) |
| CalcitePlanContext | `core/src/.../calcite/CalcitePlanContext.java` | Manages RelBuilder, RexBuilder, framework config |
| UnifiedQueryTranspiler | `api/src/.../transpiler/UnifiedQueryTranspiler.java` | RelNode -> SQL via RelToSqlConverter |
| UnifiedQueryPlanner | `api/src/.../UnifiedQueryPlanner.java` | Full PPL -> RelNode pipeline |
| OpenSearchSparkSqlDialect | `ppl/src/.../calcite/OpenSearchSparkSqlDialect.java` | Custom SQL dialect pattern |
| Planner | `core/src/.../planner/Planner.java` | LogicalPlan -> PhysicalPlan |
| OpenSearchExecutionEngine | `opensearch/src/...` | Runs PhysicalPlan operators in JVM heap |
| TableScanBuilder | `opensearch/src/...` | Pushdown interface (filter/agg/sort/limit/project) |

## Existing Calcite Integration (EXTENSIVE)

The Calcite integration is NOT partial -- it is extensive:

- `CalciteRelNodeVisitor`: 45+ visitor methods covering source, where, eval, fields, rename,
  sort, head, stats, dedup, join, lookup, parse, grok, patterns, expand, flatten, eventstats,
  trendline, fillnull, append, and more
- Custom type system: `ExprSqlType`, `ExprDateType`, `ExprIPType`, etc. (8 classes)
- UDFs: `UserDefinedFunction`, `UserDefinedAggFunction`, 8+ aggregate implementations
- Plan utilities: `PlanUtils`, `SubsearchUtils`, `JoinAndLookupUtils`
- Optimization rules: `PPLDedupConvertRule`, `PPLAggGroupMergeRule`, `OpenSearchRules`
- Schema: `OpenSearchTypeFactory`, `OpenSearchSchema`
- 55 dedicated test files in `ppl/src/test/.../calcite/`

## Underlying Storage

- OpenSearch indices backed by Apache Lucene
- Lucene provides: inverted indices, doc-value columns, BKD trees, native aggregation
- Current OpenSearch connector in Trino has LIMITED pushdown (basic filter only)

## Limitations Driving This Project

- All operators above pushed-down scan execute on single node
- No distributed shuffle, exchange, or partition-aware execution
- Joins, large aggregations, sorts on big datasets bottleneck coordinator
- No way to leverage external distributed runtimes like Trino
