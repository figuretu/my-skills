---
name: context7-fetcher
description: Context7 API 调用子任务（内部使用），通过 fork context 独立执行 API 请求以减少 Token 消耗。
version: 1.0.0
allowed-tools: Bash
context: fork
---

# Context7 Fetcher 子 Skill

> 内部子 skill，由 `context7-auto-research` 主 skill 通过 Task tool 调用。

## 用途

独立执行 Context7 API 调用，使用 `context: fork` 避免携带主对话上下文，减少 Token 消耗。

## 接收参数

通过 Task tool 的 prompt 参数接收完整命令：

1. **搜索库**: `node <skill-dir>/scripts/context7-api.js search <libraryName> <query>`
2. **获取文档**: `node <skill-dir>/scripts/context7-api.js context <libraryId> <query>`

## 执行流程

1. 执行 context7-api.js 脚本
2. 直接返回 API 响应的 JSON 数据
