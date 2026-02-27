#!/usr/bin/env bash
# Execute PPL test queries and capture results.
# Usage: ./run-tests.sh <category> [mode]
# mode: execute (default), explain, both
# Reads queries from generate-tests.sh and runs them against OpenSearch.
set -euo pipefail

CATEGORY="${1:-all}"
MODE="${2:-both}"
BASE_URL="${OPENSEARCH_URL:-http://localhost:9200}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$HOME/oss/ppl/bounty-hunter"
RESULTS_FILE="$OUTPUT_DIR/results-${CATEGORY}-$(date +%Y%m%d-%H%M%S).jsonl"

mkdir -p "$OUTPUT_DIR"

echo "=== PPL Bounty Hunter: Running $CATEGORY tests (mode=$MODE) ==="
echo "Results: $RESULTS_FILE"
echo ""

TOTAL=0
ERRORS=0
PARSE_FAILURES=0
SUCCESSES=0

# Generate and iterate through test queries
"$SCRIPT_DIR/generate-tests.sh" "$CATEGORY" | while IFS= read -r query; do
  # Skip empty lines and comments
  [[ -z "$query" || "$query" =~ ^[[:space:]]*# ]] && continue

  TOTAL=$((TOTAL + 1))
  QUERY_ID=$(printf "%04d" $TOTAL)

  # Run explain
  EXPLAIN_RESULT=""
  EXPLAIN_STATUS=""
  if [ "$MODE" = "explain" ] || [ "$MODE" = "both" ]; then
    EXPLAIN_RESULT=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/_plugins/_ppl/_explain" \
      -H 'Content-Type: application/json' \
      -d "{\"query\": $(echo "$query" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read().strip()))')}" 2>&1 || echo "CURL_ERROR")
    EXPLAIN_HTTP=$(echo "$EXPLAIN_RESULT" | tail -1)
    EXPLAIN_BODY=$(echo "$EXPLAIN_RESULT" | sed '$d')
    EXPLAIN_STATUS="$EXPLAIN_HTTP"
  fi

  # Run execute
  EXECUTE_RESULT=""
  EXECUTE_STATUS=""
  if [ "$MODE" = "execute" ] || [ "$MODE" = "both" ]; then
    EXECUTE_RESULT=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/_plugins/_ppl" \
      -H 'Content-Type: application/json' \
      -d "{\"query\": $(echo "$query" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read().strip()))')}" 2>&1 || echo "CURL_ERROR")
    EXECUTE_HTTP=$(echo "$EXECUTE_RESULT" | tail -1)
    EXECUTE_BODY=$(echo "$EXECUTE_RESULT" | sed '$d')
    EXECUTE_STATUS="$EXECUTE_HTTP"
  fi

  # Determine status
  STATUS="OK"
  if [[ "$EXPLAIN_STATUS" =~ ^[45] ]] || [[ "$EXECUTE_STATUS" =~ ^[45] ]]; then
    STATUS="ERROR"
    ERRORS=$((ERRORS + 1))
  elif echo "$EXECUTE_BODY" 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); sys.exit(0 if 'error' in d else 1)" 2>/dev/null; then
    STATUS="ERROR"
    ERRORS=$((ERRORS + 1))
  else
    SUCCESSES=$((SUCCESSES + 1))
  fi

  # Log result as JSONL
  python3 -c "
import json, sys
result = {
    'id': '$QUERY_ID',
    'query': $(echo "$query" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read().strip()))'),
    'status': '$STATUS',
    'explain_http': '$EXPLAIN_STATUS',
    'execute_http': '$EXECUTE_STATUS',
}
try:
    result['explain_body'] = json.loads('''$EXPLAIN_BODY''')
except:
    result['explain_body'] = '''$EXPLAIN_BODY'''[:500]
try:
    result['execute_body'] = json.loads('''$EXECUTE_BODY''')
except:
    result['execute_body'] = '''$EXECUTE_BODY'''[:500]
print(json.dumps(result))
" >> "$RESULTS_FILE" 2>/dev/null || echo "{\"id\":\"$QUERY_ID\",\"query\":\"parse_error\",\"status\":\"PARSE_ERROR\"}" >> "$RESULTS_FILE"

  # Print progress
  if [ "$STATUS" = "ERROR" ]; then
    echo "[$QUERY_ID] FAIL: $query"
  else
    echo "[$QUERY_ID]   OK: $query"
  fi

done

echo ""
echo "=== Summary ==="
echo "Results written to: $RESULTS_FILE"
echo "Review errors with: grep '\"status\":\"ERROR\"' $RESULTS_FILE | python3 -m json.tool"
