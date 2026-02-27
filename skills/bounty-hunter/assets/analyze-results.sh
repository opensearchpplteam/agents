#!/usr/bin/env bash
# Analyze bounty hunter test results and summarize findings.
# Usage: ./analyze-results.sh [results-file]
# If no file specified, uses the most recent results file.
set -euo pipefail

OUTPUT_DIR="$HOME/oss/ppl/bounty-hunter"

if [ -n "${1:-}" ]; then
  RESULTS_FILE="$1"
else
  RESULTS_FILE=$(ls -t "$OUTPUT_DIR"/results-*.jsonl 2>/dev/null | head -1)
  if [ -z "$RESULTS_FILE" ]; then
    echo "No results files found in $OUTPUT_DIR"
    exit 1
  fi
fi

echo "=== PPL Bounty Hunter: Analysis of $RESULTS_FILE ==="
echo ""

TOTAL=$(wc -l < "$RESULTS_FILE")
ERRORS=$(grep -c '"status":"ERROR"' "$RESULTS_FILE" || echo 0)
OK=$(grep -c '"status":"OK"' "$RESULTS_FILE" || echo 0)
PARSE_ERR=$(grep -c '"status":"PARSE_ERROR"' "$RESULTS_FILE" || echo 0)

echo "Total queries tested: $TOTAL"
echo "  Successful (OK):    $OK"
echo "  Errors (FAIL):      $ERRORS"
echo "  Parse errors:       $PARSE_ERR"
echo ""

if [ "$ERRORS" -gt 0 ]; then
  echo "=== Failed Queries ==="
  echo ""
  grep '"status":"ERROR"' "$RESULTS_FILE" | python3 -c "
import sys, json
for line in sys.stdin:
    try:
        d = json.loads(line.strip())
        print(f\"[{d['id']}] {d['query']}\")
        if isinstance(d.get('execute_body'), dict) and 'error' in d['execute_body']:
            err = d['execute_body']['error']
            if isinstance(err, dict):
                print(f\"       Error: {err.get('type','')}: {err.get('reason','')[:200]}\")
            else:
                print(f\"       Error: {str(err)[:200]}\")
        elif d.get('execute_http','').startswith(('4','5')):
            body = d.get('execute_body','')
            if isinstance(body, str):
                print(f\"       HTTP {d['execute_http']}: {body[:200]}\")
            else:
                print(f\"       HTTP {d['execute_http']}\")
        print()
    except:
        pass
"
fi

echo ""
echo "=== Error Categories ==="
grep '"status":"ERROR"' "$RESULTS_FILE" | python3 -c "
import sys, json
from collections import Counter
errors = Counter()
for line in sys.stdin:
    try:
        d = json.loads(line.strip())
        body = d.get('execute_body', {})
        if isinstance(body, dict) and 'error' in body:
            err = body['error']
            if isinstance(err, dict):
                errors[err.get('type', 'unknown')] += 1
            else:
                errors['string_error'] += 1
        elif d.get('execute_http','').startswith('4'):
            errors[f'http_{d[\"execute_http\"]}'] += 1
        elif d.get('execute_http','').startswith('5'):
            errors[f'http_{d[\"execute_http\"]}'] += 1
        else:
            errors['other'] += 1
    except:
        errors['parse_failed'] += 1

for err_type, count in errors.most_common():
    print(f'  {err_type}: {count}')
" 2>/dev/null || echo "  (could not categorize errors)"
