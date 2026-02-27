# Optimization Proposal: [Title]

**Author:** [name]
**Date:** [date]
**Focus:** [PPL Rule Optimization | Calcite Optimization]

## Executive Summary

[1-2 sentence summary of the proposed optimization and expected impact]

## Bottleneck Analysis

### Bottleneck 1: [Name]

- **Location:** `file/path.java:line`
- **Current behavior:** [What it does now]
- **Time contribution:** [Measured or estimated time in ms]
- **Evidence:** [How you determined this -- profiling data, code analysis, etc.]

### Bottleneck 2: [Name]

[Same structure]

## Proposed Optimizations

### Optimization 1: [Name]

- **Target bottleneck:** [Which bottleneck this addresses]
- **Approach:** [Technical description of the change]
- **Expected time reduction:** [ms saved, with justification]
- **Files to modify:**
  - `path/to/file1.java` - [what changes]
  - `path/to/file2.java` - [what changes]
- **Risk:** [Low/Medium/High] - [Why]
- **Regression risk:** [What could break]

### Optimization 2: [Name]

[Same structure]

## Combined Impact Estimate

| Optimization | Time Saved (ms) | Confidence |
|-------------|----------------|------------|
| Opt 1       | X.X            | High/Med/Low |
| Opt 2       | X.X            | High/Med/Low |
| **Total**   | **X.X**        |            |

**Baseline optimize time:** ~13-15ms
**Target optimize time:** ~6-7ms (50% reduction)
**Projected optimize time:** X.X ms

## Dependencies and Ordering

[If optimizations should be applied in a specific order, explain why]

## Alternatives Considered

[Other approaches you evaluated and why you chose the proposed approach]

## Open Questions

- [Any uncertainties that need to be resolved before implementation]
