# 错误处理

Go 错误创建、包装和处理最佳实践。

## 检查清单

### 1. 立即检查错误

**说明**: 函数调用后立即检查错误返回值。

**通过标准**: 每个错误都被检查，没有被忽略的错误返回值（除非有意为之）。

**不通过标准**: 用 `_` 忽略错误返回值，或延迟多行后才检查错误。

**严重程度**: 严重

**建议**:
```go
// 正确
f, err := os.Open(path)
if err != nil {
    return fmt.Errorf("failed to open file: %w", err)
}
defer f.Close()

// 错误 — 忽略错误
f, _ := os.Open(path)  // 绝不要这样做
```

---

### 2. 用上下文包装错误

**说明**: 使用 `fmt.Errorf` 配合 `%w` 动词包装错误以添加上下文。

**通过标准**: 错误被包装并附带描述失败操作的上下文。

**不通过标准**: 原始错误直接返回无上下文，或使用 `%v` 而非 `%w`。

**严重程度**: 高

**建议**:
```go
func (m *Manager) StartProcess(name string) error {
    if err := cmd.Start(); err != nil {
        return fmt.Errorf("failed to start process %s: %w", name, err)
    }
    return nil
}
```

---

### 3. 对预期条件使用哨兵错误

**说明**: 为预期的错误条件定义包级哨兵错误。

**通过标准**: 常见错误条件有命名的哨兵错误，调用者可使用 `errors.Is()`。

**不通过标准**: 通过字符串比较检查错误。

**严重程度**: 中

**建议**:
```go
// 定义哨兵错误
var ErrAlreadyRunning = errors.New("service is already running")
var ErrNotFound = errors.New("not found")

// 代码中使用
if isRunning {
    return ErrAlreadyRunning
}

// 调用者检查
if errors.Is(err, ErrAlreadyRunning) {
    // 处理预期情况
}
```

---

### 4. 使用 errors.Is 和 errors.As 检查错误

**说明**: 使用 `errors.Is()` 和 `errors.As()` 而非类型断言。

**通过标准**: 错误检查使用 `errors.Is()` 和 `errors.As()` 处理包装错误。

**不通过标准**: 直接类型断言或字符串匹配错误消息。

**严重程度**: 中

**建议**:
```go
// 检查特定错误
if errors.Is(err, os.ErrNotExist) {
    // 文件不存在
}

// 提取类型化错误
var healthErr *HealthError
if errors.As(err, &healthErr) {
    fmt.Printf("unhealthy: %s\n", healthErr.Status)
}
```

---

### 5. 需要时创建自定义错误类型

**说明**: 为携带额外上下文的错误定义自定义错误类型。

**通过标准**: 自定义错误类型实现 `error` interface，携带相关上下文。

**不通过标准**: 过度使用自定义类型，或上下文可以放在 wrap 消息中。

**严重程度**: 低

**建议**:
```go
type HealthError struct {
    Status  string
    Details string
}

func (e *HealthError) Error() string {
    return fmt.Sprintf("unhealthy: %s", e.Status)
}
```

---

### 6. 不要同时记录和返回错误

**说明**: 要么记录错误，要么返回错误，不要两者都做。

**通过标准**: 错误仅在顶层记录，底层只返回。

**不通过标准**: 同一错误在向上传播过程中被多次记录。

**严重程度**: 中

**建议**:
```go
// 库代码 — 只返回
func loadConfig() (*Config, error) {
    data, err := os.ReadFile(path)
    if err != nil {
        return nil, fmt.Errorf("read config: %w", err)
    }
    return parseConfig(data)
}

// 顶层 — 记录并处理
func Execute() {
    if err := rootCmd.Execute(); err != nil {
        fmt.Fprintf(os.Stderr, "Error: %v\n", err)
        os.Exit(1)
    }
}
```

---

### 7. 就近处理错误

**说明**: 尽可能在错误发生处附近处理错误。

**通过标准**: 错误在调用后立即处理，没有远距离错误检查。

**不通过标准**: 错误被存储后延迟检查，复杂的错误处理逻辑。

**严重程度**: 中

---

### 8. 使用提前返回

**说明**: 使用提前返回处理错误，减少嵌套。

**通过标准**: 函数使用提前返回，正常路径不深层嵌套。

**不通过标准**: 深层嵌套的 else 块，复杂的控制流。

**严重程度**: 中

**建议**:
```go
// 正确 — 提前返回
func process(name string) error {
    if name == "" {
        return errors.New("name required")
    }
    data, err := load(name)
    if err != nil {
        return fmt.Errorf("load %s: %w", name, err)
    }
    return save(data)  // 正常路径在最后
}
```

---

### 9. 提供可操作的错误消息

**说明**: 错误消息应帮助用户理解该怎么做。

**通过标准**: 错误消息描述问题并建议解决方案。

**不通过标准**: 晦涩的错误消息，缺少上下文的技术术语。

**严重程度**: 中

**建议**:
```go
// 正确 — 可操作
return fmt.Errorf("service %s failed to start, check logs for details", name)

// 错误 — 不可操作
return errors.New("start failed")
```

---

### 10. panic 仅用于编程错误

**说明**: `panic` 仅用于不可恢复的编程错误，而非运行时错误。

**通过标准**: panic 仅用于不变量违反、nil 指针保护或初始化失败。

**不通过标准**: panic 用于预期的运行时错误如文件未找到。

**严重程度**: 高

**建议**:
```go
// 可接受 — 编程错误
func MustParse(s string) *Config {
    cfg, err := Parse(s)
    if err != nil {
        panic(fmt.Sprintf("invalid config: %v", err))
    }
    return cfg
}

// 错误 — 运行时错误
func ReadFile(path string) []byte {
    data, err := os.ReadFile(path)
    if err != nil {
        panic(err)  // 绝不要这样做
    }
    return data
}
```
