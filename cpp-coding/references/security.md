# 安全编码最佳实践

## 输入验证

### 边界检查

```cpp
// Bad: 没有边界检查
void ProcessArray(const int* data, size_t size, size_t index) {
    int value = data[index];  // 可能越界！
}

// Good: 边界检查
Result<int> GetArrayElement(const int* data, size_t size, size_t index) {
    if (index >= size) {
        return Result<int>::Error("Index out of bounds");
    }
    return Result<int>::Ok(data[index]);
}

// Better: 使用 std::vector
int GetElement(const std::vector<int>& data, size_t index) {
    return data.at(index);  // 自动边界检查，越界抛出异常
}
```

### 字符串安全

```cpp
// Bad: 不安全的字符串操作
char buffer[100];
strcpy(buffer, user_input);  // 缓冲区溢出！

// Good: 使用 std::string
std::string buffer = user_input;

// Good: 使用安全的 C 函数
char buffer[100];
strncpy(buffer, user_input, sizeof(buffer) - 1);
buffer[sizeof(buffer) - 1] = '\0';
```

## 整数安全

### 整数溢出

```cpp
// Bad: 整数溢出
int Add(int a, int b) {
    return a + b;  // 可能溢出！
}

// Good: 检查溢出
Result<int> SafeAdd(int a, int b) {
    if (a > 0 && b > INT_MAX - a) {
        return Result<int>::Error("Integer overflow");
    }
    if (a < 0 && b < INT_MIN - a) {
        return Result<int>::Error("Integer underflow");
    }
    return Result<int>::Ok(a + b);
}

// Better: 使用 C++20 的安全整数运算（如果可用）
#include <limits>
Result<int> SafeAdd(int a, int b) {
    int result;
    if (__builtin_add_overflow(a, b, &result)) {
        return Result<int>::Error("Integer overflow");
    }
    return Result<int>::Ok(result);
}
```

### 类型转换

```cpp
// Bad: 不安全的类型转换
size_t size = -1;  // 变成一个很大的正数！
std::vector<int> vec(size);  // 内存耗尽

// Good: 检查转换
Result<size_t> ToSize(int value) {
    if (value < 0) {
        return Result<size_t>::Error("Negative value");
    }
    return Result<size_t>::Ok(static_cast<size_t>(value));
}
```

## 内存安全

### 缓冲区溢出

```cpp
// Bad: 缓冲区溢出
void CopyData(char* dest, const char* src) {
    while (*src) {
        *dest++ = *src++;  // 没有检查 dest 的大小！
    }
}

// Good: 使用 std::string 或 std::vector
void CopyData(std::string& dest, const std::string& src) {
    dest = src;  // 自动管理内存
}

// Good: 使用安全的 API
void CopyData(char* dest, size_t dest_size, const char* src) {
    strncpy(dest, src, dest_size - 1);
    dest[dest_size - 1] = '\0';
}
```

### Use-After-Free

```cpp
// Bad: Use-after-free
Widget* widget = new Widget();
delete widget;
widget->DoSomething();  // 悬空指针！

// Good: 使用智能指针
auto widget = std::make_unique<Widget>();
// widget 自动释放，无法 use-after-free
```

### Double-Free

```cpp
// Bad: Double-free
Widget* widget = new Widget();
delete widget;
delete widget;  // 未定义行为！

// Good: 使用智能指针
auto widget = std::make_unique<Widget>();
// 自动管理，无法 double-free
```

## 并发安全

### 数据竞争

```cpp
// Bad: 数据竞争
class Counter {
    int count_ = 0;
public:
    void Increment() { ++count_; }  // 多线程不安全！
};

// Good: 使用互斥锁
class Counter {
    std::mutex mutex_;
    int count_ = 0;
public:
    void Increment() {
        std::lock_guard<std::mutex> lock(mutex_);
        ++count_;
    }
};

// Better: 使用原子变量
class Counter {
    std::atomic<int> count_{0};
public:
    void Increment() { count_.fetch_add(1); }
};
```

## 资源泄漏

### 文件句柄

```cpp
// Bad: 文件句柄泄漏
void ProcessFile(const std::string& path) {
    FILE* file = fopen(path.c_str(), "r");
    if (!file) return;

    ProcessData(file);  // 如果抛出异常，file 泄漏
    fclose(file);
}

// Good: RAII 封装
void ProcessFile(const std::string& path) {
    std::ifstream file(path);
    if (!file) return;

    ProcessData(file);  // 即使抛出异常，file 也会自动关闭
}
```

### 网络连接

```cpp
// Good: RAII 封装网络连接
class Connection {
public:
    explicit Connection(const std::string& host) {
        socket_ = connect(host);
        if (socket_ < 0) {
            throw std::runtime_error("Failed to connect");
        }
    }

    ~Connection() {
        if (socket_ >= 0) {
            close(socket_);
        }
    }

    Connection(const Connection&) = delete;
    Connection& operator=(const Connection&) = delete;

private:
    int socket_;
};
```

## 注入攻击

### SQL 注入

```cpp
// Bad: SQL 注入
std::string query = "SELECT * FROM users WHERE name = '" + user_input + "'";
// 如果 user_input = "'; DROP TABLE users; --"，数据库被破坏！

// Good: 使用参数化查询
PreparedStatement stmt = db.Prepare("SELECT * FROM users WHERE name = ?");
stmt.Bind(1, user_input);
stmt.Execute();
```

### 命令注入

```cpp
// Bad: 命令注入
std::string command = "ls " + user_input;
system(command.c_str());  // 如果 user_input = "; rm -rf /", 灾难！

// Good: 避免使用 system，使用安全的 API
// 或者严格验证输入
Result<void> ListDirectory(const std::string& path) {
    if (!IsValidPath(path)) {
        return Result<void>::Error("Invalid path");
    }
    // 使用安全的文件系统 API
    for (const auto& entry : std::filesystem::directory_iterator(path)) {
        std::cout << entry.path() << std::endl;
    }
    return Result<void>::Ok();
}
```

## 敏感数据

### 密码和密钥

```cpp
// Bad: 密码明文存储
std::string password = "secret123";

// Good: 使用安全的内存清理
class SecureString {
public:
    explicit SecureString(const std::string& data) : data_(data) {}

    ~SecureString() {
        // 清零内存
        std::fill(data_.begin(), data_.end(), '\0');
    }

    const std::string& Get() const { return data_; }

private:
    std::string data_;
};
```

### 日志中的敏感信息

```cpp
// Bad: 日志泄漏敏感信息
LOG(INFO) << "User login: " << username << ", password: " << password;

// Good: 不记录敏感信息
LOG(INFO) << "User login: " << username;

// Good: 脱敏
LOG(INFO) << "User login: " << username << ", password: ****";
```

## 时间攻击

### 字符串比较

```cpp
// Bad: 时间攻击
bool CheckPassword(const std::string& input, const std::string& expected) {
    return input == expected;  // 比较时间与匹配位置相关
}

// Good: 常量时间比较
bool CheckPassword(const std::string& input, const std::string& expected) {
    if (input.size() != expected.size()) {
        return false;
    }

    volatile int result = 0;
    for (size_t i = 0; i < input.size(); ++i) {
        result |= input[i] ^ expected[i];
    }
    return result == 0;
}
```

## 安全检查清单

- [ ] 所有外部输入都经过验证
- [ ] 没有缓冲区溢出风险
- [ ] 没有整数溢出风险
- [ ] 使用智能指针管理内存
- [ ] 多线程代码使用适当的同步
- [ ] 资源使用 RAII 管理
- [ ] 没有 SQL/命令注入风险
- [ ] 敏感数据不记录到日志
- [ ] 使用常量时间比较敏感数据
