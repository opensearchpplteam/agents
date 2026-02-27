---
name: distributed-ppl-phase1
description: >
  Architecture decision-making for the distributed PPL engine. Evaluates blocking
  decisions: Calcite role (IR vs optimizer vs skip), Trino-Lucene connector strategy
  (A-D), Trino integration depth (Levels 1-5), and PPL command coverage matrix.
  Produces written decision documents with tradeoff analysis. All decisions BLOCK
  implementation phases.
---

# Distributed PPL: Phase 1 Architecture Decisions

## 1 Mission

You are the **project lead** evaluating critical design decisions for the distributed
PPL query engine. Each decision BLOCKS implementation. Produce written decision
documents with clear tradeoff analysis supported by evidence from the codebase.

**Output directory:** `~/oss/ppl/distributed-ppl/phase1/`

## 2 Team Structure

Spawn **one teammate** for parallel evaluation:

| Agent | Role | Focus | Subagent Type |
|-------|------|-------|---------------|
| `infra-architect` | Trino infrastructure architect | Decisions 1.2, 1.3, 1.5 | general-purpose |

The lead evaluates decisions 1.1 (Calcite role) and 1.4 (command coverage).
The infra-architect evaluates 1.2 (connector strategy), 1.3 (integration depth), and 1.5 (connectivity architecture).

Both write their documents independently. Lead reviews infra-architect's deliverables.
**No co-authorship** -- sole author + review is faster than iterative co-writing.

### Spawn Prompt: infra-architect

```
You are "infra-architect" on the distributed-ppl-phase1 team. You evaluate Trino
infrastructure decisions for the distributed PPL query engine project.

YOUR DELIVERABLES:
1. Decision 1.2: Trino-Lucene Connector Strategy (Strategy A/B/C/D)
2. Decision 1.3: Trino Integration Depth (Level 1-5)
3. Decision 1.5: Trino Connectivity Architecture

For each decision:
- Read the evaluation guide in references/
- Study the Trino OpenSearch connector (external repo: trinodb/trino, plugin/trino-opensearch)
- Analyze tradeoffs against the performance requirements
- Write decision document to ~/oss/ppl/distributed-ppl/phase1/

IMPORTANT CORRECTION: Trino does NOT use Calcite internally. It has its own IR
(PlanNode), optimizer, and type system. Do not assume RelNode-to-PlanNode conversion
is straightforward.

IMPORTANT: Connector work involves a DIFFERENT repository (trinodb/trino). Your
evaluation should identify what can be done in this repo vs what requires Trino
connector modification.

Key reference files to read:
- .claude/skills/distributed-ppl/references/trino-connector-strategies.md
- .claude/skills/distributed-ppl/references/trino-integration-levels.md
- .claude/skills/distributed-ppl/references/performance-requirements.md
- .claude/skills/distributed-ppl/references/architecture-context.md

Write decisions to files:
- ~/oss/ppl/distributed-ppl/phase1/decision-1.2-connector-strategy.md
- ~/oss/ppl/distributed-ppl/phase1/decision-1.3-integration-depth.md
- ~/oss/ppl/distributed-ppl/phase1/decision-1.5-connectivity-architecture.md

Use the strategy evaluation template from assets/templates/strategy-evaluation.md.
Send a summary message to team-lead when done.
```

## 3 Decision 1.1: Calcite Role

### Context

The codebase **already uses Calcite extensively** as an IR:
- `CalciteRelNodeVisitor`: 3,743 lines, 45+ visitor methods
- `UnifiedQueryTranspiler`: Uses RelToSqlConverter with configurable SqlDialect
- `OpenSearchSparkSqlDialect`: Demonstrates custom dialect pattern
- 55 dedicated Calcite PPL test files

This decision is therefore NOT "should we use Calcite?" but rather **"how should we extend the existing Calcite infrastructure for Trino?"**

### Options to Evaluate

| Option | Description | Key Question |
|--------|-------------|--------------|
| A | Calcite as IR only | Use existing RelNode pipeline + add TrinoSqlDialect. Minimal Calcite optimizer usage. |
| B | Calcite optimizer + IR | Run Calcite optimization rules before generating Trino SQL. Trino also optimizes -- double-opt worth it? |
| C | Skip Calcite, direct AST->SQL | Abandon existing Calcite infrastructure. Simpler but discards 3,743 lines of working code. |

### Investigation Required

Study these files:
- `core/src/main/java/org/opensearch/sql/calcite/CalciteRelNodeVisitor.java`
- `core/src/main/java/org/opensearch/sql/calcite/CalcitePlanContext.java`
- `api/src/main/java/org/opensearch/sql/api/transpiler/UnifiedQueryTranspiler.java`
- `api/src/main/java/org/opensearch/sql/api/UnifiedQueryPlanner.java`
- `ppl/src/main/java/org/opensearch/sql/ppl/calcite/OpenSearchSparkSqlDialect.java`
- `core/src/main/java/org/opensearch/sql/calcite/plan/rule/` (existing optimization rules)
- `core/src/main/java/org/opensearch/sql/planner/optimizer/LogicalPlanOptimizer.java`

Answer:
1. How much PPL -> RelNode coverage exists today? What gaps remain for Trino?
2. Does the existing RelToSqlConverter handle all RelNode types produced by CalciteRelNodeVisitor?
3. Would Calcite optimization be redundant with Trino's cost-based optimizer?
4. What is the maintenance cost of Calcite rules vs the value they provide?
5. For PPL-specific semantics (dedup, eventstats, patterns) -- how are they currently handled in RelNode?

### Deliverable

Write to: `~/oss/ppl/distributed-ppl/phase1/decision-1.1-calcite-role.md`

## 4 Decision 1.4: PPL Command Coverage

Classify every PPL command by Trino SQL translatability.

### Starting Point

Read `distributed-ppl/references/ppl-command-matrix.md` for the initial matrix. Then **audit CalciteRelNodeVisitor.java** to find ALL visitor methods and verify coverage. The reference matrix has 18 commands but the visitor handles 45+ node types.

For each command determine:
- Trino SQL equivalent and translation complexity
- Lucene pushdown potential (can the connector push this to Lucene?)
- Network cost if NOT pushed down
- Expected perf: faster/same/slower than single-node?
- Recommended execution venue: Lucene-native / Trino / Hybrid / Fallback

### Deliverable

Write to: `~/oss/ppl/distributed-ppl/phase1/decision-1.4-command-coverage.md`

## 5 Parallelism Note

Decisions 1.2 (connector strategy) and 1.3 (integration depth) do NOT depend on
decision 1.1 (Calcite role). The connector strategy evaluates how Trino talks to
Lucene -- independent of how PPL maps to RelNode. Start 1.2/1.3 immediately.

Decision 1.1 blocks Phases 2.1/2.2 (PPL translation).
Decision 1.2 blocks Phase 2.4 (connector enhancement).
Decision 1.3 blocks Phase 2.3 (execution bridge).

## 6 Exit Criteria

Phase 1 is COMPLETE when:
- [ ] Decision 1.1 written with chosen option and rationale
- [ ] Decision 1.2 written with chosen strategy
- [ ] Decision 1.3 written with chosen level and overhead analysis
- [ ] Decision 1.4 written with complete command coverage matrix
- [ ] Decision 1.5 written with connectivity architecture
- [ ] Lead has reviewed all documents

## 7 Output Format

Each decision document must include:
1. **Options evaluated** with pros/cons
2. **Evidence from codebase** (file:line references)
3. **Chosen option** with rationale
4. **Risks** and mitigation plan
5. **Impact** on subsequent phases
6. **Performance implications** against gates in `performance-requirements.md`

## 8 References

- `references/calcite-evaluation-guide.md`
- `references/connector-evaluation-guide.md`
- Parent skill: `.claude/skills/distributed-ppl/references/` (all reference files)
