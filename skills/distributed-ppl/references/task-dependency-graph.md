# Task Dependency Graph

## Optimized Dependencies

```
Phase 1 (2 agents: lead + infra-architect)
├── lead: 1.1 (Calcite decision) + 1.4 (command coverage)
│   [lead writes decision doc directly, no co-authorship delay]
│
└── infra-architect: 1.2 + 1.3 + 1.5  (runs in PARALLEL with 1.1)
    [connector strategy does NOT depend on Calcite decision]
    [all Trino infrastructure decisions in one agent]
    │
    ↓
    lead reviews infra-architect's deliverables
    infra-architect shuts down
    │
Phase 2 (3 agents: lead + ppl-translator + trino-integrator)
├── ppl-translator: 2.1 → 2.2 → starts 3.1 Tier 1  [BLOCKED BY 1.1]
│   [sequential within one agent, no coordination delay]
│   [starts Tier 1 commands as soon as translation pipeline works]
│
└── trino-integrator: 2.3 + 2.4 in parallel        [BLOCKED BY 1.2, 1.3]
    [execution bridge and connector built together]
    │
    ├── As Tier 1 commands complete:
    │   ppl-translator runs trino-sql-verifier
    │   trino-integrator runs connector-pushdown-verifier
    │   [incremental testing, no QA agent needed yet]
    │
Phase 3 (3 agents: lead + ppl-translator + qa-validator)
├── ppl-translator: 3.2 (Tier 2) → 3.3 (Tier 3) → 3.4 (fallback)
│   [same agent continues command migration]
│
└── qa-validator: 4.1-4.5 (all testing)
    [starts with Tier 1 validation while translator does Tier 2]
    [runs benchmarks using benchmark-runner pattern]
    │
Phase 5 (1-2 agents: lead + optional helper)
└── lead: configuration, explain, observability
```

## Blocking Dependencies (strict)

| Phase | Blocked By | Reason |
|-------|-----------|--------|
| 2.1 (PPL->RelNode) | 1.1 (Calcite decision) | Need to know Calcite's role |
| 2.2 (RelNode->SQL) | 2.1 | Need RelNode pipeline first |
| 2.3 (Execution bridge) | 1.3 (Integration depth) | Bridge shape depends on level |
| 2.4 (Connector) | 1.2 (Connector strategy) | Implementation depends on strategy |
| 3.x (Migration) | 2.1 + 2.2 + 2.3 + 2.4 | Need working pipeline |
| 4.x (Testing) | 3.x produces testable artifacts | Need running code to test |
| 5.x (Ops) | 4.x validates correctness | Must be correct before shipping |

## Non-Blocking (can run in parallel)

| Phases | Why Independent |
|--------|----------------|
| 1.1 and 1.2 | Calcite role vs connector strategy are different concerns |
| 1.1 and 1.3 | Calcite role vs Trino integration depth are different concerns |
| 1.2 and 1.3 | Connector strategy and integration depth are related but evaluable in parallel |
| 2.1/2.2 and 2.3/2.4 | PPL translation and Trino infrastructure are different codebases |
| 3.x and 4.x | QA can start testing Tier 1 while translator does Tier 2 |

## Key Optimization: Start Tier 1 During Phase 2

The ppl-translator can begin Tier 1 command migration (source, where, eval, fields,
stats, sort, head) as soon as the basic translation pipeline works in Phase 2.1/2.2.
No need to wait for all of Phase 2 to complete.
