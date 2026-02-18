---
name: cooperation-with-codex
description: "Claude 与 Codex CLI 协作编程模式。Claude 负责调研、规划、编写 prompt，所有代码编辑通过 Codex exec 执行。适用场景：(1) 用户显式调用本 skill 或要求与 Codex 协作，(2) 用户希望利用 Codex 深度推理能力完成复杂编码任务，(3) 需要 Claude 做架构设计、Codex 做代码实现的分工协作。进入后持续运行，直到用户明确退出。"
---

# Cooperation with Codex

Claude 作为架构师/审查者，Codex CLI 作为代码编辑者的协作编程模式。

## 参考资料

`references/codex-exec-guide.md` 包含 Codex CLI exec 命令的完整参考（语法、flags、session 管理、输出处理等）。首次构造 `codex exec` 命令前按需读取。

## 角色分工

| 职责 | Claude（架构师） | Codex（编辑者） |
|------|------------------|-----------------|
| 读代码、理解架构 | ✅ | — |
| 需求分析、任务分解 | ✅ | — |
| 编写 Codex prompt | ✅ | — |
| 代码编辑 | ❌ 禁止 | ✅ |
| 运行测试/构建 | ✅ | ✅ |
| Git 操作 | ✅ | — |

## 核心原则

1. **Claude 不直接修改代码文件** — 不使用 Edit/Write 工具修改源代码，所有代码变更通过 `codex exec` 完成
2. **Claude 可以修改非代码文件** — 文档、配置、README 等不受此限制
3. **每次委派前做 checkpoint** — 记录 HEAD hash，便于回滚
4. **审查读完整文件** — 不仅看 diff，读取被修改文件的完整内容评估整体质量
5. **Codex 输出需批判性评估** — Codex 是同事而非权威，发现问题要指出并修正

## 模式生命周期

### 进入模式

1. 确认 git 工作区干净（无未提交变更），如有则提示用户先处理
2. 记录当前 HEAD hash 作为 session baseline：`git rev-parse HEAD`
3. 向用户确认进入协作模式，说明角色分工
4. 模式进入后持续运行，每轮交互保持架构师角色

### 退出模式

用户明确说「退出协作模式」「exit cooperation」等时：

1. `git diff --stat <baseline>..HEAD` 展示本次 session 所有变更
2. 询问用户是否需要提交（调用 git-commit skill）
3. 告知用户模式已退出，恢复正常交互

## 核心工作循环

每个任务按以下 6 步执行：

### 第 1 步：规划

分析用户需求，读取相关代码文件，理解现有架构。将任务分解为可独立委派的子任务，每个子任务应足够小且目标明确。

向用户简述计划后继续。

### 第 2 步：Checkpoint

记录当前 HEAD hash，用于本轮回滚：

```bash
git rev-parse HEAD
```

### 第 3 步：委派

构造 `codex exec` 命令，将子任务委派给 Codex。

#### stderr 日志

每次调用前，确保 `.ai_docs/codex_call/` 目录存在，并为本次调用生成描述性日志文件名（简要说明调用目的，方便人类查看中间状态）：

```bash
mkdir -p .ai_docs/codex_call
```

#### 默认命令模板

```bash
codex exec --full-auto -m gpt-5.3-codex -c model_reasoning_effort=xhigh \
  -C "<workdir>" "<prompt>" 2>.ai_docs/codex_call/<描述性文件名>.log
```

Bash timeout 设为 600000ms（10 分钟）。

日志文件名示例：`add-error-handling-to-api.log`、`refactor-user-model.log`。

#### Prompt 编写规范

- 明确指定要修改的文件路径
- 描述期望的具体变更，而非抽象目标
- 提供必要上下文（相关类型定义、接口约定、已有模式）
- 使用 `@file` 引用关键文件让 Codex 读取
- 一次只做一件事，避免过大的 prompt

### 第 4 步：追踪

Codex 完成后，查看变更：

```bash
git diff --stat
git diff
```

如果 Codex 没有产生任何变更或报错，分析原因后决定是否重新委派。

### 第 5 步：验证

逐个读取被修改文件的完整内容（使用 Read 工具），做轻量级质量检查：

- **正确性** — 代码逻辑是否正确实现了需求
- **完整性** — 是否遗漏了必要的修改（如相关测试、类型定义）
- **一致性** — 是否与项目现有风格和模式一致
- **副作用** — 是否引入了非预期的变更或破坏了现有功能

向用户报告验证结果。

### 第 6 步：迭代

根据审查结果决定下一步：

- **通过** → 继续下一个子任务，或告知用户本轮任务完成
- **需修改** → **Never** 阅读 stderr 日志文件。使用 `codex exec resume --last` 在同一 session 中继续指挥 Codex 修正：
  ```bash
  echo "<修正 prompt>" | codex exec resume --last 2>.ai_docs/codex_call/<描述性文件名>-followup.log
  ```
- **需回滚** → 恢复到 checkpoint 后，新开 session 重新委派（回到第 3 步）：
  ```bash
  git checkout <checkpoint-hash> -- .
  ```

关键原则：即使 Codex 回复不符合预期，也不要阅读 stderr 日志文件来分析原因。stderr 日志仅供人类异步查看中间状态。Claude 应基于 `git diff` 审查结果决定是 resume 进一步指挥还是回滚重来。

## 高级用法

### 自定义模型和参数

用户可指定不同的模型或推理强度：

```bash
codex exec --full-auto -m gpt-5.2 -c model_reasoning_effort=high \
  -C "<workdir>" "<prompt>" 2>.ai_docs/codex_call/<描述性文件名>.log
```

### 大型任务分解策略

对于涉及多文件的大型任务：

1. 按文件或模块拆分为独立子任务
2. 每个子任务单独委派、审查
3. 所有子任务完成后做一次整体审查
4. 必要时运行测试验证集成

### 需要更大权限时

默认 `--full-auto` 限制在工作区写入。如需网络访问或更大权限：

```bash
codex exec --full-auto --sandbox danger-full-access \
  -m gpt-5.3-codex -c model_reasoning_effort=xhigh \
  -C "<workdir>" "<prompt>" 2>.ai_docs/codex_call/<描述性文件名>.log
```

仅在用户确认后使用 `danger-full-access`。

## 注意事项

- **超时处理**：Bash 工具 timeout 设为 600000ms（10 分钟）。如果 Codex 超时，缩小任务范围后重试
- **stderr 日志**：stderr 重定向到 `.ai_docs/codex_call/` 下的日志文件，供人类异步查看中间状态。Claude 不应阅读这些文件，而是通过 `git diff` 审查结果来判断下一步
- **错误处理**：Codex 执行失败或结果不符合预期时，优先 resume session 进一步指挥；问题严重时回滚到 checkpoint 后新开 session 重试
- **不跳过 git 检查**：协作模式依赖 git 追踪变更，不使用 `--skip-git-repo-check`
