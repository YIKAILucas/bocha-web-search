#!/usr/bin/env bash
set -euo pipefail

# 统一 Bocha API 调用器（curl）
# 示例：
#   bash scripts/bocha.sh web --query "中国最火 app" --count 10 --freshness oneYear --summary true
#   bash scripts/bocha.sh ai --query "总结趋势" --raw-json '{"count":8,"summary":true}'
#   bash scripts/bocha.sh rerank --query "xxx" --raw-json '{"documents":["a","b"]}'

MODE="${1:-}"
if [[ -z "$MODE" ]]; then
  echo "用法: bocha.sh <web|ai|agent|rerank> [参数]" >&2
  exit 1
fi
shift || true

QUERY=""
COUNT="10"
FRESHNESS="noLimit"
SUMMARY="true"
PAGE=""
OFFSET=""
LANGUAGE=""
REGION=""
SITE=""
RAW_JSON=""
TIMEOUT="30"
PRETTY="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --query) QUERY="${2:-}"; shift 2 ;;
    --count) COUNT="${2:-}"; shift 2 ;;
    --freshness) FRESHNESS="${2:-}"; shift 2 ;;
    --summary) SUMMARY="${2:-}"; shift 2 ;;
    --page) PAGE="${2:-}"; shift 2 ;;
    --offset) OFFSET="${2:-}"; shift 2 ;;
    --language) LANGUAGE="${2:-}"; shift 2 ;;
    --region) REGION="${2:-}"; shift 2 ;;
    --site) SITE="${2:-}"; shift 2 ;;
    --raw-json) RAW_JSON="${2:-}"; shift 2 ;;
    --timeout) TIMEOUT="${2:-}"; shift 2 ;;
    --pretty) PRETTY="true"; shift ;;
    *) echo "未知参数: $1" >&2; exit 1 ;;
  esac
done

if [[ "$MODE" != "rerank" && -z "$QUERY" ]]; then
  echo "非 rerank 模式必须传 --query" >&2
  exit 1
fi

if [[ "$SUMMARY" != "true" && "$SUMMARY" != "false" ]]; then
  echo "--summary 只能是 true/false" >&2
  exit 1
fi

if ! [[ "$COUNT" =~ ^[0-9]+$ ]]; then
  echo "--count 必须是整数" >&2
  exit 1
fi

# 温和限幅，防止误传超大值
if (( COUNT < 1 )); then COUNT=1; fi
if (( COUNT > 50 )); then COUNT=50; fi

if ! [[ "$TIMEOUT" =~ ^[0-9]+$ ]]; then
  echo "--timeout 必须是整数秒" >&2
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

case "$MODE" in
  web) ENDPOINT="https://api.bochaai.com/v1/web-search" ;;
  ai) ENDPOINT="https://api.bochaai.com/v1/ai-search" ;;
  agent) ENDPOINT="https://api.bochaai.com/v1/agent-search" ;;
  rerank) ENDPOINT="https://api.bochaai.com/v1/semantic-reranker" ;;
  *) echo "不支持的模式: $MODE（仅支持 web|ai|agent|rerank）" >&2; exit 1 ;;
esac

BASE_JSON="$(python3 - <<'PY' "$QUERY" "$COUNT" "$FRESHNESS" "$SUMMARY" "$PAGE" "$OFFSET" "$LANGUAGE" "$REGION" "$SITE"
import json,sys
query,count,freshness,summary,page,offset,language,region,site=sys.argv[1:10]
obj={}
if query: obj['query']=query
obj['count']=int(count)
obj['freshness']=freshness
obj['summary']=(summary=='true')
if page: obj['page']=page
if offset: obj['offset']=offset
if language: obj['language']=language
if region: obj['region']=region
if site: obj['site']=site
print(json.dumps(obj, ensure_ascii=False))
PY
)"

if [[ -n "$RAW_JSON" ]]; then
  PAYLOAD="$(python3 - <<'PY' "$BASE_JSON" "$RAW_JSON"
import json,sys
base=json.loads(sys.argv[1])
try:
  raw=json.loads(sys.argv[2])
except Exception as e:
  raise SystemExit(f"--raw-json 不是合法 JSON: {e}")
base.update(raw)
print(json.dumps(base, ensure_ascii=False))
PY
)"
else
  PAYLOAD="$BASE_JSON"
fi

RESP="$(curl --silent --show-error --fail \
  --location "$ENDPOINT" \
  --max-time "$TIMEOUT" \
  --header "Authorization: Bearer ${API_KEY}" \
  --header 'Content-Type: application/json' \
  --data "$PAYLOAD")"

if [[ "$PRETTY" == "true" ]] && command -v jq >/dev/null 2>&1; then
  printf '%s' "$RESP" | jq .
else
  printf '%s\n' "$RESP"
fi
