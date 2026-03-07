# 错误处理最佳实践

## Result 类型模式

现代 C++ 项目通常使用 `Result<T>` 或 `Status` 类型来表示可能失败的操作，而不是异常。

### Result<T> 基本用法

```cpp
// Result 类型定义（简化版）
template<typename T>
class Result {
public:
    static Result Ok(T value);
    static Result Error(const std::string& message);

    bool ok() const;
    const T& value() const;
    const std::string& error() const;
};

// 使用 Result
Result<int> Divide(int a, int b) {
    if (b == 0) {
        return Result<int>::Error("Division by zero");
    }
    return Result<int>::Ok(a / b);
}

void UseResult() {
    auto result = Divide(10, 2);
    if (result.ok()) {
        std::cout << "Result: " << result.value() << std::endl;
    } else {
        std::cerr << "Error: " << result.error() << std::endl;
    }
}
```

## 错误处理宏

项目通常提供宏来简化错误传播，避免重复的 if 检查。

### RETURN_IF_ERROR

检查表达式返回的 Status/Result，如果失败则立即返回。

```cpp
// 宏定义（简化版）
#define RETURN_IF_ERROR(expr) \
    do { \
        auto _status = (expr); \
        if (!_status.ok()) { \
            return _status; \
        } \
    } while (0)

// 使用示例
Status ProcessData(const Data& data) {
    RETURN_IF_ERROR(ValidateData(data));
    RETURN_IF_ERROR(TransformData(data));
    RETURN_IF_ERROR(SaveData(data));
    return Status::OK();
}
```

### ASSIGN_OR_RETURN

从 Result<T> 中提取值，如果失败则返回错误。

```cpp
// 宏定义（简化版）
#define ASSIGN_OR_RETURN(lhs, expr) \
    auto _result = (expr); \
    if (!_result.ok()) { \
        return _result.status(); \
    } \
    lhs = std::move(_result.value())

// 使用示例
Result<Widget> CreateWidget(const Config& config) {
    ASSIGN_OR_RETURN(auto validated_config, ValidateConfig(config));
    ASSIGN_OR_RETURN(auto widget, BuildWidget(validated_config));
    return widget;
}
```

### RETURN_ERROR

返回带消息的错误。

```cpp
// 宏定义（简化版）
#define RETURN_ERROR(msg) \
    return Status::Error(msg)

// 使用示例
Status OpenFile(const std::string& path) {
    if (path.empty()) {
        RETURN_ERROR("File path is empty");
    }
    // ...
}
```

## 异常 vs Result

### 何时使用异常

- 构造函数失败（无法返回 Result）
- 真正的异常情况（如内存耗尽）
- 与标准库交互（STL 使用异常）

### 何时使用 Result

- 预期的错误情况（如文件不存在、网络超时）
- 性能敏感的代码路径
- 需要明确错误处理的 API

```cpp
// Good: 构造函数使用异常
class Database {
public:
    Database(const std::string& path) {
        if (!Connect(path)) {
            throw std::runtime_error("Failed to connect to database");
        }
    }
};

// Good: 普通函数使用 Result
Result<Data> Query(const std::string& sql) {
    if (sql.empty()) {
        return Result<Data>::Error("Empty SQL query");
    }
    // ...
}
```

## noexcept 规范

### 何时使用 noexcept

- 析构函数（默认 noexcept）
- 移动构造函数和移动赋值运算符
- swap 函数
- 确定不会抛出异常的函数

```cpp
class Widget {
public:
    // 析构函数默认 noexcept
    ~Widget() = default;

    // 移动操作应该 noexcept
    Widget(Widget&& other) noexcept
        : data_(std::move(other.data_)) {}

    Widget& operator=(Widget&& other) noexcept {
        data_ = std::move(other.data_);
        return *this;
    }

    // swap 应该 noexcept
    void swap(Widget& other) noexcept {
        std::swap(data_, other.data_);
    }

private:
    std::vector<int> data_;
};
```

### noexcept 的性能优势

```cpp
// 容器操作会检查 noexcept
std::vector<Widget> widgets;
widgets.push_back(Widget());  // 如果移动构造是 noexcept，使用移动；否则拷贝
```

## 错误传播模式

### 链式调用

```cpp
Result<Output> ProcessPipeline(const Input& input) {
    ASSIGN_OR_RETURN(auto step1, Step1(input));
    ASSIGN_OR_RETURN(auto step2, Step2(step1));
    ASSIGN_OR_RETURN(auto step3, Step3(step2));
    return step3;
}
```

### 错误上下文

```cpp
Result<Data> LoadData(const std::string& path) {
    auto result = ReadFile(path);
    if (!result.ok()) {
        return Result<Data>::Error(
            "Failed to load data from " + path + ": " + result.error());
    }
    return ParseData(result.value());
}
```

### 批量错误处理

```cpp
Status ProcessBatch(const std::vector<Item>& items) {
    std::vector<std::string> errors;

    for (const auto& item : items) {
        auto status = ProcessItem(item);
        if (!status.ok()) {
            errors.push_back(status.error());
        }
    }

    if (!errors.empty()) {
        return Status::Error("Batch processing failed: " +
                           JoinStrings(errors, "; "));
    }

    return Status::OK();
}
```

## 常见陷阱

### 忽略错误

```cpp
// Bad: 忽略返回值
ProcessData(data);  // 如果失败怎么办？

// Good: 检查错误
auto status = ProcessData(data);
if (!status.ok()) {
    LOG(ERROR) << "Failed to process data: " << status.error();
    return status;
}
```

### 异常安全性

```cpp
// Bad: 不是异常安全的
void Process() {
    Resource* res = AcquireResource();
    DoSomething();  // 如果抛出异常，res 泄漏
    ReleaseResource(res);
}

// Good: 使用 RAII
void Process() {
    auto res = std::make_unique<Resource>(AcquireResource());
    DoSomething();  // 即使抛出异常，res 也会自动释放
}
```

### 过度使用异常

```cpp
// Bad: 用异常控制流程
try {
    auto data = FindData(key);
    Process(data);
} catch (const NotFoundException&) {
    // 数据不存在是预期情况，不应该用异常
}

// Good: 使用 Result 或 optional
auto data = FindData(key);
if (data.has_value()) {
    Process(data.value());
}
```
