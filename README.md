# my-skills

自定义 Claude Code Skills 集合。

## Skills 列表

| Skill | 描述 |
| --- | --- |
| [git-commit](./git-commit/SKILL.md) | 所有 git commit 操作必须通过此 skill 执行，基于 Conventional Commits 规范生成提交信息 |
| [optimize-skill](./optimize-skill/SKILL.md) | 优化已有 skill 的工作流和描述内容，支持从任意仓库触发，自动定位 my-skills 仓库并完成 skill 迁移和优化。迁移外部 skill 时自动创建 UPSTREAM.md 记录源仓库信息和定制改动日志 |
| [skill-creator](./skill-creator/SKILL.md) | Guide for creating effective skills, with auto-integration into my-skills repo (scaffold → edit → commit → global install) |
| [go-cli-tui](./go-cli-tui/SKILL.md) | Go CLI/TUI 最佳实践，涵盖 Cobra 命令模式、Bubble Tea TUI 开发、Lipgloss 样式和性能优化。适用于 CLI/TUI 开发和 code review |
