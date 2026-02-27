#!/usr/bin/env bash
# Setup test data for PPL Bounty Hunter
# Idempotent - safe to re-run. Creates indices with test data.
set -euo pipefail

BASE_URL="${OPENSEARCH_URL:-http://localhost:9200}"

echo "=== PPL Bounty Hunter: Setting up test data ==="
echo "Target: $BASE_URL"

# Wait for cluster health
echo "Checking cluster health..."
for i in $(seq 1 30); do
  STATUS=$(curl -s "$BASE_URL/_cluster/health" 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('status',''))" 2>/dev/null || echo "")
  if [ "$STATUS" = "green" ] || [ "$STATUS" = "yellow" ]; then
    echo "Cluster is $STATUS"
    break
  fi
  echo "Waiting for cluster... ($i/30)"
  sleep 2
done

###############################################################################
# 1. OTEL Logs index (primary test data from user)
###############################################################################
echo ""
echo "--- Setting up OTEL log index template ---"
curl -s -X POST "$BASE_URL/_index_template/log-template" \
  -H 'Content-Type: application/json' -d '{
  "index_patterns": ["logs-*"],
  "priority": 100,
  "template": {
    "settings": {
      "number_of_shards": 1,
      "number_of_replicas": 0
    },
    "mappings": {
      "dynamic_templates": [
        {
          "resource_attributes": {
            "path_match": "resource.attributes.*",
            "mapping": { "type": "keyword" },
            "match_mapping_type": "string"
          }
        },
        {
          "attributes": {
            "path_match": "attributes.*",
            "mapping": { "type": "keyword" },
            "match_mapping_type": "string"
          }
        }
      ],
      "properties": {
        "traceId": { "type": "keyword" },
        "flags": { "type": "byte" },
        "severityNumber": { "type": "integer" },
        "body": { "norms": false, "type": "text" },
        "serviceName": { "type": "keyword" },
        "schemaUrl": { "type": "keyword" },
        "spanId": { "type": "keyword" },
        "@timestamp": { "type": "date" },
        "severityText": { "type": "keyword" },
        "@version": { "type": "keyword" },
        "attributes": {
          "type": "object",
          "properties": {
            "time": { "enabled": false, "type": "object" }
          }
        },
        "time": { "type": "date" },
        "observedTimestamp": { "type": "date" }
      }
    }
  }
}' && echo ""

echo "--- Creating logs-00001 index with sample data ---"
curl -s -X PUT "$BASE_URL/logs-00001" -H 'Content-Type: application/json' -d '{}' 2>/dev/null || true
echo ""

# Bulk insert OTEL log documents
curl -s -X POST "$BASE_URL/logs-00001/_bulk?refresh=true" \
  -H 'Content-Type: application/x-ndjson' -d '
{"index":{}}
{"traceId":"","instrumentationScope":{"droppedAttributesCount":0},"resource":{"droppedAttributesCount":0,"attributes":{"log_type":"EKS_node","k8s_label.productid":"pr123456","k8s_label.sourcetype":"unknown","productid":"pr123456","k8s.platform":"EKS","k8s_label.criticality_code":"99","k8s.cluster.business.unit":"bu","criticality_code":"5","sourcetype":"unknown","log_tier":"standard","applicationid":"ap123456","obs_namespace":"defaultv1"},"schemaUrl":""},"flags":0,"severityNumber":0,"schemaUrl":"","spanId":"","severityText":"","attributes":{"cluster.name":"xyz-cluster1-ci-prod-us-east-1","cluster.region":"us-east-1","log.file.path":"/var/log/xyz/abc.log","cluster.env":"prod","obs_body_length":146},"time":"2025-09-04T16:17:36.046227585Z","droppedAttributesCount":0,"observedTimestamp":"2025-09-04T16:17:36.046227585Z","@timestamp":"2025-09-04T16:17:39.133Z","body":"{\"msg\":\"Error finding unassigned IPs for ENI xyz\",\"caller\":\"xyz/abc.go:702\",\"level\":\"error\",\"ts\":\"2025-09-04T16:17:35.976Z\"}"}
{"index":{}}
{"traceId":"trace-001","instrumentationScope":{"droppedAttributesCount":0},"resource":{"droppedAttributesCount":0,"attributes":{"log_type":"EKS_node","productid":"pr789012","k8s.platform":"EKS","criticality_code":"3","sourcetype":"app","log_tier":"premium","applicationid":"ap789012","obs_namespace":"monitoring"},"schemaUrl":""},"flags":1,"severityNumber":5,"schemaUrl":"","spanId":"span-001","severityText":"WARN","attributes":{"cluster.name":"abc-cluster2-prod-us-west-2","cluster.region":"us-west-2","log.file.path":"/var/log/app/server.log","cluster.env":"prod","obs_body_length":200},"time":"2025-09-04T16:18:00.000Z","droppedAttributesCount":0,"observedTimestamp":"2025-09-04T16:18:00.500Z","@timestamp":"2025-09-04T16:18:01.000Z","body":"{\"msg\":\"Connection timeout to database\",\"caller\":\"db/pool.go:150\",\"level\":\"warn\",\"ts\":\"2025-09-04T16:17:59.000Z\"}"}
{"index":{}}
{"traceId":"trace-002","instrumentationScope":{"droppedAttributesCount":1},"resource":{"droppedAttributesCount":0,"attributes":{"log_type":"ECS_task","productid":"pr345678","k8s.platform":"ECS","criticality_code":"1","sourcetype":"system","log_tier":"standard","applicationid":"ap345678","obs_namespace":"infra"},"schemaUrl":""},"flags":0,"severityNumber":9,"schemaUrl":"","spanId":"span-002","severityText":"ERROR","attributes":{"cluster.name":"def-cluster3-staging-eu-west-1","cluster.region":"eu-west-1","log.file.path":"/var/log/system/kernel.log","cluster.env":"staging","obs_body_length":95},"time":"2025-09-04T16:19:00.000Z","droppedAttributesCount":0,"observedTimestamp":"2025-09-04T16:19:00.100Z","@timestamp":"2025-09-04T16:19:01.000Z","body":"{\"msg\":\"Out of memory killed process\",\"caller\":\"kernel\",\"level\":\"error\",\"ts\":\"2025-09-04T16:18:59.000Z\"}"}
{"index":{}}
{"traceId":"","instrumentationScope":{"droppedAttributesCount":0},"resource":{"droppedAttributesCount":0,"attributes":{"log_type":"Lambda","productid":"pr000000","k8s.platform":"Lambda","criticality_code":"7","sourcetype":"function","log_tier":"archive","applicationid":"ap000000","obs_namespace":"serverless"},"schemaUrl":""},"flags":0,"severityNumber":0,"schemaUrl":"","spanId":"","severityText":"","attributes":{"cluster.name":"","cluster.region":"ap-southeast-1","log.file.path":"","cluster.env":"dev","obs_body_length":0},"time":"2025-09-04T16:20:00.000Z","droppedAttributesCount":0,"observedTimestamp":"2025-09-04T16:20:00.000Z","@timestamp":"2025-09-04T16:20:01.000Z","body":""}
{"index":{}}
{"traceId":"trace-003","instrumentationScope":{"droppedAttributesCount":0},"resource":{"droppedAttributesCount":0,"attributes":{"log_type":"EKS_node","productid":"pr123456","k8s.platform":"EKS","criticality_code":"5","sourcetype":"unknown","log_tier":"standard","applicationid":"ap123456","obs_namespace":"defaultv1"},"schemaUrl":""},"flags":0,"severityNumber":5,"schemaUrl":"","spanId":"span-003","severityText":"WARN","attributes":{"cluster.name":"xyz-cluster1-ci-prod-us-east-1","cluster.region":"us-east-1","log.file.path":"/var/log/xyz/abc.log","cluster.env":"prod","obs_body_length":180},"time":"2025-09-04T16:21:00.000Z","droppedAttributesCount":0,"observedTimestamp":"2025-09-04T16:21:00.200Z","@timestamp":"2025-09-04T16:21:01.000Z","body":"{\"msg\":\"Retry attempt 3 for service call\",\"caller\":\"xyz/retry.go:45\",\"level\":\"warn\",\"ts\":\"2025-09-04T16:20:59.000Z\"}"}
' && echo ""

###############################################################################
# 2. Typed test index for type coercion and edge-case tests
###############################################################################
echo ""
echo "--- Creating bounty-types index for type coercion tests ---"
curl -s -X DELETE "$BASE_URL/bounty-types" 2>/dev/null || true
curl -s -X PUT "$BASE_URL/bounty-types" -H 'Content-Type: application/json' -d '{
  "settings": { "number_of_shards": 1, "number_of_replicas": 0 },
  "mappings": {
    "properties": {
      "int_field": { "type": "integer" },
      "long_field": { "type": "long" },
      "float_field": { "type": "float" },
      "double_field": { "type": "double" },
      "keyword_field": { "type": "keyword" },
      "text_field": { "type": "text", "fields": { "keyword": { "type": "keyword" } } },
      "bool_field": { "type": "boolean" },
      "date_field": { "type": "date" },
      "ip_field": { "type": "ip" },
      "nested_obj": {
        "type": "object",
        "properties": {
          "inner_key": { "type": "keyword" },
          "inner_int": { "type": "integer" },
          "deep": {
            "type": "object",
            "properties": {
              "value": { "type": "keyword" }
            }
          }
        }
      },
      "tags": { "type": "keyword" },
      "json_data": { "type": "text" }
    }
  }
}' && echo ""

curl -s -X POST "$BASE_URL/bounty-types/_bulk?refresh=true" \
  -H 'Content-Type: application/x-ndjson' -d '
{"index":{"_id":"1"}}
{"int_field":42,"long_field":9999999999,"float_field":3.14,"double_field":2.718281828,"keyword_field":"hello","text_field":"The quick brown fox","bool_field":true,"date_field":"2025-01-15T10:30:00Z","ip_field":"192.168.1.1","nested_obj":{"inner_key":"a","inner_int":10,"deep":{"value":"deep_a"}},"tags":["tag1","tag2","tag3"],"json_data":"{\"name\":\"alice\",\"scores\":[90,85,92]}"}
{"index":{"_id":"2"}}
{"int_field":-1,"long_field":0,"float_field":-0.001,"double_field":0.0,"keyword_field":"world","text_field":"jumps over the lazy dog","bool_field":false,"date_field":"2024-02-29T00:00:00Z","ip_field":"10.0.0.1","nested_obj":{"inner_key":"b","inner_int":-5,"deep":{"value":"deep_b"}},"tags":["tag2","tag4"],"json_data":"{\"name\":\"bob\",\"scores\":[]}"}
{"index":{"_id":"3"}}
{"int_field":0,"long_field":-9999999999,"float_field":0.0,"double_field":-999.999,"keyword_field":"","text_field":"","bool_field":true,"date_field":"1970-01-01T00:00:00Z","ip_field":"255.255.255.255","nested_obj":{"inner_key":"","inner_int":0,"deep":{"value":""}},"tags":[],"json_data":"{}"}
{"index":{"_id":"4"}}
{"int_field":2147483647,"long_field":9223372036854775807,"float_field":3.4028235E38,"double_field":1.7976931348623157E308,"keyword_field":"special chars: <>&\"'\\'\\n\\t","text_field":"unicode: \u00e9\u00e0\u00fc\u00f1 \u4e16\u754c \ud83c\udf0d","bool_field":false,"date_field":"2099-12-31T23:59:59Z","ip_field":"::1","nested_obj":{"inner_key":"c","inner_int":2147483647,"deep":{"value":"deep_c"}},"tags":["tag1"],"json_data":"{\"nested\":{\"deep\":{\"array\":[1,2,3]}}}"}
{"index":{"_id":"5"}}
{"int_field":null,"long_field":null,"float_field":null,"double_field":null,"keyword_field":null,"text_field":null,"bool_field":null,"date_field":null,"ip_field":null,"nested_obj":null,"tags":null,"json_data":null}
' && echo ""

###############################################################################
# 3. Numeric-only index for aggregation/stats edge cases
###############################################################################
echo ""
echo "--- Creating bounty-numbers index for aggregation tests ---"
curl -s -X DELETE "$BASE_URL/bounty-numbers" 2>/dev/null || true
curl -s -X PUT "$BASE_URL/bounty-numbers" -H 'Content-Type: application/json' -d '{
  "settings": { "number_of_shards": 1, "number_of_replicas": 0 },
  "mappings": {
    "properties": {
      "category": { "type": "keyword" },
      "subcategory": { "type": "keyword" },
      "value": { "type": "double" },
      "count": { "type": "integer" },
      "ts": { "type": "date" }
    }
  }
}' && echo ""

curl -s -X POST "$BASE_URL/bounty-numbers/_bulk?refresh=true" \
  -H 'Content-Type: application/x-ndjson' -d '
{"index":{}}
{"category":"A","subcategory":"x","value":10.5,"count":1,"ts":"2025-01-01T00:00:00Z"}
{"index":{}}
{"category":"A","subcategory":"x","value":20.3,"count":2,"ts":"2025-01-01T01:00:00Z"}
{"index":{}}
{"category":"A","subcategory":"y","value":-5.0,"count":0,"ts":"2025-01-01T02:00:00Z"}
{"index":{}}
{"category":"B","subcategory":"x","value":100.0,"count":10,"ts":"2025-01-02T00:00:00Z"}
{"index":{}}
{"category":"B","subcategory":"y","value":0.0,"count":0,"ts":"2025-01-02T01:00:00Z"}
{"index":{}}
{"category":"B","subcategory":"y","value":null,"count":null,"ts":"2025-01-02T02:00:00Z"}
{"index":{}}
{"category":"C","subcategory":null,"value":50.0,"count":5,"ts":"2025-01-03T00:00:00Z"}
{"index":{}}
{"category":null,"subcategory":"z","value":75.0,"count":3,"ts":"2025-01-03T01:00:00Z"}
{"index":{}}
{"category":"A","subcategory":"x","value":10.5,"count":1,"ts":"2025-01-01T00:00:00Z"}
{"index":{}}
{"category":"A","subcategory":"x","value":10.5,"count":1,"ts":"2025-01-01T00:00:00Z"}
' && echo ""

###############################################################################
# 4. Join test indices
###############################################################################
echo ""
echo "--- Creating bounty-left and bounty-right for join tests ---"
curl -s -X DELETE "$BASE_URL/bounty-left" 2>/dev/null || true
curl -s -X DELETE "$BASE_URL/bounty-right" 2>/dev/null || true

curl -s -X PUT "$BASE_URL/bounty-left" -H 'Content-Type: application/json' -d '{
  "settings": { "number_of_shards": 1, "number_of_replicas": 0 },
  "mappings": {
    "properties": {
      "id": { "type": "integer" },
      "name": { "type": "keyword" },
      "dept_id": { "type": "integer" },
      "salary": { "type": "double" }
    }
  }
}' && echo ""

curl -s -X PUT "$BASE_URL/bounty-right" -H 'Content-Type: application/json' -d '{
  "settings": { "number_of_shards": 1, "number_of_replicas": 0 },
  "mappings": {
    "properties": {
      "dept_id": { "type": "integer" },
      "dept_name": { "type": "keyword" },
      "location": { "type": "keyword" }
    }
  }
}' && echo ""

curl -s -X POST "$BASE_URL/bounty-left/_bulk?refresh=true" \
  -H 'Content-Type: application/x-ndjson' -d '
{"index":{}}
{"id":1,"name":"Alice","dept_id":10,"salary":75000.0}
{"index":{}}
{"id":2,"name":"Bob","dept_id":20,"salary":85000.0}
{"index":{}}
{"id":3,"name":"Carol","dept_id":10,"salary":65000.0}
{"index":{}}
{"id":4,"name":"Dave","dept_id":null,"salary":90000.0}
{"index":{}}
{"id":5,"name":"Eve","dept_id":30,"salary":70000.0}
' && echo ""

curl -s -X POST "$BASE_URL/bounty-right/_bulk?refresh=true" \
  -H 'Content-Type: application/x-ndjson' -d '
{"index":{}}
{"dept_id":10,"dept_name":"Engineering","location":"NYC"}
{"index":{}}
{"dept_id":20,"dept_name":"Marketing","location":"SF"}
{"index":{}}
{"dept_id":40,"dept_name":"HR","location":"CHI"}
' && echo ""

###############################################################################
# 5. Empty index for zero-row edge cases
###############################################################################
echo ""
echo "--- Creating bounty-empty index ---"
curl -s -X DELETE "$BASE_URL/bounty-empty" 2>/dev/null || true
curl -s -X PUT "$BASE_URL/bounty-empty" -H 'Content-Type: application/json' -d '{
  "settings": { "number_of_shards": 1, "number_of_replicas": 0 },
  "mappings": {
    "properties": {
      "id": { "type": "integer" },
      "name": { "type": "keyword" },
      "value": { "type": "double" }
    }
  }
}' && echo ""

echo ""
echo "=== Test data setup complete ==="
echo "Indices created:"
curl -s "$BASE_URL/_cat/indices/bounty-*,logs-*?v&h=index,docs.count,store.size" 2>/dev/null
echo ""
