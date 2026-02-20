---
name: code-review-with-codex
description: "Claude 与 Codex 双视角 Code Review。并行执行 Claude review（调用 code-review skill）和 Codex review（通过 codex exec CLI），对比分析后输出综合报告到 `.ai_docs/review/`。适用场景：(1) 用户要求双 agent 协作 review，(2) 用户手动明确触发该 skill。codex 永远不使用本 skill。"
---

# Code Review with Codex

Claude 与 Codex 双视角并行 Code Review，对比分析后输出综合报告。

## 参考资料

`references/codex-exec-guide.md` 包含 Codex CLI exec 命令的完整参考。当工作流程中 `codex exec` 模板命令失败后才按需读取。

## 工作流程

### Step 1: 确定审查目标

判断审查对象类型：

- **远程 PR**: 用户提供 PR 编号或 URL → 使用 `gh` 命令获取信息
- **本地变更**: 用户要求 review 本地代码 → 使用 `git` 命令获取 diff

如果用户未明确指定，检查当前工作区状态后询问。

生成一个简短摘要标识（用于报告文件名，如 PR 编号 `pr-123` 或分支名 `feat-auth`）。

### Step 2: 并行审查

同时启动两路审查：

#### 路线 A — Codex Review（后台执行）

准备 Codex review 命令：

```bash
mkdir -p .ai_docs/codex_call .ai_docs/review
codex exec --full-auto -m gpt-5.3-codex -c model_reasoning_effort=xhigh \
  -o .ai_docs/codex_call/code-review-result.md \
  -C "<workdir>" \
  "使用 /code-review skill 对当前工作区的代码变更进行审查。<补充上下文：diff 范围、PR 信息等>" \
  2>.ai_docs/codex_call/code-review.log
```

- 使用 Bash `run_in_background` 启动
- `-o` 将 Codex 最终输出写入文件
- prompt 中明确指定使用 `/code-review` skill
- Bash timeout 设为 600000ms（10 分钟）

#### 路线 B — Claude Review（前台执行）

- 检查 system-reminder 中是否有 code-review skill
- 如有，按 code-review skill 的完整工作流执行审查
- 如无，按通用 review checklist 执行
- 将 Claude 的审查结果暂存

### Step 3: 收集结果

等待 Codex 后台任务完成，读取 `.ai_docs/codex_call/code-review-result.md` 获取 Codex 的审查结果。

### Step 4: 对比分析与综合

对比两份审查结果，识别：

- **共同发现的问题** — 两方都指出的问题，可信度最高
- **Claude 独有发现** — 仅 Claude 发现的问题
- **Codex 独有发现** — 仅 Codex 发现的问题
- **综合评估** — 结合两方意见给出最终 verdict

### Step 5: 输出报告

创建目录并写入报告：

```bash
mkdir -p .ai_docs/review
```

写入 `.ai_docs/review/<摘要>-review.md`，格式：

```markdown
# Code Review Report: <标题>

## 审查目标
[审查对象描述]

## Claude Review
[Claude 完整审查结果]

## Codex Review
[Codex 完整审查结果]

## 对比分析

### 共同发现
[两方都指出的问题]

### Claude 独有发现
[仅 Claude 发现的问题]

### Codex 独有发现
[仅 Codex 发现的问题]

## 综合结论
[综合两方意见的最终评价和建议]
```

向用户展示报告摘要，并告知完整报告路径。
