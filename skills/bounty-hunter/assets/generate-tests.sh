#!/usr/bin/env bash
# Generate PPL test queries for a given category.
# Usage: ./generate-tests.sh <category> [index]
# Categories: edge-case, command-interaction, function, performance, security, all
# Output: one PPL query per line to stdout
set -euo pipefail

CATEGORY="${1:-all}"
IDX_LOGS="${2:-logs-00001}"
IDX_TYPES="bounty-types"
IDX_NUMS="bounty-numbers"
IDX_LEFT="bounty-left"
IDX_RIGHT="bounty-right"
IDX_EMPTY="bounty-empty"

###############################################################################
# Category A: Edge-Case & Boundary Tests
###############################################################################
generate_edge_case() {
cat <<QUERIES
# --- Null / Missing field handling ---
source=$IDX_TYPES | where int_field IS NULL
source=$IDX_TYPES | where int_field IS NOT NULL
source=$IDX_TYPES | where isnull(int_field)
source=$IDX_TYPES | where isnotnull(keyword_field)
source=$IDX_TYPES | eval x = isnull(int_field) | fields x, int_field
source=$IDX_TYPES | eval x = ifnull(int_field, -999) | fields x
source=$IDX_TYPES | eval x = nullif(int_field, 42) | fields x
source=$IDX_TYPES | eval x = coalesce(null, int_field, 0) | fields x
source=$IDX_TYPES | stats count() by keyword_field
source=$IDX_TYPES | stats avg(int_field)
source=$IDX_TYPES | stats sum(double_field)
source=$IDX_TYPES | where keyword_field = ''
source=$IDX_TYPES | where keyword_field != ''
source=$IDX_TYPES | fillnull with 0 in int_field, long_field
source=$IDX_TYPES | fillnull using int_field = 0, keyword_field = 'N/A'

# --- Type coercion boundaries ---
source=$IDX_TYPES | eval x = CAST(int_field AS STRING) | fields x
source=$IDX_TYPES | eval x = CAST(keyword_field AS INTEGER) | fields x
source=$IDX_TYPES | eval x = CAST(double_field AS INTEGER) | fields x
source=$IDX_TYPES | eval x = CAST('not-a-number' AS INTEGER) | fields x
source=$IDX_TYPES | eval x = CAST('2025-01-15' AS DATE) | fields x
source=$IDX_TYPES | eval x = CAST(date_field AS STRING) | fields x
source=$IDX_TYPES | eval x = CAST(bool_field AS INTEGER) | fields x
source=$IDX_TYPES | eval x = CAST(int_field AS BOOLEAN) | fields x
source=$IDX_TYPES | eval x = CAST(ip_field AS STRING) | fields x
source=$IDX_TYPES | eval x = CAST('invalid-ip' AS IP) | fields x
source=$IDX_TYPES | eval x = CAST(null AS INTEGER) | fields x
source=$IDX_TYPES | eval x = CAST(json_data AS JSON) | fields x
source=$IDX_TYPES | eval x = TONUMBER('abc') | fields x
source=$IDX_TYPES | eval x = TONUMBER('') | fields x
source=$IDX_TYPES | eval x = TOSTRING(null) | fields x

# --- Integer overflow / underflow ---
source=$IDX_TYPES | eval x = int_field + 1 | where int_field = 2147483647 | fields x
source=$IDX_TYPES | eval x = int_field - 1 | where int_field = -1 | fields x
source=$IDX_TYPES | eval x = long_field + 1 | where long_field = 9223372036854775807 | fields x
source=$IDX_TYPES | eval x = int_field * int_field | fields x, int_field

# --- Empty string vs null ---
source=$IDX_TYPES | where keyword_field = ''
source=$IDX_TYPES | where keyword_field IS NULL
source=$IDX_TYPES | where isempty(keyword_field)
source=$IDX_TYPES | where isblank(keyword_field)
source=$IDX_TYPES | eval is_empty = isempty(keyword_field), is_null = isnull(keyword_field), is_blank = isblank(keyword_field) | fields keyword_field, is_empty, is_null, is_blank

# --- Zero-row results ---
source=$IDX_EMPTY | stats count()
source=$IDX_EMPTY | stats avg(value)
source=$IDX_EMPTY | stats sum(value)
source=$IDX_EMPTY | head 10
source=$IDX_EMPTY | sort value
source=$IDX_EMPTY | dedup name
source=$IDX_EMPTY | eval x = 1 | fields x

# --- Nested field access ---
source=$IDX_TYPES | fields nested_obj.inner_key, nested_obj.inner_int
source=$IDX_TYPES | where nested_obj.inner_int > 0
source=$IDX_TYPES | stats avg(nested_obj.inner_int)
source=$IDX_TYPES | eval x = nested_obj.deep.value | fields x
source=$IDX_TYPES | sort nested_obj.inner_int
source=$IDX_TYPES | dedup nested_obj.inner_key
source=$IDX_LOGS | fields resource.attributes.log_type, attributes.cluster.name
source=$IDX_LOGS | where resource.attributes.log_type = 'EKS_node'
source=$IDX_LOGS | stats count() by resource.attributes.log_type

# --- Backtick and special character fields ---
source=$IDX_LOGS | fields \`@timestamp\`, \`attributes.cluster.name\`
source=$IDX_LOGS | where \`@timestamp\` > '2025-09-04T16:18:00Z'
source=$IDX_LOGS | sort \`@timestamp\`
source=$IDX_LOGS | eval x = \`@timestamp\` | fields x

# --- Wildcard field patterns ---
source=$IDX_TYPES | fields int_*, keyword_*
source=$IDX_TYPES | fields *_field
source=$IDX_TYPES | fields nested_obj.*
QUERIES
}

###############################################################################
# Category B: Command Interaction Tests
###############################################################################
generate_command_interaction() {
cat <<QUERIES
# --- Chaining commands ---
source=$IDX_NUMS | stats avg(value) as avg_val by category | stats avg(avg_val)
source=$IDX_NUMS | stats count() as cnt by category | where cnt > 2
source=$IDX_NUMS | stats avg(value) as avg_val by category | sort avg_val
source=$IDX_NUMS | eval doubled = value * 2 | stats sum(doubled) by category
source=$IDX_NUMS | eval doubled = value * 2 | where doubled > 20 | stats count()
source=$IDX_NUMS | where value > 0 | eval pct = value / 100 | stats avg(pct) by category

# --- Rename + downstream reference ---
source=$IDX_NUMS | rename value as val | where val > 0
source=$IDX_NUMS | rename value as val | stats avg(val) by category
source=$IDX_NUMS | rename category as cat | dedup cat
source=$IDX_NUMS | rename value as val, category as cat | sort val

# --- Sort + head combinations ---
source=$IDX_NUMS | sort value | head 3
source=$IDX_NUMS | sort - value | head 3
source=$IDX_NUMS | sort value | head 2 from 1
source=$IDX_NUMS | head 5 | sort value
source=$IDX_NUMS | sort count | head 1 from 3

# --- Dedup variations ---
source=$IDX_NUMS | dedup category
source=$IDX_NUMS | dedup 2 category
source=$IDX_NUMS | dedup category keepempty=true
source=$IDX_NUMS | dedup category, subcategory
source=$IDX_NUMS | dedup category consecutive=true

# --- Fillnull + stats ---
source=$IDX_NUMS | fillnull with 0 in value | stats sum(value) by category
source=$IDX_NUMS | fillnull with 'UNKNOWN' in category | stats count() by category

# --- Expand/Flatten in chains ---
source=$IDX_TYPES | where tags IS NOT NULL | fields tags, keyword_field

# --- Join variations ---
source=$IDX_LEFT | join left=$IDX_LEFT, right=$IDX_RIGHT on dept_id $IDX_RIGHT
source=$IDX_LEFT | join type=left $IDX_RIGHT on dept_id = dept_id
source=$IDX_LEFT | join type=inner $IDX_RIGHT on dept_id = dept_id
source=$IDX_LEFT | join type=left $IDX_RIGHT on dept_id = dept_id | where dept_name IS NULL

# --- Subquery ---
source=$IDX_LEFT | where salary > [source=$IDX_LEFT | stats avg(salary)]
source=$IDX_LEFT | where dept_id IN [source=$IDX_RIGHT | fields dept_id]

# --- Append/Appendcol ---
source=$IDX_LEFT | fields name, salary | append [source=$IDX_RIGHT | fields dept_name as name, dept_id as salary]

# --- Eval + where interaction ---
source=$IDX_NUMS | eval x = value + count | where x > 100
source=$IDX_NUMS | eval x = if(value > 50, 'high', 'low') | stats count() by x
source=$IDX_NUMS | eval x = case(value > 100, 'high', value > 0, 'med' else 'low') | fields x, value

# --- Multiple evals ---
source=$IDX_NUMS | eval a = value * 2 | eval b = a + 10 | eval c = b / count | fields a, b, c

# --- Reverse ---
source=$IDX_NUMS | sort value | reverse | head 3
QUERIES
}

###############################################################################
# Category C: Function Correctness Tests
###############################################################################
generate_function() {
cat <<QUERIES
# --- String functions ---
source=$IDX_TYPES | eval x = length(keyword_field) | fields x, keyword_field
source=$IDX_TYPES | eval x = lower(keyword_field) | fields x
source=$IDX_TYPES | eval x = upper(keyword_field) | fields x
source=$IDX_TYPES | eval x = trim('  hello  ') | fields x
source=$IDX_TYPES | eval x = ltrim('  hello  ') | fields x
source=$IDX_TYPES | eval x = rtrim('  hello  ') | fields x
source=$IDX_TYPES | eval x = substr(keyword_field, 1, 3) | fields x
source=$IDX_TYPES | eval x = concat(keyword_field, '_suffix') | fields x
source=$IDX_TYPES | eval x = concat_ws('-', keyword_field, 'b', 'c') | fields x
source=$IDX_TYPES | eval x = replace(keyword_field, 'hello', 'bye') | fields x
source=$IDX_TYPES | eval x = reverse(keyword_field) | fields x
source=$IDX_TYPES | eval x = locate('ll', keyword_field) | fields x
source=$IDX_TYPES | eval x = position('ll' IN keyword_field) | fields x
source=$IDX_TYPES | eval x = ascii(keyword_field) | fields x
source=$IDX_TYPES | eval x = strcmp(keyword_field, 'hello') | fields x
source=$IDX_TYPES | eval x = length('') | fields x
source=$IDX_TYPES | eval x = length(null) | fields x
source=$IDX_TYPES | eval x = substr('hello', 0, 100) | fields x
source=$IDX_TYPES | eval x = substr('hello', -1, 2) | fields x
source=$IDX_TYPES | eval x = replace('', '', 'x') | fields x
source=$IDX_TYPES | eval x = regexp_replace(keyword_field, '[aeiou]', '*') | fields x

# --- Math functions ---
source=$IDX_TYPES | eval x = abs(-42) | fields x
source=$IDX_TYPES | eval x = abs(int_field) | fields x
source=$IDX_TYPES | eval x = ceil(3.1) | fields x
source=$IDX_TYPES | eval x = floor(3.9) | fields x
source=$IDX_TYPES | eval x = round(3.456, 2) | fields x
source=$IDX_TYPES | eval x = round(3.456, 0) | fields x
source=$IDX_TYPES | eval x = round(3.5) | fields x
source=$IDX_TYPES | eval x = sqrt(4) | fields x
source=$IDX_TYPES | eval x = sqrt(-1) | fields x
source=$IDX_TYPES | eval x = pow(2, 10) | fields x
source=$IDX_TYPES | eval x = pow(2, -1) | fields x
source=$IDX_TYPES | eval x = log(100) | fields x
source=$IDX_TYPES | eval x = log(0) | fields x
source=$IDX_TYPES | eval x = log(-1) | fields x
source=$IDX_TYPES | eval x = ln(1) | fields x
source=$IDX_TYPES | eval x = exp(0) | fields x
source=$IDX_TYPES | eval x = mod(10, 3) | fields x
source=$IDX_TYPES | eval x = mod(10, 0) | fields x
source=$IDX_TYPES | eval x = pi() | fields x
source=$IDX_TYPES | eval x = e() | fields x
source=$IDX_TYPES | eval x = sign(-5) | fields x
source=$IDX_TYPES | eval x = sign(0) | fields x
source=$IDX_TYPES | eval x = cbrt(27) | fields x
source=$IDX_TYPES | eval x = truncate(3.456, 1) | fields x

# --- Trig functions ---
source=$IDX_TYPES | eval x = sin(0) | fields x
source=$IDX_TYPES | eval x = cos(0) | fields x
source=$IDX_TYPES | eval x = tan(0) | fields x
source=$IDX_TYPES | eval x = asin(1) | fields x
source=$IDX_TYPES | eval x = acos(1) | fields x
source=$IDX_TYPES | eval x = atan(1) | fields x
source=$IDX_TYPES | eval x = atan2(1, 1) | fields x
source=$IDX_TYPES | eval x = degrees(3.14159) | fields x
source=$IDX_TYPES | eval x = radians(180) | fields x
source=$IDX_TYPES | eval x = asin(2) | fields x
source=$IDX_TYPES | eval x = acos(2) | fields x

# --- Date/Time functions ---
source=$IDX_TYPES | eval x = now() | fields x
source=$IDX_TYPES | eval x = curdate() | fields x
source=$IDX_TYPES | eval x = year(date_field) | fields x
source=$IDX_TYPES | eval x = month(date_field) | fields x
source=$IDX_TYPES | eval x = day(date_field) | fields x
source=$IDX_TYPES | eval x = hour(date_field) | fields x
source=$IDX_TYPES | eval x = minute(date_field) | fields x
source=$IDX_TYPES | eval x = second(date_field) | fields x
source=$IDX_TYPES | eval x = dayofweek(date_field) | fields x
source=$IDX_TYPES | eval x = dayofyear(date_field) | fields x
source=$IDX_TYPES | eval x = datediff(DATE('2025-01-15'), DATE('2025-01-01')) | fields x
source=$IDX_TYPES | eval x = adddate(date_field, 30) | fields x
source=$IDX_TYPES | eval x = adddate(date_field, INTERVAL 1 HOUR) | fields x
source=$IDX_TYPES | eval x = date_format(date_field, '%Y-%m-%d') | fields x
source=$IDX_TYPES | eval x = unix_timestamp(date_field) | fields x
source=$IDX_TYPES | eval x = from_unixtime(0) | fields x
source=$IDX_TYPES | eval x = year(null) | fields x
source=$IDX_TYPES | eval x = datediff(null, DATE('2025-01-01')) | fields x

# --- Conditional functions ---
source=$IDX_TYPES | eval x = if(int_field > 0, 'positive', 'non-positive') | fields x
source=$IDX_TYPES | eval x = if(null, 'yes', 'no') | fields x
source=$IDX_TYPES | eval x = case(int_field > 100, 'big', int_field > 0, 'small' else 'zero-or-neg') | fields x
source=$IDX_TYPES | eval x = coalesce(null, null, 'fallback') | fields x
source=$IDX_TYPES | eval x = coalesce(int_field, -1) | fields x
source=$IDX_TYPES | eval x = nullif(int_field, 0) | fields x

# --- JSON functions ---
source=$IDX_TYPES | eval x = json_valid(json_data) | fields x
source=$IDX_TYPES | eval x = json_extract(json_data, '$.name') | fields x
source=$IDX_TYPES | eval x = json_keys(json_data) | fields x
source=$IDX_TYPES | eval x = json_valid('not json') | fields x
source=$IDX_TYPES | eval x = json_valid('') | fields x
source=$IDX_TYPES | eval x = json_valid(null) | fields x
source=$IDX_TYPES | eval x = json_extract('{}', '$.missing') | fields x
source=$IDX_TYPES | eval x = json_array_length(json_extract(json_data, '$.scores')) | fields x

# --- Crypto functions ---
source=$IDX_TYPES | eval x = md5(keyword_field) | fields x
source=$IDX_TYPES | eval x = sha1(keyword_field) | fields x
source=$IDX_TYPES | eval x = sha2(keyword_field, 256) | fields x
source=$IDX_TYPES | eval x = md5('') | fields x
source=$IDX_TYPES | eval x = md5(null) | fields x

# --- Collection functions ---
source=$IDX_TYPES | eval x = split('a,b,c', ',') | fields x
source=$IDX_TYPES | eval x = array(1, 2, 3) | fields x
source=$IDX_TYPES | eval x = array_length(array(1, 2, 3)) | fields x

# --- IP functions ---
source=$IDX_TYPES | eval x = cidrmatch(ip_field, '192.168.1.0/24') | fields x
source=$IDX_TYPES | eval x = cidrmatch(ip_field, '10.0.0.0/8') | fields x
source=$IDX_TYPES | where cidrmatch(ip_field, '192.168.0.0/16')

# --- TYPEOF ---
source=$IDX_TYPES | eval x = typeof(int_field) | fields x
source=$IDX_TYPES | eval x = typeof(keyword_field) | fields x
source=$IDX_TYPES | eval x = typeof(null) | fields x
source=$IDX_TYPES | eval x = typeof(date_field) | fields x

# --- Aggregation edge cases ---
source=$IDX_NUMS | stats avg(value) by category
source=$IDX_NUMS | stats percentile(value, 50)
source=$IDX_NUMS | stats percentile(value, 0)
source=$IDX_NUMS | stats percentile(value, 100)
source=$IDX_NUMS | stats percentile(value, 99.9)
source=$IDX_NUMS | stats var_samp(value)
source=$IDX_NUMS | stats var_pop(value)
source=$IDX_NUMS | stats stddev_samp(value)
source=$IDX_NUMS | stats stddev_pop(value)
source=$IDX_NUMS | stats distinct_count(category)
source=$IDX_NUMS | stats values(category)
source=$IDX_NUMS | stats list(category)
source=$IDX_NUMS | stats earliest(ts)
source=$IDX_NUMS | stats latest(ts)
source=$IDX_NUMS | stats first(value)
source=$IDX_NUMS | stats last(value)
source=$IDX_NUMS | stats take(category, 3)
source=$IDX_NUMS | stats count() as cnt by span(ts, 1d)
source=$IDX_NUMS | stats count() as cnt by span(ts, 1h)
QUERIES
}

###############################################################################
# Category D: Performance Tests
###############################################################################
generate_performance() {
cat <<QUERIES
# --- Long pipelines ---
source=$IDX_NUMS | where value > 0 | eval x = value * 2 | eval y = x + count | where y > 10 | stats avg(y) by category | sort avg(y) | head 5
source=$IDX_NUMS | eval a = value + 1 | eval b = a * 2 | eval c = b - 3 | eval d = c / 2 | eval e = d + a | eval f = e * b | eval g = f - c | eval h = g + d | fields h

# --- Deep function nesting ---
source=$IDX_TYPES | eval x = abs(ceil(floor(round(sqrt(abs(double_field)))))) | fields x
source=$IDX_TYPES | eval x = concat(concat(concat(concat(keyword_field, '_a'), '_b'), '_c'), '_d') | fields x
source=$IDX_TYPES | eval x = if(if(if(int_field > 0, true, false), 'a', 'b') = 'a', 'yes', 'no') | fields x

# --- Regex patterns (potential catastrophic backtracking) ---
source=$IDX_TYPES | where text_field like '%fox%'
source=$IDX_TYPES | eval x = regexp_replace(text_field, '(a+)+b', 'x') | fields x
source=$IDX_TYPES | parse text_field '(?<word>\\w+)\\s+(?<rest>.*)'

# --- High cardinality ---
source=$IDX_LOGS | stats count() by body
source=$IDX_LOGS | stats count() by body, \`@timestamp\`
source=$IDX_LOGS | top 5 body

# --- Stats on stats ---
source=$IDX_NUMS | stats avg(value) as avg_v, count() as cnt by category, subcategory | stats avg(avg_v) by category

# --- Join performance ---
source=$IDX_LEFT | join type=left $IDX_RIGHT on dept_id = dept_id | stats avg(salary) by dept_name

# --- Multiple subqueries ---
source=$IDX_LEFT | where salary > [source=$IDX_LEFT | stats avg(salary)] | where dept_id IN [source=$IDX_RIGHT | fields dept_id]
QUERIES
}

###############################################################################
# Category E: Security Tests
###############################################################################
generate_security() {
cat <<QUERIES
# --- Field name injection attempts ---
source=$IDX_TYPES | fields keyword_field
source=$IDX_TYPES | eval x = 1 | fields x

# --- Metadata field access ---
source=$IDX_TYPES | fields _id
source=$IDX_TYPES | fields _source
source=$IDX_TYPES | fields _score
source=$IDX_TYPES | where _id = '1'
source=$IDX_TYPES | eval x = _id | fields x

# --- Cross-index in join ---
source=$IDX_LEFT | join type=left .opensearch-sap-log-types-config on id = dept_id

# --- CIDR edge cases ---
source=$IDX_TYPES | where cidrmatch(ip_field, 'invalid-cidr')
source=$IDX_TYPES | where cidrmatch(ip_field, '0.0.0.0/0')
source=$IDX_TYPES | where cidrmatch(ip_field, '255.255.255.255/32')
source=$IDX_TYPES | eval x = cidrmatch(keyword_field, '10.0.0.0/8') | fields x

# --- Very long inputs ---
source=$IDX_TYPES | where keyword_field = '$(python3 -c "print('A'*10000)")'
source=$IDX_TYPES | eval x = length('$(python3 -c "print('B'*10000)")') | fields x

# --- Regex ReDoS patterns ---
source=$IDX_TYPES | where match(text_field, '(a+)+$')

# --- Script-like expressions in eval ---
source=$IDX_TYPES | eval x = 1; eval y = 2 | fields x
source=$IDX_TYPES | eval x = CAST('1; DROP TABLE test' AS STRING) | fields x

# --- System index access patterns ---
source=.plugins-ml-config | head 1
source=.opendistro_security | head 1
source=.kibana | head 1
QUERIES
}

###############################################################################
# Main dispatcher
###############################################################################
case "$CATEGORY" in
  edge-case)
    generate_edge_case
    ;;
  command-interaction)
    generate_command_interaction
    ;;
  function)
    generate_function
    ;;
  performance)
    generate_performance
    ;;
  security)
    generate_security
    ;;
  all)
    echo "# ===== EDGE-CASE TESTS ====="
    generate_edge_case
    echo ""
    echo "# ===== COMMAND INTERACTION TESTS ====="
    generate_command_interaction
    echo ""
    echo "# ===== FUNCTION CORRECTNESS TESTS ====="
    generate_function
    echo ""
    echo "# ===== PERFORMANCE TESTS ====="
    generate_performance
    echo ""
    echo "# ===== SECURITY TESTS ====="
    generate_security
    ;;
  *)
    echo "Unknown category: $CATEGORY" >&2
    echo "Usage: $0 <edge-case|command-interaction|function|performance|security|all> [index]" >&2
    exit 1
    ;;
esac
