---
name: optimize-skill
description: "优化已有 skill 的工作流和描述内容。适用场景：(1) 用户在使用某个 skill 时发现描述不够准确或缺少关键信息，(2) 用户希望改进 skill 的触发条件或执行步骤，(3) 用户想要完善 skill 的参数定义或适用场景。支持从任意仓库触发，自动定位 my-skills 仓库并完成 skill 迁移和优化。"
---

# Optimize Skill

优化已有 skill 的描述、工作流和内容，使其更准确、更完善。

## 执行流程

按以下步骤顺序执行，不可跳步。每完成一步，简短地向用户报告当前状态和结果，再继续下一步。

### 第一步：确认目标 skill

从用户的描述或当前上下文中确认需要优化的 skill 名称。如果不明确，询问用户。

### 第二步：定位 my-skills 仓库

按以下优先级依次尝试定位仓库：

1. 尝试通过 zoxide 查找：

```bash
zoxide query my-skills 2>/dev/null
```

2. 如果 zoxide 未找到，检查环境变量 `$MY_SKILLS_DIR` 是否已设置且目录存在。

3. 如果以上方式都未找到，告知用户找不到 my-skills 仓库，后续操作无法继续，请用户手动提供路径。

定位成功后，告知用户找到的仓库路径，并记录为 `$MY_SKILLS_DIR`，后续步骤中使用。

### 第三步：检查 skill 来源

在 `$MY_SKILLS_DIR` 中查找目标 skill 目录是否存在：

```bash
ls "$MY_SKILLS_DIR/<skill-name>/SKILL.md"
```

同时通过 `npx skills` 检查该 skill 是否已全局安装：

```bash
npx skills ls -g
```

根据结果分两条路径：

#### 路径 A：skill 已在 my-skills 仓库中

直接跳到第四步，与用户讨论优化方案。

#### 路径 B：skill 不在 my-skills 仓库中（通过 npx skills 安装）

说明该 skill 是通过 `npx skills` 安装的，需要先迁移到 my-skills 仓库。执行以下操作：

1. 从 `npx skills ls -g` 的输出中确认 skill 名称和安装路径（canonical 路径形如 `~/.agents/skills/<skill-name>`）。

2. 将该 canonical 路径下的 skill 目录完整复制到 `$MY_SKILLS_DIR/<skill-name>/`。

3. 卸载通过 npx skills 安装的版本：

```bash
npx skills remove <skill-name> -g -a claude-code -a codex -y
```

4. 从本地仓库重新安装该 skill：

```bash
npx skills add "$MY_SKILLS_DIR" -g -a claude-code -a codex -s <skill-name> -y
```

5. 验证安装成功：

```bash
npx skills ls -g -a claude-code
```

6. 创建 `UPSTREAM.md` 记录源仓库信息：

在 `$MY_SKILLS_DIR/<skill-name>/UPSTREAM.md` 中记录以下内容，方便日后源 skill 更新时重新应用定制改动：

```markdown
# Upstream Info

- **Source**: <从 npx skills ls -g 输出中提取的 repo URL 或 registry 来源>
- **Original Name**: <skill-name>
- **Migrated At**: <迁移日期>

## Original Description

<复制迁移时 SKILL.md 中的 description 字段原文>

## Customization Log

| Date | Summary |
|------|---------|
```

确认迁移完成后，继续第四步。

### 第四步：与用户讨论优化方案

读取目标 skill 的 SKILL.md 完整内容，然后与用户讨论：

1. 当前 skill 存在什么问题？（描述不准确、缺少场景、步骤不清晰等）
2. 用户期望的改进方向是什么？
3. 是否需要调整 skill 的触发条件（description 字段）？

等待用户确认优化方向后再动手修改。

### 第五步：执行优化

根据讨论结果修改 `$MY_SKILLS_DIR/<skill-name>/SKILL.md`。修改时注意：

- 保持 skill 原有的语言风格：如果原 skill 是英文编写的，优化后仍使用英文；如果是中文编写的，则使用中文（专业术语保持英文）
- 适用场景使用 "(1) ... (2) ... (3) ..." 格式
- 保持 YAML frontmatter 中 name 和 description 字段完整
- description 字段要具体，包含足够的上下文信息帮助 agent 判断何时触发
- 如果 skill 目录下存在 `UPSTREAM.md`（即该 skill 是从外部迁移来的），在其 Customization Log 表格中追加一行，记录本次变更日期和改动摘要，格式如 `| 2025-01-15 | 优化了 description 中的触发条件描述 |`

### 第六步：同步更新 README

修改 `$MY_SKILLS_DIR/README.md` 中的 Skills 列表，确保与 skill 的最新描述一致。

### 第七步：提交变更并备份到远程

在 `$MY_SKILLS_DIR` 下暂存优化后的改动：

```bash
git -C "$MY_SKILLS_DIR" add <skill-name>/ README.md  # UPSTREAM.md 已包含在 <skill-name>/ 目录中
```

然后按照 `$MY_SKILLS_DIR/AGENTS.md` 中的提交规范完成提交——检查是否有可用的 commit 相关 skill，有则调用；没有则按常规方式提交。提交后推送到远程仓库。

### 第八步：重新安装

从本地仓库重新安装更新后的 skill，确保改动生效：

```bash
npx skills add "$MY_SKILLS_DIR" -g -a claude-code -a codex -s <skill-name> -y
```
