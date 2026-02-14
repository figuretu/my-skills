---
name: go-coding
description: "Go 编码最佳实践。涵盖惯用模式、注释规范、错误处理、并发、测试和安全编码。适用场景：(1) 用 Go 实现新需求或新功能，(2) 重构 Go 模块/包，(3) 对 Go 代码进行 code review，(4) 优化 Go 代码质量。不适用于局部小修（语法修复、变量重命名、单行改动等）。"
---

# Go 编码最佳实践

确保 Go 代码符合惯用风格、可维护且安全。适用于实现、重构和 code review。

## 风格原则（优先级排序）

1. **Clarity** — 代码的意图和原因对读者一目了然。
2. **Simplicity** — 用最简单的方式达成目标，避免不必要的抽象。
3. **Concision** — 信噪比高，不重复、不冗余。
4. **Maintainability** — 易于后续修改，API 可优雅扩展。
5. **Consistency** — 与周围代码风格一致；同一概念使用同一命名。

## 核心编码规范

### 格式化

- `gofmt` 强制，无例外。
- 命名使用 `MixedCaps`/`mixedCaps`，禁止下划线（测试函数 `TestFoo_Bar` 除外）。
- 行长度无硬性限制，按语义断行而非凑字数；行太长时优先缩短命名或重构。

### Happy Path

- 正常路径直线向下，错误/特殊情况 early return 或 continue。
- 避免不必要的 else：变量在两个分支都赋值时，用默认值 + 覆盖模式。

```go
// Good: default + override.
a := 10
if b {
    a = 100
}
```

### 错误处理

- 调用后立即检查 `err`，不要攒到后面。
- 用 `%w` 包装错误并附带操作上下文：`fmt.Errorf("get user %s: %w", id, err)`。
- 对预期条件定义哨兵错误，用 `errors.Is()` 检查。
- 不要同时 log 和 return 同一个错误——选一个。
- `panic` 仅限不可恢复的编程错误，不用于业务逻辑。

### 命名

- 不遮蔽预声明标识符（`new`、`len`、`copy` 等），完整列表见 [patterns.md](references/patterns.md)。
- 接受 interface，返回 struct。

### 结构

- 保持函数小而专注，复杂逻辑提取为辅助函数。
- 使用 `defer` 进行资源清理（文件、锁、连接）。
- 复杂 struct 使用构造函数初始化。
- 常量替代魔法值。
- 最小化包级可变状态，优先依赖注入。
- naked return 仅限短函数；中大型函数显式返回。

## 注释规范

### 总体原则

注释面向读者，解释 why 而非 what。所有注释以句号结尾。

### 方法前注释

Go doc 风格，以函数名开头。不使用 `@param` 等标签。

```go
// ProcessOrder validates and persists the given order.
// It returns an error if validation fails or the database is unreachable.
func ProcessOrder(o *Order) error {
```

### 方法内注释

每个逻辑块前用单行注释说明意图。

```go
func ProcessOrder(o *Order) error {
    // Validate the order before processing.
    if err := o.Validate(); err != nil {
        return fmt.Errorf("validate order: %w", err)
    }

    // Persist to database.
    if err := db.Save(o); err != nil {
        return fmt.Errorf("save order: %w", err)
    }

    return nil
}
```

### Struct / Interface

导出的 struct 和 interface 必须有注释。

### 测试方法

测试函数必须有注释，说明测试目标。

### 格式

所有注释以句号结尾。`//` 后空一格。

## Go 箴言

> Don't communicate by sharing memory, share memory by communicating.
> Concurrency is not parallelism.
> Channels orchestrate; mutexes serialize.
> The bigger the interface, the weaker the abstraction.
> Make the zero value useful.
> interface{} says nothing.
> Gofmt's style is no one's favorite, yet gofmt is everyone's favorite.
> A little copying is better than a little dependency.
> Syscall must always be guarded with build tags.
> Cgo must always be guarded with build tags.
> Cgo is not Go.
> With the unsafe package there are no guarantees.
> Clear is better than clever.
> Reflection is never clear.
> Errors are values.
> Don't just check errors, handle them gracefully.
> Design the architecture, name the components, document the details.
> Documentation is for users.
> Don't panic.

## 专项参考（按需加载）

**加载时机**：仅在 code review 或重构时按需加载。实现需求时不读专项参考，遵循上方核心编码规范即可。

| 文件 | 何时加载 |
|------|----------|
| [patterns.md](references/patterns.md) | 需要查阅惯用模式细节或命名规范 |
| [error-handling.md](references/error-handling.md) | 需要查阅错误处理详细模式 |
| [concurrency.md](references/concurrency.md) | 代码涉及 goroutine/channel/sync |
| [testing.md](references/testing.md) | 编写或修改测试代码 |
| [security.md](references/security.md) | 代码涉及外部输入/HTTP/文件/敏感数据 |
