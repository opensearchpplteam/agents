#!/usr/bin/env bash
# Create an issue report file from template.
# Usage: ./file-issue.sh <issue-id> <category> <title>
# Example: ./file-issue.sh 001 bug "Stats avg returns null for non-null group"
set -euo pipefail

ISSUE_ID="${1:?Usage: file-issue.sh <id> <category> <title>}"
CATEGORY="${2:?Category required: bug, performance, security}"
TITLE="${3:?Title required}"

OUTPUT_DIR="$HOME/oss/ppl/bounty-hunter"
DATETIME=$(date +%Y-%m-%d-%H%M%S)
FILENAME="issue-${ISSUE_ID}-${DATETIME}.md"
FILEPATH="$OUTPUT_DIR/$FILENAME"

mkdir -p "$OUTPUT_DIR"

CATEGORY_UPPER=$(echo "$CATEGORY" | tr '[:lower:]' '[:upper:]')

cat > "$FILEPATH" <<TEMPLATE
# Issue ${ISSUE_ID}: ${TITLE}

**Category:** ${CATEGORY_UPPER}
**Date:** $(date +%Y-%m-%d)
**Found by:** PPL Bounty Hunter

---

## Query Information
**PPL Command/Query:**
\`\`\`ppl
# Paste your PPL command or query here
# Remember to sanitize any sensitive fields or values
\`\`\`

**Expected Result:**
<!-- Describe what you expected to happen -->

**Actual Result:**
<!-- Describe what actually happened, including any error messages -->
<!-- Make sure to redact any sensitive information in error messages -->

## Reproduction Commands

**1. Create index with mapping:**
\`\`\`bash
curl --request PUT \\
  --url http://localhost:9200/{index-name} \\
  --header 'content-type: application/json' \\
  --data '{
  "mappings": {
    "properties": {
      "field_name": { "type": "type" }
    }
  }
}'
\`\`\`

**2. Insert sample data:**
\`\`\`bash
curl --request POST \\
  --url http://localhost:9200/{index-name}/_bulk \\
  --header 'content-type: application/x-ndjson' \\
  --data '{"index": { "_id": 1 }}
{"field_name": "value1"}
{"index": { "_id": 2 }}
{"field_name": "value2"}
'
\`\`\`

**3. Run the PPL query:**
\`\`\`bash
curl --request POST \\
  --url http://localhost:9200/_plugins/_ppl \\
  --header 'content-type: application/json' \\
  --data '{"query": "source={index-name} | ..."}'
\`\`\`

## Dataset Information
**Dataset/Schema Type**
- [ ] OpenTelemetry (OTEL)
- [ ] Simple Schema for Observability (SS4O)
- [ ] Open Cybersecurity Schema Framework (OCSF)
- [ ] Custom (details below)

## Bug Description
**Issue Summary:**
<!-- A clear and concise description of what the bug is -->

**Root Cause Analysis:**
<!-- Developer's RCA: file:line, code path, why it's wrong -->

**Steps to Reproduce:**
1. Create index with mapping (curl #1 above)
2. Insert sample data (curl #2 above)
3. Run the PPL query (curl #3 above)
4. Observe the result

**Severity:** [Critical/High/Medium/Low]
**Category:** ${CATEGORY_UPPER}
**PPL Commands Affected:** [list commands]
**Confirmed by:** [developer agent name]
**Environment:** OpenSearch + SQL Plugin (main branch, Calcite enabled)

## Explain API Output
\`\`\`json
// Paste _explain output here
\`\`\`

## Execute API Output
\`\`\`json
// Paste _ppl output here
\`\`\`

## Analysis
<!-- Developer's root cause analysis -->
<!-- Reference to relevant source files: file:line -->

## Suggested Fix
<!-- Optional: developer's suggestion for how to fix this -->
TEMPLATE

echo "Created: $FILEPATH"
