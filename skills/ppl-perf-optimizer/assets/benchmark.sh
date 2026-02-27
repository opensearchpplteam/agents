#!/usr/bin/env bash
# PPL Benchmark Script
# Runs warmup + measurement iterations for each query, computes stats, writes results.
#
# Usage:
#   bash benchmark.sh [output_dir]
#
# Options (env vars):
#   OPENSEARCH_URL  - OpenSearch endpoint (default: http://localhost:9200)
#   WARMUP          - Warmup iterations per query (default: 10)
#   RUNS            - Measurement iterations per query (default: 50)
#   INDEX           - Test index name (default: perf-test-001)
#
# Output:
#   <output_dir>/benchmark-<timestamp>.md   - Formatted results
#   <output_dir>/raw/Q<N>-optimize.csv      - Raw optimize times per query

set -euo pipefail

OPENSEARCH_URL="${OPENSEARCH_URL:-http://localhost:9200}"
WARMUP="${WARMUP:-10}"
RUNS="${RUNS:-50}"
INDEX="${INDEX:-perf-test-001}"
OUTPUT_DIR="${1:-$(pwd)}"
TIMESTAMP="$(date +%Y-%m-%d-%H%M%S)"
RAW_DIR="${OUTPUT_DIR}/raw"

mkdir -p "$RAW_DIR"

# --- Queries ---
declare -a QUERY_IDS=("Q1" "Q2" "Q3" "Q4" "Q5")
declare -a QUERY_LABELS=(
  "Simple projection"
  "Eval + sort + limit"
  "Filter + eval + sort"
  "Aggregation"
  "Multi-eval + filter + sort + limit"
)
declare -a QUERIES=(
  "source=${INDEX} | where value > 2.0 | where value > 1.0 | where value < 3.0 | fields id, name"
  "source=${INDEX} | eval a = rand() | sort a | fields id | head 5"
  "source=${INDEX} | where value > 2.0 | eval score = value * 100 | sort score"
  "source=${INDEX} | stats avg(value) as avg_val by name"
  "source=${INDEX} | eval a = value * 2, b = a + 1 | where b > 5 | sort b | head 3"
)

# --- Helpers ---
run_query() {
  local query="$1"
  curl -s -X POST "${OPENSEARCH_URL}/_plugins/_ppl/" \
    -H 'Content-Type: application/json' \
    -d "{\"profile\": true, \"query\": \"${query}\"}"
}

extract_phase() {
  local phase="$1"
  python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d['profile']['phases']['${phase}']['time_ms'])
except Exception as e:
    print(f'ERROR: {e}', file=sys.stderr)
    print(-1)
"
}

compute_stats() {
  local csv_file="$1"
  python3 -c "
import statistics, math
times = [float(l.strip()) for l in open('${csv_file}') if float(l.strip()) >= 0]
n = len(times)
if n == 0:
    print('ERROR: no valid measurements')
    exit(1)
s = sorted(times)
p90_idx = int(math.ceil(n * 0.9)) - 1
print(f'{min(s):.2f},{statistics.median(s):.2f},{statistics.mean(s):.2f},{s[p90_idx]:.2f},{max(s):.2f}')
"
}

# --- Preflight check ---
echo "=== PPL Benchmark ==="
echo "Endpoint: ${OPENSEARCH_URL}"
echo "Index:    ${INDEX}"
echo "Warmup:   ${WARMUP} iterations"
echo "Runs:     ${RUNS} iterations"
echo "Output:   ${OUTPUT_DIR}"
echo ""

HEALTH=$(curl -s "${OPENSEARCH_URL}/_cluster/health" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status','UNKNOWN'))" 2>/dev/null || echo "UNREACHABLE")
if [ "$HEALTH" = "UNREACHABLE" ]; then
  echo "ERROR: Cannot reach OpenSearch at ${OPENSEARCH_URL}"
  exit 1
fi
echo "Cluster health: ${HEALTH}"

# Check index exists
INDEX_EXISTS=$(curl -s -o /dev/null -w "%{http_code}" "${OPENSEARCH_URL}/${INDEX}")
if [ "$INDEX_EXISTS" != "200" ]; then
  echo "WARNING: Index '${INDEX}' does not exist. Creating with sample data..."
  curl -s -X PUT "${OPENSEARCH_URL}/${INDEX}" -H 'Content-Type: application/json' -d '{
    "mappings": {"properties": {"id": {"type": "integer"}, "name": {"type": "keyword"}, "value": {"type": "double"}, "ts": {"type": "date"}}}
  }' > /dev/null
  curl -s -X POST "${OPENSEARCH_URL}/${INDEX}/_bulk" -H 'Content-Type: application/x-ndjson' -d '
{"index":{"_id":"1"}}
{"id":1,"name":"Alice","value":3.14,"ts":"2024-01-01T00:00:00Z"}
{"index":{"_id":"2"}}
{"id":2,"name":"Bob","value":2.71,"ts":"2024-01-02T00:00:00Z"}
{"index":{"_id":"3"}}
{"id":3,"name":"Charlie","value":1.41,"ts":"2024-01-03T00:00:00Z"}
' > /dev/null
  curl -s -X POST "${OPENSEARCH_URL}/${INDEX}/_refresh" > /dev/null
  echo "Index '${INDEX}' created with 3 sample documents."
fi

echo ""

# --- Run benchmarks ---
declare -a SUMMARY_LINES=()

for i in "${!QUERY_IDS[@]}"; do
  qid="${QUERY_IDS[$i]}"
  query="${QUERIES[$i]}"
  label="${QUERY_LABELS[$i]}"
  csv_file="${RAW_DIR}/${qid}-optimize.csv"
  csv_all="${RAW_DIR}/${qid}-all-phases.csv"

  echo "--- ${qid}: ${label} ---"
  echo "Query: ${query}"

  # Warmup
  echo -n "Warmup (${WARMUP}): "
  for w in $(seq 1 "$WARMUP"); do
    run_query "$query" > /dev/null
    echo -n "."
  done
  echo " done"

  # Measurement
  echo -n "Measure (${RUNS}): "
  > "$csv_file"
  > "$csv_all"
  echo "run,analyze,optimize,execute,format,total" > "$csv_all"

  for r in $(seq 1 "$RUNS"); do
    response=$(run_query "$query")
    optimize_ms=$(echo "$response" | python3 -c "
import sys, json
d = json.load(sys.stdin)
p = d['profile']
phases = p['phases']
print(phases['optimize']['time_ms'])
" 2>/dev/null || echo "-1")

    all_phases=$(echo "$response" | python3 -c "
import sys, json
d = json.load(sys.stdin)
p = d['profile']
ph = p['phases']
total = p['summary']['total_time_ms']
print(f\"${r},{ph.get('analyze',{}).get('time_ms',0)},{ph['optimize']['time_ms']},{ph.get('execute',{}).get('time_ms',0)},{ph.get('format',{}).get('time_ms',0)},{total}\")
" 2>/dev/null || echo "${r},-1,-1,-1,-1,-1")

    echo "$optimize_ms" >> "$csv_file"
    echo "$all_phases" >> "$csv_all"

    if (( r % 10 == 0 )); then echo -n "."; fi
  done
  echo " done"

  # Stats
  stats=$(compute_stats "$csv_file")
  IFS=',' read -r smin smedian smean sp90 smax <<< "$stats"
  echo "  min=${smin}  median=${smedian}  mean=${smean}  p90=${sp90}  max=${smax}"
  SUMMARY_LINES+=("| ${qid} | ${smin} | ${smedian} | ${smean} | ${sp90} | ${smax} |")
  echo ""
done

# --- Write markdown report ---
REPORT="${OUTPUT_DIR}/benchmark-${TIMESTAMP}.md"

cat > "$REPORT" <<HEADER
# Benchmark Results

**Date:** $(date -u +%Y-%m-%dT%H:%M:%SZ)
**Branch:** $(cd ~/oss/ppl 2>/dev/null && git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
**Commit:** $(cd ~/oss/ppl 2>/dev/null && git rev-parse --short HEAD 2>/dev/null || echo "unknown")

## Protocol

- **Warmup:** ${WARMUP} iterations per query (discarded)
- **Measurement:** ${RUNS} iterations per query
- **Primary metric:** p90 optimize time

## Environment

- Endpoint: ${OPENSEARCH_URL}
- Index: ${INDEX}

## Summary (optimize phase, ms)

| Query | Min | Median | Mean | p90 | Max |
|-------|-----|--------|------|-----|-----|
HEADER

for line in "${SUMMARY_LINES[@]}"; do
  echo "$line" >> "$REPORT"
done

cat >> "$REPORT" <<'FOOTER'

## Raw Data

Raw CSV files per query are in the `raw/` subdirectory:
- `Q<N>-optimize.csv` - optimize phase times (one per line)
- `Q<N>-all-phases.csv` - all phase times (CSV with header)

## Notes

[Add observations about variance, warmup effects, outliers here]
FOOTER

echo "=== Benchmark complete ==="
echo "Report: ${REPORT}"
echo "Raw data: ${RAW_DIR}/"
