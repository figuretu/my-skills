# AGENTS.md

This file provides guidance to Agents when working with code in this repository.

## 仓库用途 (Repository Purpose)

这个仓库用于管理 Agents 的自定义 skills。

## 语言规范 (Language Convention)

**重要**: 所有 skill 的描述必须使用中文，但专业术语保持英文。

示例：
- ✅ "下载飞书/Lark 文档到本地 Markdown 文件"
- ✅ "上传本地 Markdown 文件到飞书云文档，支持指定目标位置"
- ❌ "Download Feishu/Lark documents to local Markdown files"

## Skill 结构规范

每个 skill 应该包含：
- **名称**: 使用 kebab-case 命名（如 `upload-to-lark`, `download-lark-doc`）
- **描述**: 中文描述功能，专业术语用英文
- **适用场景**: 列出具体的使用场景，帮助 Claude 判断何时调用该 skill
- **参数**: 清晰定义输入参数和格式要求

## 开发指南

在创建或修改 skill 时：
1. 确保描述清晰、具体，包含足够的上下文信息
2. 列出明确的适用场景，使用 "(1) ... (2) ... (3) ..." 格式
3. 技术术语（如 Markdown, JSON, URL）保持英文
4. 中文描述要自然流畅，避免生硬翻译
5. 对 skill 做任何增删改后，必须同步更新 `README.md` 中的 Skills 列表
