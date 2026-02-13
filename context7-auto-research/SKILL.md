---
name: context7-auto-research
description: 通过 Context7 获取库/框架最新文档。优先使用已有知识，仅在以下场景触发：(1) 用户显式调用本 skill，(2) 使用库/框架时已有知识无法解决问题（接口不存在、参数错误、缺少解决方案、知识可能过时），主动查询最新文档。
---

# Context7 自动文档查询

通过 Context7 API 获取库/框架最新文档。
优先使用已有知识解决问题，不要因为用户提到了某个库就触发查询。

## 触发条件

### 核心原则

**已有知识优先。** 只在确实卡住时才查询 Context7。

### 场景一：用户显式调用

用户通过 `/context7-auto-research` 或明确要求查询最新文档时触发。

### 场景二：已有知识无法解决问题

使用库/框架过程中遇到以下情况时，主动触发查询：

- 不确定某个 API 是否存在或其签名/参数
- 生成的代码调用了不存在的接口或使用了错误的参数
- 对某个功能的用法缺乏信心，怀疑已过时或训练数据未覆盖
- 尝试解决问题但找不到方案，需要查阅最新文档

不触发的情况：

- 对库/框架的常见用法有充分把握
- 用户只是提到了某个库名，但问题本身可以用已有知识回答
- 常规的代码编写、配置、调试，已有知识足够应对

## 查询流程

### 第 1 步：提取库信息

从用户查询中识别：

- 库名称（如 "react"、"next.js"、"prisma"）
- 版本号（如 "React 19"、"Next.js 15"）
- 具体功能/API（如 "useEffect"、"middleware"）

### 第 2 步：搜索库

通过 Task tool 调用 context7-fetcher 子 skill：

```
Task parameters:
- subagent_type: Bash
- description: "Search Context7 for library"
- prompt: node <skill-dir>/scripts/context7-api.js search "<library-name>" "<rewritten-query>"
```

其中 `<skill-dir>` 为本 skill 的安装目录路径。
`<rewritten-query>` 为重写后的关键词查询（见下方 Query 重写规则）。

### 第 3 步：选择最佳匹配

从搜索结果中选择库，优先级：

1. 名称精确匹配
2. 最高 trust score
3. 版本匹配（如用户指定 "Next.js 15" → 优先 v15.x）
4. 官方包优先于社区 fork

### 第 4 步：获取文档

通过 Task tool 调用 context7-fetcher 子 skill：

```
Task parameters:
- subagent_type: Bash
- description: "Fetch documentation from Context7"
- prompt: node <skill-dir>/scripts/context7-api.js context "<library-id>" "<rewritten-query>"
```

### 第 5 步：整合到回答

使用获取的文档：

1. 基于最新信息准确回答
2. 包含文档中的代码示例
3. 标注相关版本
4. 提供功能/API 的上下文说明

## Helper 脚本

`scripts/context7-api.js` 提供两个命令：

```bash
# 搜索库
node scripts/context7-api.js search <libraryName> <query>

# 获取文档
node scripts/context7-api.js context <libraryId> <query>
```

### API Key 配置

支持两种方式：

1. `.env` 文件（推荐）：在 skill 目录创建 `.env`，参考 `.env.example`
2. 环境变量：`export CONTEXT7_API_KEY="your-api-key"`

优先级：环境变量 > .env 文件。未设置时使用公共速率限制（配额较低）。

获取 API Key：访问 context7.com/dashboard 注册。

## Query 重写规则

不要直接使用用户原始问题作为 query。将用户意图提炼为简洁的英文关键词短语：

- 去除口语化表达、语气词、冗余修饰
- 保留核心技术术语和功能名称
- 使用英文关键词（Context7 文档源以英文为主）

示例：

| 触发场景 | 重写后的 query |
| --- | --- |
| 用户调用：查 Next.js 15 中间件配置 | `middleware configuration` |
| 不确定 `useFormStatus` 参数 | `useFormStatus hook API` |
| Prisma `createMany` 是否支持嵌套 | `createMany nested writes` |
| 不确定 Tailwind v4 的 dark mode 写法 | `dark mode configuration` |

## 最佳实践

- query 必须经过重写（见 Query 重写规则），不要直接传递用户原始问题
- 用户指定版本时，使用版本特定的 library ID（如 `/vercel/next.js/v15.1.8`）
- 搜索无结果时告知用户并建议替代方案
- API 失败时回退到训练数据，但注明可能过时
- 不要转储整个文档，提取相关部分
- 多个库查询时，通过多个 Task 调用并行获取

## 示例工作流

### 示例 1：用户显式调用

**用户:** "/context7-auto-research Next.js 15 middleware"

1. 用户显式调用，直接触发
2. 重写 query：`middleware configuration`
3. 搜索：`search "next.js" "middleware configuration"`
4. 选择：`/vercel/next.js/v15.1.8`
5. 获取：`context "/vercel/next.js/v15.1.8" "middleware configuration"`
6. 返回最新文档内容

### 示例 2：API 不确定主动查询

**场景:** 用户要求用 React 19 的 `useFormStatus` 实现表单提交状态，
但对该 Hook 的参数和返回值不确定。

1. 识别知识缺口：`useFormStatus` 是 React 19 新增 API，训练数据可能不完整
2. 重写 query：`useFormStatus hook API`
3. 搜索：`search "react" "useFormStatus hook API"`
4. 选择：`/facebook/react/v19.0.0`
5. 获取：`context "/facebook/react/v19.0.0" "useFormStatus hook API"`
6. 基于最新文档生成准确代码

### 示例 3：解决方案卡住主动查询

**场景:** 用户使用 Prisma 遇到复杂的嵌套写入问题，
已有知识中的写法在新版本中可能已变更。

1. 尝试用已有知识解决 → 不确定 `createMany` 是否支持嵌套
2. 重写 query：`createMany nested writes`
3. 搜索：`search "prisma" "createMany nested writes"`
4. 选择：`/prisma/prisma`
5. 获取：`context "/prisma/prisma" "createMany nested writes"`
6. 基于最新文档确认正确用法
