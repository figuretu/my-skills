---
name: optimize-skill
description: "优化已有 skill 的工作流和描述内容。适用场景：(1) 用户在使用某个 skill 时发现描述不够准确或缺少关键信息，(2) 用户希望改进 skill 的触发条件或执行步骤，(3) 用户想要完善 skill 的参数定义或适用场景。支持从任意仓库触发，自动定位 my-skills 仓库并完成 skill 迁移和优化。"
---

# Optimize Skill

优化已有 skill 的描述、工作流和内容，使其更准确、更完善。

## 辅助脚本

本 skill 附带 `scripts/skill-ops.sh`，封装了仓库定位、skill 检查、安装等常用操作。脚本内部通过 zoxide / `$MY_SKILLS_DIR` 环境变量自动定位 my-skills 仓库。

支持的子命令：

| 子命令 | 作用 |
|--------|------|
| `scripts/skill-ops.sh locate-repo` | 查找并输出 my-skills 仓库路径 |
| `scripts/skill-ops.sh check <name>` | 检查 skill 本地存在性 + 全局安装状态 |
| `scripts/skill-ops.sh install <name>` | 从本地仓库安装/重装 skill（claude-code + codex） |
| `scripts/skill-ops.sh uninstall <name>` | 从所有 agent 全局卸载 skill |
| `scripts/skill-ops.sh stage <name>` | git add skill 目录 + README.md，显示暂存状态 |

## 执行流程

按以下步骤顺序执行。每完成一步，简短向用户报告状态后继续。

### 第一步：确认目标 skill

从用户描述或当前上下文中确认需要优化的 skill 名称。如不明确，向用户询问。

### 第二步：定位 my-skills 仓库

```bash
scripts/skill-ops.sh locate-repo
```

将输出记录为 `$MY_SKILLS_DIR`。若命令失败，告知用户并请其手动提供路径或设置 `$MY_SKILLS_DIR` 环境变量。

定位成功后，读取 `$MY_SKILLS_DIR/AGENTS.md` 了解仓库规范（命名、语言、提交等），后续步骤遵循这些规范。

### 第三步：检查 skill 来源

```bash
scripts/skill-ops.sh check <skill-name>
```

根据输出分两条路径：

#### 路径 A：skill 已在 my-skills 仓库中

直接进入第四步。

#### 路径 B：skill 不在 my-skills 仓库中（通过 npx skills 安装）

需先迁移到 my-skills 仓库：

1. 从 check 输出中确认安装路径（形如 `~/.agents/skills/<skill-name>`），将该目录完整复制到 `$MY_SKILLS_DIR/<skill-name>/`。

2. 卸载旧版并从本地仓库重装：

```bash
scripts/skill-ops.sh uninstall <skill-name>
scripts/skill-ops.sh install <skill-name>
```

3. 在 `$MY_SKILLS_DIR/<skill-name>/UPSTREAM.md` 中记录源仓库信息，方便日后追踪上游更新：

```markdown
# Upstream Info

- **Source**: <repo URL 或 registry 来源>
- **Original Name**: <skill-name>
- **Migrated At**: <迁移日期>

## Original Description

<迁移时 SKILL.md 中的 description 原文>

## Customization Log

| Date | Summary |
|------|---------|
```

迁移完成后继续第四步。

### 第四步：与用户讨论优化方案

读取目标 skill 的 SKILL.md 完整内容，与用户讨论：

1. 当前 skill 存在什么问题？（描述不准确、缺少场景、步骤不清晰等）
2. 期望的改进方向是什么？
3. 是否需要调整触发条件（description 字段）？

等待用户确认优化方向后再动手修改。

### 第五步：执行优化

根据讨论结果修改 `$MY_SKILLS_DIR/<skill-name>/SKILL.md`。修改时遵循以下原则：

- 保持 skill 原有语言风格（英文写的保持英文，中文写的保持中文，专业术语保持英文）
- 使用祈使句/不定式形式编写指令（如"执行 X"而非"你应该执行 X"）
- 适用场景使用 "(1) ... (2) ... (3) ..." 格式
- YAML frontmatter 中 name 和 description 字段保持完整且具体
- 若 skill 目录下存在 `UPSTREAM.md`，在 Customization Log 表格中追加本次变更记录

### 第六步：同步更新 README

修改 `$MY_SKILLS_DIR/README.md` 中的 Skills 列表，确保与 skill 最新描述一致。

### 第七步：提交变更并推送

暂存改动：

```bash
scripts/skill-ops.sh stage <skill-name>
```

按 `$MY_SKILLS_DIR/AGENTS.md` 中的提交规范完成提交——检查是否有可用的 commit 相关 skill，有则调用；没有则按常规方式提交。提交后推送到远程仓库。

### 第八步：重新安装

从本地仓库重新安装，确保改动生效：

```bash
scripts/skill-ops.sh install <skill-name>
```
