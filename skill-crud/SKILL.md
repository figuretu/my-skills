---
name: skill-crud
description: "创建、优化和迭代 skill。适用场景：(1) 用户想创建一个新 skill 来扩展 Agent 能力，(2) 用户在使用某个 skill 时发现描述不够准确或缺少关键信息，想要优化，(3) 用户希望改进 skill 的触发条件、执行步骤或参数定义，(4) 用户想将 npx skills registry 中的 skill 迁移到本地仓库并定制。支持从任意仓库触发，自动定位 my-skills 仓库。"
---

# Skill CRUD

创建、优化和迭代 skill，统一管理 skill 的全生命周期。

## 辅助脚本

| 脚本 | 用途 |
|------|------|
| `scripts/skill-ops.sh locate-repo` | 查找并输出 my-skills 仓库路径 |
| `scripts/skill-ops.sh check <name>` | 检查 skill 本地存在性 + 全局安装状态 |
| `scripts/skill-ops.sh install <name>` | 从本地仓库安装/重装 skill（按 `install-rules.json` 决定目标 agent） |
| `scripts/skill-ops.sh uninstall <name>` | 从所有默认 agent 全局卸载 skill |
| `scripts/skill-ops.sh stage <name>` | git add skill 目录 + README.md，显示暂存状态 |
| `scripts/init_skill.py <name> --path <path>` | 初始化新 skill 目录（生成模板 SKILL.md + 示例资源） |
| `scripts/quick_validate.py <skill-dir>` | 验证 skill 结构（frontmatter、命名规范等） |

## 参考资料

`references/skill-design-principles.md` 包含 Skill 设计原则（结构规范、Progressive Disclosure、Metadata 质量、内容组织、写作规范等）。创建和优化 skill 时按需读取，作为编写和检查的依据。

## 执行流程

按以下步骤顺序执行。每完成一步，简短向用户报告状态后继续。

### 第一步：定位 my-skills 仓库

```bash
scripts/skill-ops.sh locate-repo
```

将输出记录为 `$MY_SKILLS_DIR`。若命令失败，告知用户并请其手动提供路径或设置 `$MY_SKILLS_DIR` 环境变量。

定位成功后，读取 `$MY_SKILLS_DIR/AGENTS.md` 了解仓库规范（命名、语言、提交等），后续步骤遵循这些规范。

### 第二步：判断意图

根据用户描述判断操作类型：

- **创建**：用户想创建一个全新的 skill → 进入「创建流程」
- **优化**：用户想改进已有 skill 的描述、工作流或内容 → 进入「优化流程」

如不明确，向用户询问。

---

## 创建流程

### C1：理解需求

跳过条件：skill 的使用模式已经非常清晰。

通过提问理解 skill 的具体用法，例如：

- "这个 skill 应该支持哪些功能？"
- "能举几个使用场景的例子吗？"
- "用户说什么话应该触发这个 skill？"
- "这个 skill 是 public（全局安装，推 GitHub）还是 private（仓库级别安装，推内网）？"

避免一次问太多问题。当对 skill 应支持的功能有清晰认识后，结束此步。

将 scope 记录为 `$SKILL_SCOPE`（`public` 或 `private`），后续步骤据此决定目标路径。

### C2：规划可复用内容

将具体场景转化为可复用资源。对每个场景分析：

1. 从零执行这个场景需要什么？
2. 哪些 scripts / references / assets 在重复执行时有帮助？

示例：
- PDF 旋转 → 每次都要重写相同代码 → `scripts/rotate_pdf.py`
- 前端应用 → 每次都要相同样板代码 → `assets/hello-world/`
- BigQuery 查询 → 每次都要重新发现表结构 → `references/schema.md`

### C3：初始化 skill

根据 `$SKILL_SCOPE` 决定目标路径：
- `public`：`$MY_SKILLS_DIR`
- `private`：`$MY_SKILLS_DIR/private`

```bash
# public skill
scripts/init_skill.py <skill-name> --path "$MY_SKILLS_DIR"

# private skill
scripts/init_skill.py <skill-name> --path "$MY_SKILLS_DIR/private"
```

脚本会生成模板 SKILL.md 和示例资源目录。初始化后根据需要定制或删除示例文件。

若 skill 已存在且只需迭代，跳过此步。

### C4：编辑 Skill

读取 `references/skill-design-principles.md`，按设计原则编写 skill 内容。

#### 先处理可复用资源

从 C2 中确定的资源开始实现 `scripts/`、`references/`、`assets/` 文件。此步可能需要用户提供素材（如品牌资源、API 文档等）。删除不需要的示例文件和目录。

#### 再更新 SKILL.md

回答以下问题来完成 SKILL.md：

1. Skill 的用途是什么？（几句话概括）
2. 什么时候应该使用这个 skill？
3. 实际使用时应该怎么做？（确保引用了所有可复用资源）

完成后进入「共享收尾步骤」。

---

## 优化流程

### O1：确认目标并检查来源

从用户描述或当前上下文中确认需要优化的 skill 名称。如不明确，向用户询问。

```bash
scripts/skill-ops.sh check <skill-name>
```

根据输出分两条路径：

#### 路径 A：skill 已在 my-skills 仓库中

直接进入 O2。

#### 路径 B：skill 不在 my-skills 仓库中（通过 npx skills 安装）

需先迁移到 my-skills 仓库：

1. 从 check 输出中确认安装路径（形如 `~/.agents/skills/<skill-name>`），将该目录完整复制到 `$MY_SKILLS_DIR/<skill-name>/`。

2. 卸载旧版并从本地仓库重装：

```bash
scripts/skill-ops.sh uninstall <skill-name>
scripts/skill-ops.sh install <skill-name>
```

3. 在 `$MY_SKILLS_DIR/<skill-name>/UPSTREAM.md` 中记录源仓库信息：

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

迁移完成后继续 O2。

### O2：讨论优化方案

读取目标 skill 的 SKILL.md 完整内容，与用户讨论：

1. 当前 skill 存在什么问题？（描述不准确、缺少场景、步骤不清晰等）
2. 期望的改进方向是什么？
3. 是否需要调整触发条件（description 字段）？

等待用户确认优化方向后再动手修改。

### O3：执行优化

读取 `references/skill-design-principles.md`，对照设计原则检查并修改 `$MY_SKILLS_DIR/<skill-name>/SKILL.md`。

修改时遵循：

- 保持 skill 原有语言风格（英文写的保持英文，中文写的保持中文，专业术语保持英文）
- 遵循设计原则中的写作规范和内容组织原则
- 若 skill 目录下存在 `UPSTREAM.md`，在 Customization Log 表格中追加本次变更记录

完成后进入「共享收尾步骤」。

---

## 共享收尾步骤

### 同步 README

- **Public skill**：更新 `$MY_SKILLS_DIR/README.md` 中的 Skills 列表，确保与 skill 最新描述一致。
- **Private skill**：更新 `$MY_SKILLS_DIR/private/README.md`（如存在），不修改主仓库 README。

### 提交变更

暂存改动（脚本自动识别 public/private，在正确的 git 仓库中暂存）：

```bash
scripts/skill-ops.sh stage <skill-name>
```

检查是否有可用的 commit 相关 skill，有则调用；没有则提示用户是否提交和推送。

注意：private skill 的提交发生在 `$MY_SKILLS_DIR/private/` 子仓库中。

### 重新安装

- **Public skill**：从本地仓库重新安装，确保改动生效：

```bash
scripts/skill-ops.sh install <skill-name>
```

- **Private skill**：跳过此步。Private skill 按需在目标项目仓库中安装，不在 skill 仓库本身安装。提醒用户到目标项目中执行 `scripts/skill-ops.sh install <skill-name>`。

### 迭代

使用 skill 后如发现问题，可直接进入优化流程（O2 → O3）改进，然后重复收尾步骤。
