# 测试模式

Go 测试编写最佳实践。

## 检查清单

### 1. 使用表驱动测试

**说明**: 将测试组织为输入和预期输出的表格。

**通过标准**: 复杂测试场景使用表驱动模式，易于添加用例。

**不通过标准**: 重复的测试代码，难以添加新测试用例。

**严重程度**: 中

**建议**:
```go
func TestProcess(t *testing.T) {
    tests := []struct {
        name        string
        input       string
        want        string
        wantErr     bool
        errContains string
    }{
        {
            name:    "valid input",
            input:   "hello",
            want:    "HELLO",
            wantErr: false,
        },
        {
            name:        "empty input returns error",
            input:       "",
            wantErr:     true,
            errContains: "empty input",
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got, err := Process(tt.input)
            // 断言...
        })
    }
}
```

---

### 2. 使用 t.Run 创建子测试

**说明**: 使用 `t.Run()` 创建命名子测试，获得更好的输出和隔离性。

**通过标准**: 所有表驱动测试使用 `t.Run()`，子测试有描述性名称。

**不通过标准**: 测试没有子测试，不清楚哪个用例失败。

**严重程度**: 中

---

### 3. 使用 interface 实现 mock

**说明**: 为外部依赖定义 interface 以支持 mock。

**通过标准**: 外部依赖（HTTP、文件系统）通过 interface 访问。

**不通过标准**: 直接使用具体类型，无法在没有真实依赖的情况下测试。

**严重程度**: 高

**建议**:
```go
// 定义 interface
type HTTPClient interface {
    Do(req *http.Request) (*http.Response, error)
}

// mock 实现
type mockHTTPClient struct {
    response *http.Response
    err      error
}

func (m *mockHTTPClient) Do(req *http.Request) (*http.Response, error) {
    return m.response, m.err
}
```

---

### 4. 同时测试成功和错误用例

**说明**: 每个测试应验证正常路径和错误条件。

**通过标准**: 测试包含错误用例，同时有 `wantErr: true` 和 `wantErr: false`。

**不通过标准**: 只测试正常路径，错误处理未测试。

**严重程度**: 高

---

### 5. 使用 t.TempDir 创建临时文件

**说明**: 需要临时目录的测试使用 `t.TempDir()`。

**通过标准**: 测试使用 `t.TempDir()` 自动清理，无临时文件泄漏。

**不通过标准**: 手动创建临时目录，忘记在 defer 中清理。

**严重程度**: 中

**建议**:
```go
func TestFilePersistence(t *testing.T) {
    tempDir := t.TempDir()  // 自动清理
    // 使用 tempDir...
}
```

---

### 6. 使用 t.Cleanup 进行资源清理

**说明**: 使用 `t.Cleanup()` 注册测试完成后必须运行的清理操作。

**通过标准**: 资源通过 `t.Cleanup()` 注册，即使失败也会清理。

**不通过标准**: defer 中的清理在 fatal 时不运行，资源泄漏。

**严重程度**: 中

**建议**:
```go
func TestWithEnvVar(t *testing.T) {
    orig := os.Getenv("MY_VAR")
    os.Setenv("MY_VAR", "test-value")
    t.Cleanup(func() {
        if orig != "" {
            os.Setenv("MY_VAR", orig)
        } else {
            os.Unsetenv("MY_VAR")
        }
    })
    // 测试代码...
}
```

---

### 7. 使用 t.Helper 标记测试辅助函数

**说明**: 用 `t.Helper()` 标记测试辅助函数，获得更好的错误报告。

**通过标准**: 辅助函数调用 `t.Helper()`，错误指向实际测试行。

**不通过标准**: 错误指向辅助函数而非失败的测试。

**严重程度**: 低

**建议**:
```go
func assertNoError(t *testing.T, err error) {
    t.Helper()  // 错误将指向调用者
    if err != nil {
        t.Fatalf("unexpected error: %v", err)
    }
}
```

---

### 8. 测试文件命名规范

**说明**: 测试文件应命名为 `*_test.go`，放在同一包中。

**通过标准**: 测试文件遵循 `xxx_test.go` 模式，与源文件同目录。

**不通过标准**: 测试在单独目录中，非标准命名。

**严重程度**: 低

---

### 9. 安全时使用并行测试

**说明**: 不共享状态的测试使用 `t.Parallel()`。

**通过标准**: 独立测试并行运行，测试套件更快完成。

**不通过标准**: 共享状态的测试并行运行导致不稳定。

**严重程度**: 低

**建议**:
```go
func TestSomething(t *testing.T) {
    tests := []struct{...}
    for _, tt := range tests {
        tt := tt  // 捕获循环变量
        t.Run(tt.name, func(t *testing.T) {
            t.Parallel()  // 无共享状态时安全
            // 测试代码...
        })
    }
}
```

---

### 10. 验证错误消息内容

**说明**: 测试错误用例时，验证错误消息内容。

**通过标准**: 错误测试验证错误消息包含预期文本。

**不通过标准**: 只检查 `err != nil`，错误类型不对也能通过。

**严重程度**: 中

**建议**:
```go
if err == nil {
    t.Fatal("expected error")
}
if !strings.Contains(err.Error(), tt.errContains) {
    t.Errorf("error %q should contain %q", err, tt.errContains)
}
```
