# Calcite Optimization Reference

## Overview

Apache Calcite provides two planners used by OpenSearch PPL:

1. **HepPlanner** (Heuristic): Applies rules in a fixed order without cost evaluation.
   Fast but limited.
2. **VolcanoPlanner** (Cost-Based): Explores a search space of equivalent plans,
   evaluates cost for each, and picks the cheapest. Powerful but expensive.

## HepPlanner in PPL

**File**: `core/.../calcite/utils/CalciteToolsHelper.java`

Currently uses only two rules:
- `FilterMergeRule`: Merges adjacent LogicalFilter nodes
- `PPLSimplifyDedupRule`: Simplifies dedup patterns

### Optimization Opportunities

1. **Skip for simple plans**: If the RelNode tree has no consecutive filters and no
   dedup, the HepPlanner does nothing useful but still has setup overhead.
2. **Rule applicability check**: Could short-circuit by checking if any rule's pattern
   matches before creating the planner.
3. **Combine with VolcanoPlanner**: These rules could be added to the VolcanoPlanner's
   rule set instead of running a separate planning phase.

## VolcanoPlanner in PPL

Triggered by `runner.prepareStatement(rel)` inside `CalciteToolsHelper`.

### What prepareStatement Does

1. Creates a new VolcanoPlanner instance
2. Registers the full set of Calcite built-in rules + custom PPL rules
3. Sets the initial RelNode as the root
4. Explores the search space by applying rules and computing costs
5. Selects the cheapest physical plan
6. Converts to EnumerableRel (executable plan)

### Where Time Goes

1. **Rule registration**: Default Calcite includes 100+ rules. Many are irrelevant
   for PPL query patterns (e.g., materialized view rules, semi-join rules).
2. **Search space explosion**: Even simple plans can have many equivalent transformations.
3. **Cost computation**: Each alternative plan node computes its cost via the cost model.
4. **Physical conversion**: Converting logical to enumerable requires trait propagation.

### Optimization Opportunities

1. **Custom rule set**: Register only rules relevant to PPL patterns. Remove rules
   for features PPL does not use (materialized views, semi-joins, spatial, etc.).
2. **Plan complexity threshold**: For simple plans (< N nodes), skip VolcanoPlanner
   entirely and use HepPlanner with a larger rule set.
3. **Planner caching**: Cache the VolcanoPlanner configuration (but not the plan
   itself) across queries to avoid re-registration overhead.
4. **Trait simplification**: If PPL only needs enumerable convention, simplify the
   trait propagation.

## CalcitePlanContext Overhead

**File**: `core/.../calcite/CalcitePlanContext.java`

Created per query via `CalcitePlanContext.create()`. This involves:
1. Building FrameworkConfig with schema, programs, and traits
2. Creating a JDBC connection via CalciteConnectionFactory
3. Initializing RelBuilder and RexBuilder
4. Setting up type factory and operator table

### Optimization Opportunities

1. **Connection pooling**: Reuse JDBC connections across queries instead of
   creating/closing per query.
2. **FrameworkConfig caching**: Cache the FrameworkConfig when the schema has not changed.
3. **Type factory singleton**: TypeFactory is stateless and can be shared.
4. **Lazy initialization**: Some components (RelBuilder, RexBuilder) could be lazily
   initialized if not needed for all query types.

## Custom PPL Rules

### PPLAggregateConvertRule
Converts PPL aggregation patterns to standard Calcite LogicalAggregate.
Essential for correct semantics -- cannot be removed.

### PPLAggGroupMergeRule
Merges consecutive aggregation groups. Only fires when the plan has adjacent
aggregate nodes. Could be skipped if the plan structure makes this impossible.

### PPLDedupConvertRule
Converts PPL dedup to Calcite equivalents. Only relevant for queries with dedup.

### PPLSimplifyDedupRule
Simplifies dedup patterns that can be reduced to simpler operations.
Currently in HepPlanner; could be moved to VolcanoPlanner.

## Profiling the Optimize Phase

To determine where time is spent within the optimize phase, consider adding
fine-grained timing around:

1. `HepPlanner` creation and execution
2. `connection.unwrap(RelRunner.class)` call
3. `runner.prepareStatement(rel)` call
4. Within prepareStatement: rule application vs cost computation vs physical conversion

This data will be critical for making informed optimization decisions.

## Common Calcite Performance Patterns

### Pattern: Rule Set Pruning
Only register rules that can fire for the given query shape. Use the RelNode
tree structure to determine which rule categories are relevant.

### Pattern: Two-Phase Planning
Use HepPlanner for guaranteed-beneficial rewrites (filter pushdown, projection
pruning), then use VolcanoPlanner only if cost-based decisions are needed.

### Pattern: Plan Caching
For identical or structurally similar queries, cache the optimized plan shape
and re-instantiate with new parameters. Requires plan normalization.

### Pattern: Planner Configuration Reuse
Separate planner configuration (rules, traits, cost model) from per-query state.
Cache the configuration and create lightweight per-query instances.
