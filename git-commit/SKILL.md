---
name: git-commit
description: '所有 git commit 操作必须通过此 skill 执行，禁止直接运行 git commit 命令。基于 Conventional Commits 规范生成提交信息。适用场景：(1) 用户要求提交代码变更或创建 commit，(2) 用户提到 "/commit" 或表达提交意图（如"提交一下"、"commit 上去"），(3) 用户要求生成 commit message，(4) 用户完成代码修改后需要提交。支持从会话上下文或 diff 自动分析变更类型和范围。'
---

# Git Commit

## Overview

基于 Conventional Commits 规范，智能分析变更并生成简洁的提交信息。优先使用会话上下文，无上下文时回退到 git diff 分析。

## 调用模式

### 交互模式（默认）

用户直接调用 skill / 表达出提交意图，或者 Agent 当前的 Edit 任务已经完成，进入收尾工作。展示 commit message 并通过 AskUserQuestion 让用户决定下一步操作。

### 自动模式

agent 正在实现大型需求或任务，需要阶段性 checkpoint 保持中间状态可靠、可追溯。直接生成并执行 commit，不向用户提问，禁止使用 push。由调用时的任务状态决定是否进入此模式。

## Commit 格式

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

### Type 列表

| Type       | 用途                     |
| ---------- | ------------------------ |
| `feat`     | 新功能                   |
| `fix`      | Bug 修复                 |
| `docs`     | 仅文档变更               |
| `style`    | 格式调整（不影响逻辑）    |
| `refactor` | 重构（非新功能/修复）     |
| `perf`     | 性能优化                 |
| `test`     | 测试相关                 |
| `build`    | 构建系统/依赖            |
| `ci`       | CI/CD 配置               |
| `chore`    | 杂项维护                 |
| `revert`   | 回滚                     |

### Breaking Changes

```
feat!: remove deprecated endpoint

# 或使用 footer
feat: allow config to extend other configs

BREAKING CHANGE: `extends` key behavior changed
```

## 工作流程

### Step 1: 收集变更信息

优先级顺序：

1. **会话上下文可用** — 当前会话中通过 Edit/Write 工具修改过文件，或用户描述了变更内容 → 直接使用上下文，跳过 diff
2. **无上下文** — 执行 git 命令分析：

```bash
git status --porcelain
# 有 staged 文件时
git diff --staged
# 无 staged 文件时
git diff
```

### Step 2: 暂存文件

如果没有 staged 文件，根据变更内容暂存：

```bash
# 暂存特定文件
git add path/to/file1 path/to/file2

# 按模式暂存
git add src/components/*
```

**禁止提交敏感文件**（.env, credentials, private keys 等）。

### Step 3: 生成 Commit Message

从变更中分析：
- **Type**: 变更类型
- **Scope**: 影响的模块/区域（可选）
- **Description**: 一行摘要，祈使语气，<=50 字符

原则：
- **Commit message 必须使用英文**
- 祈使语气：add / fix / update（不用 added / fixed）
- 描述 WHAT 和 WHY，不描述 HOW
- Body 最多 3 行，仅在必要时添加
- 关联 issue：`Closes #123`, `Refs #456`

### Step 4: 确认并提交

**交互模式**（默认）：使用 AskUserQuestion 向用户展示 commit message 并询问下一步操作（选项按此顺序）：
1. **提交并推送** — commit + push 到远程
2. **仅提交** — 只 commit，不 push
3. **跳过** — 不提交

用户确认后按选择执行。

**自动模式**：agent 正在实现大型需求或任务，需要阶段性 checkpoint 保持中间状态可靠、可追溯。直接 commit 不提问，禁止使用 push。由调用时的任务状态决定是否进入自动模式。

```bash
git commit -m "$(cat <<'EOF'
<type>[scope]: <description>

<optional body>
EOF
)"

git log -1 --oneline
```

**禁止**在 commit message 中添加 `Co-Authored-By`、`Generated with` 等工具标记。

## Git 安全协议

- 禁止修改 git config
- 禁止执行破坏性命令（--force, reset --hard）除非用户明确要求
- 禁止跳过 hooks（--no-verify）除非用户明确要求
- 禁止 force push 到 main/master
- Hook 失败时修复问题后创建新 commit，不要 amend

## Git Tag

创建 tag 时先检查已有格式保持一致：

```bash
git tag --sort=-creatordate | head -5
```

有 `v` 前缀则保持 `v` 前缀，无则不加。
