---
name: spec-review-with-codex
description: "Claude 与 Codex 双视角 Spec Review（代码驱动）。并行审查需求/设计产出物（proposal、specs、design、tasks 等），各自独立探索项目代码以验证 spec 的可行性和完整性，对比分析后输出综合报告到 `.ai_docs/review/`。适用场景：(1) 用户在 opsx:ff 后要求审查 spec 质量，(2) 用户要求双 agent 协作审查需求或设计文档，(3) 用户手动明确触发该 skill 并传入目标目录。codex 永远不使用本 skill。"
---

# Spec Review with Codex

Claude 与 Codex 双视角并行审查需求/设计产出物，对比分析后输出综合报告。核心原则：**代码驱动审查**——两个 agent 各自独立探索项目代码，从不同视角验证 spec 是否切合当前代码实际。

## 参考资料

- `references/codex-exec-guide.md` — Codex CLI exec 命令参考。`codex exec` 失败时按需读取。

## 输入

`/spec-review-with-codex` 之后的参数是目标目录路径。支持两种形式：

1. **OpenSpec 变更目录**：如 `openspec/changes/error-types-preconditions/`，自动识别其中的 proposal.md、specs/、design.md、tasks.md
2. **任意文档目录**：包含需求/设计文档的目录，递归扫描 `.md` 文件

如未提供参数，使用 AskUserQuestion 询问目标目录。

## 代码探索原则

审查不能只看文档。Claude 和 Codex 必须各自独立探索项目代码，以代码现状为基准评判 spec。

探索范围（按 spec 涉及的模块按需执行）：

- **项目元信息**：AGENTS.md、CLAUDE.md、go.mod/package.json 等，了解项目架构、约定和依赖
- **相关模块代码**：spec 涉及的包/模块的现有实现，理解当前架构和模式
- **接口与类型定义**：spec 引用或将修改的接口、类型、数据结构
- **测试代码**：现有测试的覆盖范围和测试模式，判断 spec 的测试策略是否合理
- **相似功能**：项目中已有的类似功能实现，判断 spec 是否复用了现有模式

不要预先汇总代码摘要。让每个 agent 自行决定探索路径和深度，以获得独立视角。

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

### HIGH: 代码对齐 (Code Alignment)

需要探索项目代码后才能回答的问题：

- spec 提出的架构/模式是否与项目现有架构一致？是否引入了不必要的新模式？
- 项目中是否已有可复用的组件、工具函数或模式？spec 是否充分利用了它们？
- spec 涉及的修改是否会破坏现有功能？影响面是否被完整识别？
- spec 中引用的接口、类型、模块是否真实存在？签名是否匹配？
- 技术方案是否符合项目已有的编码约定和最佳实践（命名、错误处理、日志、测试等）？
- 依赖项（外部库、框架版本）是否与项目当前依赖兼容？

### HIGH: 清晰度 (Clarity)

- 每条需求是否可验证（有明确的通过/失败标准）？
- 是否存在模糊用语（"适当的"、"合理的"、"尽可能"）？
- 接口契约（输入/输出/错误）是否明确定义？
- 是否有足够的示例或场景说明？

### MEDIUM: 可行性 (Feasibility)

- 技术方案在当前代码基础上是否可行？是否存在未验证的假设？
- 是否考虑了替代方案并记录了取舍？是否有更简单的实现路径被忽略？
- 依赖项（外部库、系统能力）在项目中是否已确认可用或易于引入？
- 复杂度评估是否合理？是否有过度工程化的迹象？
- 是否存在需要大规模重构现有代码才能实现的隐含前提？

### MEDIUM: 范围 (Scope)

- 变更边界是否清晰？是否有范围蔓延？
- 是否有需求超出了 proposal 定义的范围？
- 影响分析是否完整（对现有功能的影响）？

### LOW: 可维护性 (Maintainability)

- 设计是否过度工程化？
- 是否为未来扩展留了合理的空间（但不过度设计）？
- 文档是否足够支撑后续开发者理解上下文？

## 问题陈述格式

Claude 和 Codex 的审查报告中，每个发现的问题必须按以下四要素结构化陈述：

1. **位置**：问题出现在哪个文件/章节/需求项（给出具体引用）
2. **问题**：问题是什么，属于哪个检查维度（如 Completeness / Code Alignment）
3. **影响**：如果不修复，会导致什么后果
4. **建议**：具体的修复或改进建议

构造 Codex prompt 时，将本节内容完整嵌入，要求 Codex 按相同格式输出。

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
- **完整嵌入「代码探索原则」和「审查检查清单」章节内容**，要求按相同维度和优先级输出结构化审查结果
- **明确要求 Codex 独立探索项目代码**：读取项目元信息（AGENTS.md 等）、探索 spec 涉及的现有模块代码、验证 spec 中引用的接口和类型是否真实存在
- **要求 Codex 使用中文输出审查报告**
- 如果是 OpenSpec 变更目录，要求执行跨产出物对齐检查
- 使用 Bash `run_in_background` 启动，不限时

**Claude 审查（前台）：**

Claude 使用中文进行审查并输出结果。

1. 读取目标目录下所有产出物文件
2. **探索项目代码**：按「代码探索原则」独立探索 spec 涉及的项目代码，重点关注现有架构、模式、接口定义和相关模块实现
3. 按「审查检查清单」中的优先级逐项审查（包括「代码对齐」维度）
4. 如果是 OpenSpec 变更目录，执行跨产出物对齐检查：
   - proposal 定义的 capabilities 是否都有对应 specs
   - specs 中的需求是否都在 design 中有技术方案
   - design 中的决策是否都在 tasks 中有实现步骤
   - tasks 是否有"孤立任务"（无法追溯到 specs 中的需求）

### 3. 对比分析与综合

等待 Codex 完成，读取 `.ai_docs/codex_call/spec-review-result.md`。

对比两份审查结果，**使用中文**写入 `.ai_docs/review/<summary_id>-spec-review.md`。

对比分析规则：
- 将两份报告中的问题按主题归并（同一位置/同一问题的合并为一条）
- 每个问题综合双方的建议，给出最终建议
- 如果某个问题的上下文不足以给出可靠建议（如一方指出了问题但缺少代码层面的验证），**回到代码中补充探索**，获取足够上下文后再给出建议
- 对 Codex 独有发现，回到代码/文档验证后再给出综合建议
- 不要简单罗列双方原文，要做真正的综合判断

报告结构：

```markdown
# Spec Review Report: <标题>

## 审查目标
[目标目录、产出物列表、项目上下文]

## 共同发现
[两方都指出的问题——可信度最高，每条含综合建议]

## Claude 独有发现
[仅 Claude 发现的问题]

## Codex 独有发现
[仅 Codex 发现的问题，每条含 Claude 验证结论和综合建议]

## 综合结论
[最终评价、关键改进建议、优先级排序]
```

每条问题沿用「问题陈述格式」章节定义的四要素结构，按 severity 从高到低排列。无 finding 时对应章节不输出。

向用户展示报告摘要，并告知完整报告路径。
