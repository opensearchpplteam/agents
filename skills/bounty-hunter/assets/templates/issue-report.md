## Query Information
**PPL Command/Query:**
```ppl
# The PPL query that triggered the bug
```

**Expected Result:**
<!-- What the grammar/documentation says should happen -->

**Actual Result:**
<!-- What actually happened, with full API response -->

## Reproduction Commands

**1. Create index with mapping:**
```bash
curl --request PUT \
  --url http://localhost:9200/{index-name} \
  --header 'content-type: application/json' \
  --data '{
  "mappings": {
    "properties": {
      "field_name": { "type": "type" }
    }
  }
}'
```

**2. Insert sample data:**
```bash
curl --request POST \
  --url http://localhost:9200/{index-name}/_bulk \
  --header 'content-type: application/x-ndjson' \
  --data '{"index": { "_id": 1 }}
{"field_name": "value1"}
{"index": { "_id": 2 }}
{"field_name": "value2"}
'
```

**3. Run the PPL query:**
```bash
curl --request POST \
  --url http://localhost:9200/_plugins/_ppl \
  --header 'content-type: application/json' \
  --data '{"query": "source={index-name} | ..."}'
```

## Dataset Information
**Dataset/Schema Type**
- [ ] OpenTelemetry (OTEL)
- [ ] Simple Schema for Observability (SS4O)
- [ ] Open Cybersecurity Schema Framework (OCSF)
- [ ] Custom (details below)

## Bug Description
**Issue Summary:**
<!-- One-line description -->

**Root Cause Analysis:**
<!-- Developer's RCA: file:line, code path, why it's wrong -->

**Steps to Reproduce:**
1. Create index with mapping (curl #1 above)
2. Insert sample data (curl #2 above)
3. Run the PPL query (curl #3 above)
4. Observe the result

**Severity:** [Critical/High/Medium/Low]
**Category:** [Bug/Performance/Security/DocIssue]
**PPL Commands Affected:** [list of commands]
**Confirmed by:** [developer agent name]
**Environment:** OpenSearch + SQL Plugin (main branch, Calcite enabled)
