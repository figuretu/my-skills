---
name: code-review-with-codex
description: "Claude 与 Codex 双视角 Code Review。并行执行 Claude review 和 Codex review（通过 codex exec CLI），对比分析后输出综合报告到 `.ai_docs/review/`。适用场景：(1) 用户要求双 agent 协作 review，(2) 用户手动明确触发该 skill。codex 永远不使用本 skill。"
---

# Code Review with Codex

Claude 与 Codex 双视角并行 Code Review，对比分析后输出综合报告。

## 参考资料

- `references/codex-exec-guide.md` — Codex CLI exec 命令参考。`codex exec` 失败时按需读取。
- `references/review-checklist.md` — 通用代码审查检查清单（Security / Correctness / Performance / Maintainability / Testing）。Claude 审查时按需读取作为审查基线。

## 工作流程

### Phase 0: 前置决策（Subagent）

使用 Task tool 启动一个 general-purpose subagent，prompt 中注入：

1. 用户的审查请求原文
2. system-reminder 中所有 skill 的 name + description 列表（原文复制）
3. 用户提供的 spec/需求文档路径（如有）

subagent 执行以下任务：

**A. 判断 diff 获取方式：**
- 分析用户请求（是否提供 PR 编号/URL，还是要求 review 本地变更）
- 运行 `git status` 和 `git branch` 了解当前状态
- 确定具体的 bash 命令序列来获取 diff
- 生成一个简短摘要标识（如 `pr-123` 或 `feat-auth`）

**B. 匹配编码规范 skill：**
- 从传入的 skill 列表中，识别编码规范/最佳实践类 skill
- 获取 diff 内容（使用 A 中确定的命令），通读变更代码，识别涉及的语言和框架
- 综合文件扩展名和代码中实际使用的框架/库来匹配 skill（如 `.go` 文件 → go-coding，代码中使用 Bubble Tea → go-cli-tui）
- 返回匹配到的 skill 名称列表

subagent MUST 以如下格式返回结果：

```
diff_type: local | pr
diff_commands:
  - <command 1>
  - <command 2>
summary_id: <摘要标识>
matched_skills: [skill-name-1, skill-name-2]
pr_context: <PR 标题/描述，仅 PR 模式时提供>
```

### Phase 1: 启动 Codex + 准备 Claude 上下文

Phase 0 完成后，立即并行执行以下两件事：

#### 1a. 启动 Codex Review（后台）

准备 Codex review 命令：

```bash
mkdir -p .ai_docs/codex_call .ai_docs/review
codex exec --full-auto -m gpt-5.3-codex -c model_reasoning_effort=xhigh \
  -o .ai_docs/codex_call/code-review-result.md \
  -C "<workdir>" \
  "使用 \$code-review skill 对当前工作区的代码变更进行审查。审查时 MUST 加载以下编码规范 skill 作为审查标准：<matched_skills 列表>。使用中文输出审查报告。<补充上下文：diff 范围、PR 信息、spec 路径等>" \
  2>.ai_docs/codex_call/code-review.log
```

- 使用 Bash `run_in_background` 启动
- prompt 中 MUST 显式列出 Phase 0 匹配到的 skill 名称
- 如果用户提供了 spec/需求文档，MUST 在 prompt 中告知 Codex 文档路径
- Bash timeout 不限时。

#### 1b. 准备 Claude 审查上下文

**MUST 全部完成后才能进入 Phase 2。跳过任何子步骤都会导致审查质量下降。**

1. 执行 Phase 0 返回的 diff 命令，获取完整 diff
2. 如果 `matched_skills` 非空，逐个读取对应 skill 的 SKILL.md 及其 `references/` 目录下的关键文件，提取语言/框架特定的审查标准
3. 读取本 skill 的 `references/review-checklist.md`，作为通用工程审查基线
4. 检查是否存在 spec/需求文档（用户提供、PR 描述中引用、diff 中包含 .md/spec/design doc 等）

完成后，上下文中应包含：diff 全文、通用 checklist、语言特定标准、spec（如有）。

### Phase 2: Claude Review（前台执行）

基于 Phase 1b 加载的全部标准（通用 checklist + 编码规范 skill）执行审查。Checklist 和编码规范作为**内部审查依据**，不作为输出结构。

**只关注发现的问题**，按以下优先级维度审查：

| 优先级 | 维度 | 说明 |
|--------|------|------|
| CRITICAL | Security | 注入、认证、敏感数据、依赖安全 |
| HIGH | Correctness | 逻辑、错误处理、边界、竞态 |
| HIGH | Performance | 查询、资源管理、算法效率 |
| MEDIUM | Maintainability | 清晰度、抽象、重复 |
| MEDIUM | Testing | 覆盖率、测试质量 |

发现的问题按三个层级记录，每层使用不同详细度：

**Critical**（必须修复）— 完整四要素：
```
### 简短标题
- **位置**: file_path:line_number
- **问题**: 具体描述（标注所属维度）
- **影响**: 不修复的后果
- **建议**: 具体修复方案
```

**Improvements**（建议改进）— 三要素：
```
### 简短标题
- **位置**: file_path:line_number
- **问题**: 具体描述
- **理由**: 为什么值得改（可选）
- **建议**: 具体改进方案
```

**Nitpicks**（品味级建议）— 轻量一行：
```
- `file_path:line_number` — 建议内容
```

无问题的层级不出现在输出中。

**Spec 分析（条件执行）：** 如果 Phase 1b 发现了 spec/需求文档：
- 实现完整性：需求中的每个功能点是否都有对应实现
- Spec 缺陷：歧义、缺失、矛盾、可测试性、安全/性能盲区

将 Claude 审查结果暂存（不写文件，保留在上下文中）。

### Phase 3: 综合分析与报告

等待 Codex 后台任务完成，读取 `.ai_docs/codex_call/code-review-result.md` 获取 Codex 审查结果。

**交叉验证：** 对 Codex 的每条发现：
- 回到代码中验证问题是否确实存在
- 如果上下文不足，读取更多相关代码补充判断
- 评估 severity 是否合理（可升降级）
- 给出 Claude 的综合建议（可能与 Codex 建议不同）

**归并分类：** 将两份审查结果按主题归并：
- **共同发现**：同一位置/同一问题合并为一条，综合双方建议
- **Claude 独有发现**：仅 Claude 发现的问题
- **Codex 独有发现**：仅 Codex 发现的问题，附 Claude 验证结论

写入 `.ai_docs/review/<summary_id>-review.md`，格式：

```markdown
# Code Review Report: <标题>

## 审查目标
[审查对象、diff 范围]

## 共同发现
[两方都指出的问题——可信度最高，每条含综合建议]

## Claude 独有发现
[仅 Claude 发现的问题]

## Codex 独有发现
[仅 Codex 发现的问题，每条含 Claude 验证结论]

## 综合结论
[Verdict + 优先级排序的行动建议]
```

每条问题沿用 Phase 2 定义的分层格式（Critical 四要素 / Improvements 三要素 / Nitpicks 一行）。在共同发现和独有发现中按 Critical → Improvements → Nitpicks 排列。综合建议中注明与对方建议的差异（如有）。无 finding 时对应章节不输出。

向用户展示报告摘要，并告知完整报告路径。
