# Benchmark Protocol: Single-Agent vs Subagent PR Review

Use this protocol to compare current skill behavior against subagent orchestration.

## Goal
Measure whether subagent orchestration improves review quality without unacceptable latency/cost.

## Dataset
- Use 20 to 40 historical PRs from `opensearch-project/sql`.
- Include mixed sizes and domains: parser/planner/runtime/tests/docs.
- Include known tricky cases: pushdown, PIT/pagination, permissions, nested fields, snapshots.
- Keep a fixed benchmark set for every run.

## Ground Truth
- Build a reference set per PR from:
1. merged review comments
2. post-merge fixes/reverts
3. maintainer adjudication
- Label each true issue with severity and area.

## Experiment Design
- Run two modes on the same PR set:
1. `single-agent`
2. `subagent-orchestrated`
- Run each mode 3 times per PR to capture variance.
- Randomize run order to reduce sequence bias.

## Required Metrics
- `major_plus_recall`: recall on blocker/major true issues.
- `precision`: fraction of reported findings that are true.
- `integration_gap_recall`: recall for missing `integ-test`/`yamlRestTest` gaps on behavior-changing PRs.
- `subagent_coverage`: fraction of required aspects with successful subagent output (target 4/4), regardless of agent name.
- `false_blocker_rate`: proportion of blocker findings rejected by maintainers.
- `latency_sec`: end-to-end review time.
- `token_or_cost`: total usage proxy.
- `format_compliance`: pass/fail against required output template.

## Pass/Fail Criteria (example)
- `major_plus_recall` improves by at least 10%.
- `precision` does not drop by more than 5%.
- `integration_gap_recall` is at least 95%.
- `subagent_coverage` is 100%.
- `latency_sec` increase is less than 25%.
- `format_compliance` is 100%.

## Logging Schema
Log one row per run with:
- `pr_number`
- `mode`
- `run_id`
- `findings_count`
- `major_plus_recall`
- `precision`
- `integration_gap_recall`
- `subagent_coverage`
- `false_blocker_rate`
- `latency_sec`
- `token_or_cost`
- `format_compliance`

## Analysis
- Compare paired metrics per PR (`single-agent` vs `subagent`).
- Report mean, median, and p90 for latency and quality metrics.
- Use paired non-parametric comparison for quality deltas.
- Include top 5 disagreement cases with short root-cause notes.

## Decision Rule
- Adopt subagent mode only if quality gains are consistent and latency/cost remain within thresholds.
- Otherwise keep single-agent as default and enable subagent mode only for large or multi-domain PRs.
