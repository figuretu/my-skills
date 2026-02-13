---
name: git-commit
description: '智能 Git 提交工具，基于 Conventional Commits 规范生成提交信息。适用场景：(1) 用户要求提交代码变更或创建 commit，(2) 用户提到 "/commit" 或表达提交意图，(3) 用户要求生成 commit message，(4) 用户完成代码修改后需要提交。支持从会话上下文或 diff 自动分析变更类型和范围，生成简洁规范的提交信息。'
---

# Git Commit

## Overview

基于 Conventional Commits 规范，智能分析变更并生成简洁的提交信息。优先使用会话上下文，无上下文时回退到 git diff 分析。

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

展示提交信息，等待用户确认后执行：

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
