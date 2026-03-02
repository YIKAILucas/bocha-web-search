#!/usr/bin/env bash
set -euo pipefail

QUERY="${1:-}"
COUNT="${2:-10}"
FRESHNESS="${3:-noLimit}"
SUMMARY="${4:-true}"

if [[ -z "$QUERY" ]]; then
  echo "用法: bash scripts/search.sh \"查询词\" [count] [freshness] [summary]" >&2
  exit 1
fi

if ! [[ "$COUNT" =~ ^[0-9]+$ ]]; then
  echo "count 必须是整数" >&2
  exit 1
fi

if (( COUNT < 1 )); then COUNT=1; fi
if (( COUNT > 20 )); then COUNT=20; fi

if [[ "$SUMMARY" != "true" && "$SUMMARY" != "false" ]]; then
  echo "summary 只能是 true 或 false" >&2
  exit 1
fi

API_KEY="${BOCHA_API_KEY:-}"
if [[ -z "$API_KEY" ]]; then
  CONFIG_FILE="$(cd "$(dirname "$0")/.." && pwd)/config.json"
  if [[ -f "$CONFIG_FILE" ]]; then
    API_KEY="$(python3 - <<'PY' "$CONFIG_FILE"
import json,sys
p=sys.argv[1]
try:
  d=json.load(open(p,'r',encoding='utf-8'))
  print((d.get('apiKey') or '').strip())
except Exception:
  print('')
PY
)"
  fi
fi

if [[ -z "$API_KEY" ]]; then
  echo "缺少 API Key。请设置 BOCHA_API_KEY 或在 skills/bocha-web-search/config.json 中配置 apiKey。" >&2
  exit 2
fi

curl --silent --show-error --fail \
  --location 'https://api.bochaai.com/v1/web-search' \
  --header "Authorization: Bearer ${API_KEY}" \
  --header 'Content-Type: application/json' \
  --data "{\"query\":\"${QUERY//\"/\\\"}\",\"count\":${COUNT},\"freshness\":\"${FRESHNESS}\",\"summary\":${SUMMARY}}"
