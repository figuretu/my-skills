# Codex 独立分析腿

Codex 分析腿是 PR walkthrough 的可选独立视角。它只产出分析素材，不修改代码、不生成最终走查文档，也不执行 code review。

## 启动条件

- 默认不启动。
- 用户点名 Codex / 双视角时启动。
- diff 超过约 5,000 行时，向用户询问一次是否增加 Codex 独立分析腿；用户拒绝则不启动。

## 后台启动

确认工作目录、diff 基线和走查 slug 后，创建输出目录并使用后台执行：

```bash
mkdir -p ".ai_docs/pr-reads/<slug>"
codex exec --full-auto -m gpt-5.6-sol -c model_reasoning_effort=xhigh \
  -o ".ai_docs/pr-reads/<slug>/codex-result.md" \
  -C "<workdir>" \
  "<prompt>" \
  2>".ai_docs/pr-reads/<slug>/codex-exec.log"
```

通过 Bash 的后台执行能力启动，不阻塞主流程。`codex-result.md` 是交付给主 agent 的唯一结果文件；stderr 日志只用于异步诊断，不作为分析结论来源。

## Prompt 要求

Prompt 必须明确告诉 Codex：

- 走查目标（本地分支或 PR）、diff 基线、工作目录和输出语言（中文）。
- 先读取项目元信息（`AGENTS.md`、`CLAUDE.md`、项目 manifest 等），再完整读取 diff。
- 独立探索 diff 涉及的现有模块、接口、类型、数据流、测试和相似实现；不要只根据 diff 猜测 before 状态。
- 产出面向理解的素材：before/after 结构、关键用户旅程、跨模块调用链、状态变化、可观察的排查路标，以及需要主 agent 回代码核实的疑点。
- 不调用其他审查 skill，不修改任何文件，不把风格偏好当成问题。

要求 Codex 全量覆盖目标范围，并在每条结论中给出文件或模块级定位。代码片段只能作为主 agent 的定位线索，最终文档中的代码仍须由主 agent 亲自读取和裁剪。

## 结果吸收

主流程继续称重、精读和写作，不等待 Codex 才开始。Codex 完成后读取 `codex-result.md`，与主 agent 的发现逐项对比：

1. 共同发现直接作为高置信度素材。
2. 独有发现回到代码和 diff 核实，确认后补入对应旅程、心智模型补丁或风险地图。
3. 矛盾结论以代码现状为准，不能把 Codex 输出原文直接当成事实。

在第七步综合修订时完成吸收，并在交付摘要中说明是否启动过 Codex 分析腿。
