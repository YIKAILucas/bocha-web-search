---
name: bocha-web-search
description: 使用博查（Bocha）Search API 进行中文优先的联网检索，返回标题、链接、摘要等结构化结果。用户提到“博查搜索/联网搜索/查一下/搜一下/最新资讯/事实核查/行业研报检索”时使用。
---

# bocha-web-search

使用博查搜索 API 做实时检索，适合中文互联网内容与行业资讯搜集。

## 前置配置

二选一：

1. 环境变量（推荐）

```bash
export BOCHA_API_KEY="你的博查API Key"
```

2. 本地配置文件（仅本机）

在技能目录创建 `config.json`：

```json
{
  "apiKey": "你的博查API Key"
}
```

## 执行命令（curl 方式）

```bash
cd skills/bocha-web-search
bash scripts/search.sh "中国最火 app 研报" 10 oneYear true
```

参数：
- 第1个参数：查询词（必填）
- 第2个参数：返回条数（可选，默认10，范围1-20）
- 第3个参数：`freshness`（可选，默认 `noLimit`，常用：`oneDay`/`oneWeek`/`oneMonth`/`oneYear`）
- 第4个参数：`summary`（可选，默认 `true`，可选 `true/false`）

## 输出格式

脚本直接输出博查 API 的原始 JSON 响应（便于后续二次处理与追溯）。

## 使用建议

1. 先用宽关键词拿全量结果（如“2025 中国移动互联网 报告”）。
2. 再加限定词做二次检索（如“QuestMobile”“CNNIC”“CTR”）。
3. 回答用户时优先引用机构来源，避免仅用自媒体榜单。
