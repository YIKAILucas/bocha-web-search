#!/usr/bin/env python3
import json
import os
import sys
from pathlib import Path
from urllib import request, error

API_URL = "https://api.bochaai.com/v1/web-search"


def load_api_key() -> str:
    env_key = os.getenv("BOCHA_API_KEY", "").strip()
    if env_key:
        return env_key

    config_path = Path(__file__).resolve().parent.parent / "config.json"
    if config_path.exists():
        try:
            data = json.loads(config_path.read_text(encoding="utf-8"))
            key = str(data.get("apiKey", "")).strip()
            if key:
                return key
        except Exception:
            pass

    raise RuntimeError("缺少 API Key。请设置 BOCHA_API_KEY 或在 skills/bocha-web-search/config.json 中配置 apiKey。")


def normalize_results(raw: dict, query: str):
    items = raw.get("results") or raw.get("data") or raw.get("items") or []
    normalized = []

    for it in items:
        if not isinstance(it, dict):
            continue
        title = it.get("title") or it.get("name") or ""
        url = it.get("url") or it.get("link") or ""
        snippet = it.get("snippet") or it.get("summary") or it.get("description") or ""
        source = it.get("source") or it.get("site") or ""
        publish_time = it.get("publish_time") or it.get("time") or it.get("date") or ""
        normalized.append(
            {
                "title": title,
                "url": url,
                "snippet": snippet,
                "source": source,
                "publish_time": publish_time,
            }
        )

    return {
        "query": query,
        "total": len(normalized),
        "results": normalized,
    }


def search(query: str, top_k: int, api_key: str):
    payload = json.dumps({"query": query, "count": top_k}).encode("utf-8")
    req = request.Request(
        API_URL,
        data=payload,
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
        method="POST",
    )

    try:
        with request.urlopen(req, timeout=30) as resp:
            text = resp.read().decode("utf-8", errors="ignore")
            data = json.loads(text)
            return normalize_results(data, query)
    except error.HTTPError as e:
        body = e.read().decode("utf-8", errors="ignore")
        raise RuntimeError(f"请求失败: HTTP {e.code} {body}")
    except error.URLError as e:
        raise RuntimeError(f"网络错误: {e}")


def main():
    if len(sys.argv) < 2:
        print("用法: python3 scripts/search.py \"查询词\" [结果条数1-20]", file=sys.stderr)
        sys.exit(1)

    query = sys.argv[1].strip()
    if not query:
        print("查询词不能为空", file=sys.stderr)
        sys.exit(1)

    top_k = 10
    if len(sys.argv) >= 3:
        try:
            top_k = int(sys.argv[2])
        except ValueError:
            print("结果条数必须是整数", file=sys.stderr)
            sys.exit(1)
    top_k = max(1, min(top_k, 20))

    try:
        api_key = load_api_key()
        result = search(query, top_k, api_key)
        print(json.dumps(result, ensure_ascii=False, indent=2))
    except Exception as e:
        print(json.dumps({"error": str(e)}, ensure_ascii=False), file=sys.stderr)
        sys.exit(2)


if __name__ == "__main__":
    main()
