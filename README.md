# my-skills

自定义 Claude Code Skills 集合。

## Skills 列表

| Skill | 描述 |
| --- | --- |
| [git-commit](./git-commit/SKILL.md) | 所有 git commit 操作必须通过此 skill 执行，基于 Conventional Commits 规范生成提交信息 |
| [skill-crud](./skill-crud/SKILL.md) | 创建、优化和迭代 skill，统一管理 skill 全生命周期。支持从任意仓库触发，自动定位 my-skills 仓库 |
| [go-cli-tui](./go-cli-tui/SKILL.md) | Go CLI/TUI 最佳实践，涵盖 Cobra 命令模式、Bubble Tea TUI 开发、Lipgloss 样式和性能优化。适用于 CLI/TUI 开发和 code review |
| [go-review](./go-review/SKILL.md) | Go 代码审查与优化最佳实践，涵盖惯用模式、错误处理、并发、测试和安全编码规范。适用于 code review 和代码优化 |
| [context7-auto-research](./context7-auto-research/SKILL.md) | 通过 Context7 获取库/框架最新文档。优先使用已有知识，仅在用户显式调用或已有知识无法解决问题时触发查询 |
| [cooperation-with-codex](./cooperation-with-codex/SKILL.md) | Claude 与 Codex CLI 协作编程模式。Claude 负责调研、规划、编写 prompt 和 code review，所有代码编辑通过 Codex exec 执行 |
