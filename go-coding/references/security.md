# 安全模式

Go 安全编码最佳实践。

## 检查清单

### 1. 禁止在日志中输出凭证或 token

**说明**: 敏感数据（API key、token、密码）绝不能出现在日志中。

**通过标准**: 敏感值在记录前已脱敏，应用了清洗处理。

**不通过标准**: 凭证出现在 debug 日志中，token 被打印到 stderr。

**严重程度**: 严重

**建议**:
```go
// 对所有日志进行脱敏
func sanitizeLog(msg string) string {
    sanitized := msg
    for _, sp := range sensitivePatterns {
        sanitized = sp.pattern.ReplaceAllString(sanitized, sp.replacement)
    }
    return sanitized
}

// 显式脱敏 header
func logHeaders(kind string, hdr http.Header) {
    sensitiveHeaders := map[string]struct{}{
        "authorization": {},
        "cookie":        {},
        "x-api-key":     {},
    }
    for k, vals := range hdr {
        if _, sensitive := sensitiveHeaders[strings.ToLower(k)]; sensitive {
            log.Printf("%s header: %s: [REDACTED]", kind, k)
        } else {
            log.Printf("%s header: %s: %s", kind, k, vals)
        }
    }
}
```

---

### 2. 使用正则脱敏日志

**说明**: 应用正则模式自动脱敏日志中的敏感数据。

**通过标准**: 日志脱敏能捕获 JWT、API key、密码等秘密信息。

**不通过标准**: 仅手动脱敏，模式遗漏常见凭证格式。

**严重程度**: 高

**建议**:
```go
var sensitivePatterns = []struct {
    pattern     *regexp.Regexp
    replacement string
}{
    // JWT token
    {regexp.MustCompile(`\beyJ[a-zA-Z0-9_-]+\.eyJ[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+`), "[REDACTED-JWT]"},
    // API key
    {regexp.MustCompile(`\b(sk|pk|sess)-[a-zA-Z0-9\-_]{20,}`), "[REDACTED-KEY]"},
    // Bearer token
    {regexp.MustCompile(`(?i)(bearer\s+)[a-zA-Z0-9\-_\.]+`), "${1}[REDACTED]"},
    // 密码
    {regexp.MustCompile(`(?i)(password[=:\s]+['"]?)[^\s&'"]+`), "${1}[REDACTED]"},
}
```

---

### 3. 验证所有外部输入

**说明**: 使用前验证来自用户、文件和网络的输入。

**通过标准**: 所有用户输入已验证，强制执行长度限制，拒绝无效输入。

**不通过标准**: 未检查的输入传递给系统调用，文件路径未验证。

**严重程度**: 严重

**建议**:
```go
func processFile(path string) error {
    if path == "" {
        return errors.New("path required")
    }
    cleanPath := filepath.Clean(path)
    if !strings.HasPrefix(cleanPath, allowedDir) {
        return errors.New("path outside allowed directory")
    }
    info, err := os.Stat(cleanPath)
    if err != nil {
        return fmt.Errorf("cannot access file: %w", err)
    }
    if !info.Mode().IsRegular() {
        return errors.New("not a regular file")
    }
    return nil
}
```

---

### 4. HTTP 请求必须设置超时

**说明**: 所有 HTTP 请求必须有超时，防止资源耗尽。

**通过标准**: 所有 HTTP 请求使用带超时的 context，无无限等待。

**不通过标准**: 请求无超时，使用默认 http.Client。

**严重程度**: 高

**建议**:
```go
func fetchData(url string) ([]byte, error) {
    ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
    defer cancel()

    req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
    if err != nil {
        return nil, err
    }
    client := &http.Client{Timeout: 12 * time.Second}
    resp, err := client.Do(req)
    if err != nil {
        return nil, err
    }
    defer resp.Body.Close()
    return io.ReadAll(resp.Body)
}
```

---

### 5. 限制响应体大小

**说明**: 限制从外部源读取的数据大小。

**通过标准**: 响应体读取有大小限制，大体积数据以流方式处理。

**不通过标准**: 无限制读取可能耗尽内存。

**严重程度**: 中

**建议**:
```go
const maxBodySize = 10 * 1024 * 1024  // 10MB

func readBody(resp *http.Response) ([]byte, error) {
    limitedReader := io.LimitReader(resp.Body, maxBodySize)
    data, err := io.ReadAll(limitedReader)
    if err != nil {
        return nil, err
    }
    if int64(len(data)) == maxBodySize {
        return nil, errors.New("response body too large")
    }
    return data, nil
}
```

---

### 6. 安全的文件权限

**说明**: 创建文件时使用限制性权限，绝不使用全局可写。

**通过标准**: 文件以 0644 或更严格权限创建，目录以 0755。

**不通过标准**: 全局可写文件（0666、0777），敏感数据在全局可读文件中。

**严重程度**: 高

**建议**:
```go
// 配置文件 — 仅所有者读写
os.WriteFile(path, data, 0600)

// 日志文件 — 所有者读写，其他只读
os.WriteFile(logPath, data, 0644)

// 目录 — 所有者完全，其他读执行
os.MkdirAll(dir, 0755)
```

---

### 7. Shell 参数转义

**说明**: 构建 shell 命令时，正确转义参数。

**通过标准**: shell 参数已转义，不可能发生命令注入。

**不通过标准**: 用户输入直接拼入 shell 命令，未转义特殊字符。

**严重程度**: 严重

**建议**:
```go
// 使用 exec.Command 分离参数（安全）
cmd := exec.Command("git", "commit", "-m", message)

// 绝不要这样做
cmd := exec.Command("sh", "-c", "git commit -m " + message)
```

---

### 8. 防止路径遍历

**说明**: 验证文件路径以防止目录遍历攻击。

**通过标准**: 所有路径用 `filepath.Clean` 清理，路径相对基目录验证。

**不通过标准**: 用户控制的路径直接使用，`../` 序列可能生效。

**严重程度**: 严重

**建议**:
```go
func safeReadFile(baseDir, userPath string) ([]byte, error) {
    cleanPath := filepath.Clean(userPath)
    cleanPath = strings.TrimPrefix(cleanPath, string(filepath.Separator))
    fullPath := filepath.Join(baseDir, cleanPath)
    if !strings.HasPrefix(fullPath, filepath.Clean(baseDir)+string(filepath.Separator)) {
        return nil, errors.New("path escapes base directory")
    }
    return os.ReadFile(fullPath)
}
```

---

### 9. 优雅处理信号

**说明**: 处理 OS 信号实现优雅关闭和资源清理。

**通过标准**: SIGINT 和 SIGTERM 被处理，关闭时资源被清理。

**不通过标准**: 突然终止，资源处于不一致状态。

**严重程度**: 中

**建议**:
```go
func setupSignalHandler(cleanup func()) {
    sigCh := make(chan os.Signal, 1)
    signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
    go func() {
        <-sigCh
        fmt.Println("\nShutting down gracefully...")
        cleanup()
        os.Exit(0)
    }()
}
```

---

### 10. 错误消息中脱敏敏感数据

**说明**: 错误消息不应暴露敏感数据。

**通过标准**: 错误消息描述问题但不暴露秘密。

**不通过标准**: 密码或 token 出现在错误输出中。

**严重程度**: 高

**建议**:
```go
// 错误 — 暴露 token
return fmt.Errorf("auth failed with token: %s", token)

// 正确 — 描述问题但不暴露秘密
return fmt.Errorf("auth failed: invalid or expired token")
```
