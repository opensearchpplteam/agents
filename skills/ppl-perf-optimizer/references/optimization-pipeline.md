# PPL Query Optimization Pipeline Reference

## Pipeline Overview

The PPL query execution follows four phases, timed via the profiling infrastructure:

```
Parse → ANALYZE → OPTIMIZE → EXECUTE → FORMAT
```

### Entry Point

**File**: `core/src/main/java/org/opensearch/sql/executor/QueryService.java`

Method `executeWithCalcite()` orchestrates the full pipeline. Each phase is timed
via `ProfileContext` and reported in the `profile` response.

## Phase 1: ANALYZE (4-5ms typical)

Converts the PPL AST into a Calcite RelNode tree.

**Key classes**:
- `CalcitePlanContext` (`core/.../calcite/CalcitePlanContext.java`): Manages Calcite
  framework config, RelBuilder, RexBuilder, connection pooling, lambda/subquery state.
- `CalciteRelNodeVisitor` (`core/.../calcite/CalciteRelNodeVisitor.java`, ~158KB):
  Visits each PPL AST node and produces equivalent Calcite RelNodes.
- `CalciteRexNodeVisitor` (`core/.../calcite/CalciteRexNodeVisitor.java`):
  Converts PPL expressions to Calcite RexNodes.

**What happens**:
1. `CalcitePlanContext.create()` builds framework config, schema, type factory
2. `analyze(plan, context)` walks the PPL AST
3. `convertToCalcitePlan(relNode, context)` finalizes the RelNode tree
4. Timing recorded via `profileContext.getOrCreateMetric(MetricName.ANALYZE)`

## Phase 2: OPTIMIZE (13-15ms typical -- THE BOTTLENECK)

Two-stage optimization, followed by connection/runner setup.

### Stage 1: HepPlanner (Heuristic)

**File**: `core/.../calcite/utils/CalciteToolsHelper.java:448-460`

```java
HepProgram hepProgram = HepProgram.builder()
    .addRuleInstance(FilterMergeRule.Config.DEFAULT.toRule())
    .addRuleInstance(PPLSimplifyDedupRule.Config.DEFAULT.toRule())
    .build();
HepPlanner hepPlanner = new HepPlanner(hepProgram);
hepPlanner.setRoot(rel);
rel = hepPlanner.findBestExp();
```

Only two rules: FilterMergeRule and PPLSimplifyDedupRule. Quick but still has
overhead from planner setup and tree traversal.

### Stage 2: VolcanoPlanner (Cost-Based) + PrepareStatement

**File**: `core/.../calcite/utils/CalciteToolsHelper.java:405-430`

```java
rel = CalciteToolsHelper.optimize(rel, context);  // HepPlanner
try (Connection connection = context.connection) {
    final RelRunner runner = connection.unwrap(RelRunner.class);
    PreparedStatement preparedStatement = runner.prepareStatement(rel);
    // ^^^ THIS is where VolcanoPlanner runs and most time is spent
    return preparedStatement;
}
```

`runner.prepareStatement(rel)` triggers:
1. VolcanoPlanner with the full Calcite rule set
2. Cost model evaluation for all rule applications
3. Physical plan generation (EnumerableRel conversion)
4. Schema validation and type checking

### Custom Calcite Rules

Directory: `core/.../calcite/plan/rule/`
- `PPLAggregateConvertRule.java` - Aggregation conversion
- `PPLAggGroupMergeRule.java` - Aggregation group merging
- `PPLDedupConvertRule.java` - Dedup handling
- `PPLSimplifyDedupRule.java` - Dedup simplification

### Legacy LogicalPlan Optimizer

**File**: `core/.../planner/optimizer/LogicalPlanOptimizer.java`

Top-down optimizer with two rule phases:
1. Relational algebra transformations (MergeFilterAndFilter, PushFilterUnderSort, etc.)
2. Data source push-down (filter, aggregation, sort, limit, highlight, nested, project)

This may run in addition to or instead of the Calcite optimizer depending on
the query path. Potential source of duplicate optimization work.

## Phase 3: EXECUTE (4-5ms typical)

**File**: `opensearch/.../executor/OpenSearchExecutionEngine.java`

Executes the optimized plan via `statement.executeQuery()`, converts JDBC
ResultSet to QueryResponse.

## Phase 4: FORMAT (<0.1ms typical)

Serializes the QueryResponse to the output format.

## Profiling Infrastructure

### Metric Collection

- `MetricName` enum: ANALYZE, OPTIMIZE, EXECUTE, FORMAT
- `DefaultProfileContext`: ConcurrentHashMap of metrics, nanosecond precision
- `QueryProfile`: Output model with summary.total_time_ms and per-phase times

### Plan-Level Profiling

- `ProfileEnumerableRel`: Wraps each Enumerable node with timing
- `ProfileScannableRel`: Wraps scan nodes with timing
- `PlanProfileBuilder`: Recursively instruments the plan tree

## Directory Map

```
core/src/main/java/org/opensearch/sql/
  calcite/
    CalcitePlanContext.java          # Context: connection, schema, builder
    CalciteRelNodeVisitor.java       # PPL AST → RelNode
    CalciteRexNodeVisitor.java       # PPL expr → RexNode
    utils/
      CalciteToolsHelper.java        # HepPlanner + VolcanoPlanner entry
    plan/
      rel/                           # Custom RelNode implementations
      rule/                          # Custom Calcite optimization rules
    profile/
      PlanProfileBuilder.java        # Plan tree instrumentation
      ProfileEnumerableRel.java      # Per-node timing wrapper
      ProfileScannableRel.java       # Scan node timing wrapper
  planner/
    Planner.java                     # Plan entry point
    optimizer/
      LogicalPlanOptimizer.java      # Top-down rule optimizer
      Rule.java                      # Rule interface
      rule/
        EvalPushDown.java            # Limit push-down
        MergeFilterAndFilter.java    # Filter merging
        PushFilterUnderSort.java     # Filter reordering
        read/
          CreateTableScanBuilder.java
          TableScanPushDown.java     # Multiple push-down variants
  executor/
    QueryService.java                # Main pipeline orchestrator
  monitor/profile/
    MetricName.java                  # Phase enum
    DefaultProfileContext.java       # Timing collection
    QueryProfile.java                # Output model

opensearch/src/main/java/org/opensearch/sql/opensearch/
  executor/
    OpenSearchExecutionEngine.java   # Execution engine
```
