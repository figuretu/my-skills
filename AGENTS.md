# AGENTS.md

This file provides guidance to Agents when working with code in this repository.

## 仓库用途 (Repository Purpose)

这个仓库用于管理 Agents 的自定义 skills。

仓库采用 public/private 双层结构：
- **根目录** 的 skill 是公开的，推送到 GitHub，全局安装
- **`private/`** 目录是独立的 git 仓库（被父仓库 `.gitignore` 忽略），推送到内网仓库，仅在特定仓库级别安装

## 语言规范 (Language Convention)

**重要**: 
- 自建 skill 的描述必须使用中文，但专业术语保持英文。
- 从 npx skills 迁移来的 skill 描述保持原语言，不需要翻译成中文。

示例：
- ✅ "下载飞书/Lark 文档到本地 Markdown 文件"

## Skill 结构规范

每个 skill 应该包含：
- **名称**: 使用 kebab-case 命名（如 `upload-to-lark`, `download-lark-doc`）
- **适用场景**: 列出具体的使用场景，帮助 Claude 判断何时调用该 skill
- **参数**: 清晰定义输入参数和格式要求

## Skill 安装与管理

Skill 通过 `npx skills` 管理（文档：`npx skills --help`）。用户常用的 agent 是 `claude-code` 和 `codex`。

### 安装规则

仓库根目录的 `install-rules.json` 定义了每个 **public** skill 的安装目标 agent：

- `defaults` 对所有 public skill 生效（默认安装到 claude-code + codex）
- `skills` 中可为特定 skill 覆盖默认规则（如 `cooperation-with-codex` 仅安装到 claude-code）

**Private skills 不受 `install-rules.json` 管理**，始终以 repo-level 方式安装（不带 `-g`），默认目标 agent 为 `claude-code`。

安装 skill 前必须读取此文件，按规则决定 `-a` 参数。`skill-ops.sh install` 已自动处理 public/private 的区分。

### 常用命令

```bash
# 安装本仓库中的某个 skill（自动按 install-rules.json 决定目标 agent）
scripts/skill-ops.sh install <skill-name>

# 手动安装（需自行查阅 install-rules.json 确定 -a 参数）
npx skills add "$MY_SKILLS_DIR" -g -a claude-code -a codex -s <skill-name> -y

# 查看已安装的全局 skills
npx skills ls -g

# 查看某个 agent 已安装的 skills
npx skills ls -g -a claude-code

# 卸载某个 skill
npx skills remove <skill-name> -g -a claude-code -a codex -y

# 检查更新 / 更新所有 skills（仅限公开 registry 来源，不包含本地导入和私有仓库导入的 skill）
npx skills check
npx skills update
```

其中 `$MY_SKILLS_DIR` 指本仓库根目录路径。

### Private Skills

`private/` 是独立的 git 仓库，有自己的版本控制和远程仓库。`skill-ops.sh` 会自动检测 skill 位于根目录还是 `private/` 下，并采用对应的安装/暂存策略：

- `skill-ops.sh install <name>`：自动检测位置，private skill 以 repo-level 安装
- `skill-ops.sh stage <name>`：自动在正确的 git 仓库中暂存
- `skill-ops.sh check <name>`：同时搜索根目录和 `private/`

Private 仓库的提交和推送需要单独操作：

```bash
cd "$MY_SKILLS_DIR/private"
git add .
git commit -m "..." # 如有 commit 相关 skill，先调用
git push  # 推送到内网仓库
```

## 提交规范 (Commit Convention)

当 skill 流程涉及 git commit 操作时，不要硬编码 commit 命令和 message 格式。应先检查当前环境是否有已安装的 commit 相关 skill（如 git-commit），有则调用该 skill 完成提交；没有则按常规方式提交。

## 开发指南

在创建或修改 skill 时：
1. 确保描述清晰、具体，包含足够的上下文信息
2. 列出明确的适用场景，使用 "(1) ... (2) ... (3) ..." 格式
3. 技术术语（如 Markdown, JSON, URL）保持英文
4. 翻译时，中文描述要自然流畅，避免生硬
5. 对 skill 做任何增删改后，必须同步更新 `README.md` 中的 Skills 列表
6. 对 skill 做任何修改后，提醒用户提交变更并重新 install（`npx skills add ... -s <skill-name>`），否则修改不会在 agent 中生效
7. 执行 `git diff` 时，如果发现某个 skill 目录下有未提交的变更（可能是之前修改的残留），主动提示用户是否需要提交并重新 install
