---
name: spec-review-with-codex
description: "Claude 与 Codex 双视角 Spec Review。并行审查需求/设计产出物（proposal、specs、design、tasks 等），对比分析后输出综合报告到 `.ai_docs/review/`。适用场景：(1) 用户在 opsx:ff 后要求审查 spec 质量，(2) 用户要求双 agent 协作审查需求或设计文档，(3) 用户手动明确触发该 skill 并传入目标目录。codex 永远不使用本 skill。"
---

# Spec Review with Codex

Claude 与 Codex 双视角并行审查需求/设计产出物，对比分析后输出综合报告。聚焦设计层面的缺漏和盲点。

## 参考资料

- `references/codex-exec-guide.md` — Codex CLI exec 命令参考。`codex exec` 失败时按需读取。

## 输入

`/spec-review-with-codex` 之后的参数是目标目录路径。支持两种形式：

1. **OpenSpec 变更目录**：如 `openspec/changes/error-types-preconditions/`，自动识别其中的 proposal.md、specs/、design.md、tasks.md
2. **任意文档目录**：包含需求/设计文档的目录，递归扫描 `.md` 文件

如未提供参数，使用 AskUserQuestion 询问目标目录。

## 审查检查清单

Claude 和 Codex 共用同一套审查标准。构造 Codex prompt 时，将本节内容完整嵌入。

### CRITICAL: 完整性 (Completeness)

- 需求是否覆盖了所有用户场景（正常流程 + 异常流程）？
- 错误处理和边界条件是否有对应需求？
- 是否遗漏了非功能性需求（性能、安全、可观测性）？
- 并发和竞态场景是否被考虑？

### HIGH: 一致性 (Consistency)

- 需求之间是否存在矛盾或冲突？
- proposal 的范围与 specs 的需求列表是否对齐？
- design 的技术决策是否满足 specs 中的所有需求？
- tasks 是否覆盖了 specs 和 design 中的所有要求？
- 术语使用是否一致（同一概念是否用了不同名称）？

### HIGH: 清晰度 (Clarity)

- 每条需求是否可验证（有明确的通过/失败标准）？
- 是否存在模糊用语（"适当的"、"合理的"、"尽可能"）？
- 接口契约（输入/输出/错误）是否明确定义？
- 是否有足够的示例或场景说明？

### MEDIUM: 可行性 (Feasibility)

- 技术方案是否可行？是否存在未验证的假设？
- 是否考虑了替代方案并记录了取舍？
- 依赖项（外部库、系统能力）是否已确认可用？
- 复杂度评估是否合理？

### MEDIUM: 范围 (Scope)

- 变更边界是否清晰？是否有范围蔓延？
- 是否有需求超出了 proposal 定义的范围？
- 影响分析是否完整（对现有功能的影响）？

### LOW: 可维护性 (Maintainability)

- 设计是否过度工程化？
- 是否为未来扩展留了合理的空间（但不过度设计）？
- 文档是否足够支撑后续开发者理解上下文？

## 工作流程

### 1. 识别审查目标

确认目标目录路径存在，扫描目录结构，列出待审查文件。生成摘要标识 `summary_id`（如 `spec-error-types`）。

### 2. 并行启动审查

同时执行以下两件事：

**Codex 审查（后台）：**

```bash
mkdir -p .ai_docs/codex_call .ai_docs/review
codex exec --full-auto -m gpt-5.3-codex -c model_reasoning_effort=xhigh \
  -o .ai_docs/codex_call/spec-review-result.md \
  -C "<workdir>" \
  "<prompt>" \
  2>.ai_docs/codex_call/spec-review.log
```

Codex prompt 构造规则：
- 告知审查目标目录路径，与用户给的路径保持一致
- 要求不调用 OpenSpec 相关 skill，不修改任何文件
- **完整嵌入「审查检查清单」章节内容**，要求按相同维度和优先级输出结构化审查结果
- 如果是 OpenSpec 变更目录，要求执行跨产出物对齐检查
- 使用 Bash `run_in_background` 启动，不限时

**Claude 审查（前台）：**

1. 读取目标目录下所有产出物文件
2. 按「审查检查清单」中的优先级逐项审查
3. 如果是 OpenSpec 变更目录，执行跨产出物对齐检查：
   - proposal 定义的 capabilities 是否都有对应 specs
   - specs 中的需求是否都在 design 中有技术方案
   - design 中的决策是否都在 tasks 中有实现步骤
   - tasks 是否有"孤立任务"（无法追溯到 specs 中的需求）

### 3. 对比分析与综合

等待 Codex 完成，读取 `.ai_docs/codex_call/spec-review-result.md`。

对比两份审查结果，写入 `.ai_docs/review/<summary_id>-spec-review.md`：

```markdown
# Spec Review Report: <标题>

## 审查目标
[目标目录、产出物列表、项目上下文]

## Claude Review
[Claude 完整审查结果，按优先级分组]

## Codex Review
[Codex 完整审查结果]

## 对比分析

### 共同发现
[两方都指出的问题，可信度最高]

### Claude 独有发现
[仅 Claude 发现的问题]

### Codex 独有发现
[仅 Codex 发现的问题]

## 综合结论
[综合两方意见的最终评价、关键改进建议、优先级排序]
```

向用户展示报告摘要，并告知完整报告路径。
