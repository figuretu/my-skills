---
name: code-review
description: "语言无关的 Code Review。支持本地变更和远程 PR。运行时自动发现已安装的语言/框架最佳实践 skill 并加载其规范。当存在 spec/需求文档时，同时审查实现完整性并批判性分析 spec 本身的缺陷。适用场景：(1) 用户要求 review 本地代码变更，(2) 用户提供 PR 编号或 URL 要求 review，(3) 用户提到 code review、审查代码等意图，(4) cooperation-with-codex 流程中需要结构化 review。"
---

# Code Review

语言无关的结构化 Code Review，支持本地变更和远程 PR。

## 工作流程

### Step 1: 确定审查目标

判断审查对象类型：

- **远程 PR**: 用户提供 PR 编号或 URL → 使用 `gh` 命令获取信息
- **本地变更**: 用户要求 review 本地代码 → 使用 `git` 命令获取 diff

如果用户未明确指定，检查当前工作区状态后询问。

### Step 2: 扫描可用的最佳实践 Skill

检查 system-reminder 中的 skills 列表，识别与编码规范/最佳实践相关的 skill（如 go-coding、go-cli-tui 等）。

**记住这些 skill 名称**，后续读 diff 时按需加载。此步骤仅做识别，不立即读取 skill 内容。

### Step 3: 准备上下文

根据审查目标类型获取变更内容：

**远程 PR:**
```bash
# 获取 PR 基本信息（标题、描述、分支、文件列表）
gh pr view <number> --json title,body,baseRefName,headRefName,files
# 获取已有评论和 review 意见，理解讨论历史
gh pr view <number> --comments
# 获取 diff
gh pr diff <number>
# 如需本地查看代码，checkout PR 分支
gh pr checkout <number>
```

阅读 PR 描述和已有评论，理解变更目标和讨论历史，避免重复已有反馈。

**本地变更:**
```bash
git status
# 已暂存的变更
git diff --cached
# 未暂存的变更（如果有）
git diff
# 如果用户指定了 commit 范围
git diff <base>..<head>
```

### Step 4: 需求与文档分析（条件执行）

**触发条件**（满足任一即执行）：
- 用户提及 spec、需求文档、设计文档
- PR 描述中引用了 spec 或需求
- diff 中包含文档文件（.md、spec、design doc 等）

**执行内容：**
1. 检查 diff 中的文档变更
2. 按需读取项目中的相关文档（docs/、README、spec 文件）理解上下文
3. 产出两部分分析：

**实现完整性 Checklist:**
- [ ] 需求中的每个功能点是否都有对应实现
- [ ] 边界条件和异常场景是否已处理
- [ ] 文档描述与实际实现是否一致

**Spec/需求文档缺陷分析:**
- 歧义：描述模糊、可多种理解的条款
- 缺失：未覆盖的场景、缺少的约束条件
- 矛盾：文档内部或与实现之间的冲突
- 可测试性：需求是否可验证、验收标准是否明确
- 安全/性能盲区：未提及的安全要求或性能约束

**未触发时跳过此步骤。**

### Step 5: 代码审查分析

按优先级逐项审查，参考 [review-checklist.md](references/review-checklist.md)：

| 优先级 | 维度 | 说明 |
|--------|------|------|
| CRITICAL | Security | 注入、认证、敏感数据、依赖安全 |
| HIGH | Correctness | 逻辑、错误处理、边界、竞态 |
| HIGH | Performance | 查询、资源管理、算法效率 |
| MEDIUM | Maintainability | 清晰度、抽象、重复 |
| MEDIUM | Testing | 覆盖率、测试质量 |

**最佳实践 Skill 加载：** 读 diff 代码时，如果发现代码与 Step 2 记住的 skill 关联（如 `.go` 文件 → go-coding），则读取该 skill 的 SKILL.md 和相关 references，作为 review 的补充标准。无关联 skill 时仅使用通用 checklist。

### Step 6: 输出审查结果

使用以下结构化格式输出：

```
## Summary
[一句话概括变更内容和整体评价]

## Spec Analysis (如果 Step 4 触发)
### 实现完整性
[checklist 结果]

### Spec 缺陷
[发现的问题]

## Findings

### Critical
[必须修复才能合并的问题，含具体文件和行号]

### Improvements
[建议改进但不阻塞合并的问题]

### Nitpicks
[风格、命名等细微建议]

## Verdict
[Approved ✅ / Request Changes 🔄 / Needs Discussion 💬]
[一句话说明理由]
```

**输出规则：**
- 每个 finding 必须包含具体文件路径和行号
- 引用相关代码片段
- 给出修改建议而非仅指出问题
- 空的 section 不输出（如无 Critical 则省略该节）

### Step 7: 收尾

- **远程 PR**: 询问用户是否需要切回原分支（`gh pr checkout` 会切换分支）
- **本地变更**: 无额外操作
