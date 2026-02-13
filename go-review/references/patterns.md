# 惯用 Go 模式

通用 Go 代码惯用模式检查清单。

## 检查清单

### 1. 谨慎使用命名返回值

**说明**: 命名返回值仅在有助于文档说明或配合 defer 错误处理时使用。

**搜索模式**:
```bash
grep -rn "func.*\(.*\).*\(.*,.*\)" --include="*.go" | grep -v "_test.go"
```

**通过标准**: 命名返回值用于文档说明或 defer 模式，而非图方便。

**不通过标准**: 不必要地使用命名返回值，导致裸 return 令人困惑。

**严重程度**: 低

---

### 2. 接受 interface，返回 struct

**说明**: 函数应接受 interface 以提高灵活性，返回具体类型以保持清晰。

**搜索模式**:
```bash
grep -rn "func.*interface{}" --include="*.go"
```

**通过标准**: 函数接受窄 interface（如 `io.Reader`），返回具体 struct。

**不通过标准**: 函数返回 interface 或接受过于宽泛的 `interface{}`。

**严重程度**: 中

**建议**:
```go
// 正确
type HTTPClient interface {
    Do(req *http.Request) (*http.Response, error)
}
func NewClient() *DefaultHTTPClient { ... }

// 避免
func NewClient() HTTPClient { ... }  // 返回 interface
```

---

### 3. 使用构造函数

**说明**: 复杂 struct 应有构造函数进行验证和初始化。

**通过标准**: 构造函数验证输入、设置默认值，必要时返回 error。

**不通过标准**: struct 初始化散落在代码各处，缺少验证。

**严重程度**: 中

**建议**:
```go
func NewManager(dataDir string) (*Manager, error) {
    if dataDir == "" {
        return nil, errors.New("data directory required")
    }
    return &Manager{dataDir: dataDir}, nil
}
```

---

### 4. 使用 Functional Options 模式

**说明**: 对于有多个可选配置参数的 struct，使用 functional options 模式。

**通过标准**: 复杂配置使用 functional options 模式，清晰且可扩展。

**不通过标准**: 构造函数参数列表过长，或过度暴露 struct 字段。

**严重程度**: 低

**建议**:
```go
type Option func(*Config)

func WithTimeout(d time.Duration) Option {
    return func(c *Config) { c.Timeout = d }
}

func NewClient(opts ...Option) *Client {
    cfg := defaultConfig()
    for _, opt := range opts {
        opt(&cfg)
    }
    return &Client{cfg: cfg}
}
```

---

### 5. 使用组合而非继承

**说明**: 使用 struct 嵌入实现组合，而非类继承模式。

**通过标准**: 嵌入用于共享行为（如嵌入 `sync.Mutex`）。

**不通过标准**: 深层继承层次或过度嵌入导致行为不透明。

**严重程度**: 低

**建议**:
```go
type ResourceInfo struct {
    Name string
    mu   sync.RWMutex  // 嵌入用于加锁
}
```

---

### 6. 使用 `defer` 进行资源清理

**说明**: 使用 `defer` 进行资源清理，确保即使在错误路径上也能执行清理。

**通过标准**: 所有文件句柄、锁和连接都使用 `defer` 清理。

**不通过标准**: 在多个 return 点手动清理，存在资源泄漏风险。

**严重程度**: 高

**建议**:
```go
func readFile(path string) ([]byte, error) {
    f, err := os.Open(path)
    if err != nil {
        return nil, err
    }
    defer f.Close()  // 始终执行
    return io.ReadAll(f)
}
```

---

### 7. 保持函数小而专注

**说明**: 函数应只做一件事。复杂逻辑应提取为辅助函数。

**通过标准**: 大多数函数不超过 50 行。复杂逻辑已提取为辅助函数。

**不通过标准**: 巨型函数，深层嵌套逻辑。

**严重程度**: 中

---

### 8. 使用常量替代魔法值

**说明**: 为重复使用的值和配置默认值定义常量。

**通过标准**: 超时、缓冲区大小和配置值定义为常量。

**不通过标准**: 魔法数字散落在代码各处。

**严重程度**: 中

**建议**:
```go
const (
    DefaultTimeout     = 30 * time.Second
    PollInterval       = 500 * time.Millisecond
    MaxRetries         = 3
)
```

---

### 9. 使用类型别名增强语义

**说明**: 定义类型别名为原始类型添加语义含义。

**通过标准**: 定义了领域特定类型如 `Status` 或 `Mode`。

**不通过标准**: 到处使用裸原始类型，缺少语义上下文。

**严重程度**: 低

**建议**:
```go
type SessionMode int

const (
    SessionModeDefault SessionMode = iota
    SessionModeStateless
    SessionModeDev
)
```

---

### 10. 避免包级可变状态

**说明**: 最小化包级变量，优先使用依赖注入。

**通过标准**: 包级状态仅限于单例或不可变配置。

**不通过标准**: 可变的包级状态导致测试困难。

**严重程度**: 中

**建议**: 通过构造函数或函数参数显式传递依赖。包级变量仅用于不可变常量或必要的单例。
