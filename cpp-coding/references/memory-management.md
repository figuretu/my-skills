# 内存管理最佳实践

## RAII (Resource Acquisition Is Initialization)

RAII 是 C++ 中最重要的资源管理惯用法。核心思想：资源的生命周期与对象的生命周期绑定。

### 基本原则

- 在构造函数中获取资源
- 在析构函数中释放资源
- 利用栈对象的自动析构特性

```cpp
// Good: RAII 封装文件句柄
class FileHandle {
public:
    explicit FileHandle(const std::string& path) {
        fd_ = open(path.c_str(), O_RDONLY);
        if (fd_ < 0) {
            throw std::runtime_error("Failed to open file");
        }
    }

    ~FileHandle() {
        if (fd_ >= 0) {
            close(fd_);
        }
    }

    // 禁止拷贝，允许移动
    FileHandle(const FileHandle&) = delete;
    FileHandle& operator=(const FileHandle&) = delete;
    FileHandle(FileHandle&& other) noexcept : fd_(other.fd_) {
        other.fd_ = -1;
    }

    int get() const { return fd_; }

private:
    int fd_;
};
```

## 智能指针

### unique_ptr - 独占所有权

90% 的情况应该使用 `unique_ptr`。

```cpp
// Good: 使用 unique_ptr
std::unique_ptr<Widget> CreateWidget() {
    return std::make_unique<Widget>();
}

void UseWidget() {
    auto widget = CreateWidget();
    widget->DoSomething();
}  // 自动释放

// Good: 转移所有权
std::unique_ptr<Widget> widget1 = std::make_unique<Widget>();
std::unique_ptr<Widget> widget2 = std::move(widget1);  // 转移所有权
// widget1 现在为 nullptr
```

### shared_ptr - 共享所有权

仅在真正需要共享所有权时使用。过度使用 `shared_ptr` 会导致：
- 性能开销（引用计数的原子操作）
- 循环引用导致内存泄漏
- 所有权不清晰

```cpp
// Acceptable: 真正需要共享所有权
class Cache {
public:
    std::shared_ptr<Data> Get(const std::string& key) {
        return cache_[key];  // 多个调用者共享同一份数据
    }

private:
    std::map<std::string, std::shared_ptr<Data>> cache_;
};

// Bad: 不必要的 shared_ptr
void ProcessWidget(std::shared_ptr<Widget> widget) {  // 应该用 Widget& 或 const Widget&
    widget->DoSomething();
}
```

### weak_ptr - 打破循环引用

```cpp
class Node {
public:
    std::shared_ptr<Node> next;
    std::weak_ptr<Node> prev;  // 使用 weak_ptr 打破循环引用
};
```

## 移动语义

### 何时使用移动

- 返回大对象时（RVO 优化失败的情况）
- 转移资源所有权时
- 容器操作时（如 `std::vector::push_back`）

```cpp
// Good: 移动构造
class Buffer {
public:
    Buffer(size_t size) : data_(new char[size]), size_(size) {}

    ~Buffer() { delete[] data_; }

    // 移动构造
    Buffer(Buffer&& other) noexcept
        : data_(other.data_), size_(other.size_) {
        other.data_ = nullptr;
        other.size_ = 0;
    }

    // 移动赋值
    Buffer& operator=(Buffer&& other) noexcept {
        if (this != &other) {
            delete[] data_;
            data_ = other.data_;
            size_ = other.size_;
            other.data_ = nullptr;
            other.size_ = 0;
        }
        return *this;
    }

private:
    char* data_;
    size_t size_;
};

// Good: 使用移动
std::vector<Buffer> buffers;
Buffer buf(1024);
buffers.push_back(std::move(buf));  // 移动而非拷贝
```

## 常见陷阱

### 悬空指针

```cpp
// Bad: 返回局部变量的指针
Widget* CreateWidget() {
    Widget widget;
    return &widget;  // 悬空指针！
}

// Good: 返回值或智能指针
std::unique_ptr<Widget> CreateWidget() {
    return std::make_unique<Widget>();
}
```

### 内存泄漏

```cpp
// Bad: 异常导致内存泄漏
void Process() {
    Widget* widget = new Widget();
    DoSomething();  // 如果抛出异常，widget 泄漏
    delete widget;
}

// Good: 使用智能指针
void Process() {
    auto widget = std::make_unique<Widget>();
    DoSomething();  // 即使抛出异常，widget 也会自动释放
}
```

### 双重释放

```cpp
// Bad: 双重释放
Widget* widget = new Widget();
delete widget;
delete widget;  // 未定义行为！

// Good: 智能指针自动管理
auto widget = std::make_unique<Widget>();
// 无需手动释放
```

## 性能考虑

### 避免不必要的拷贝

```cpp
// Bad: 不必要的拷贝
std::vector<int> GetData() {
    std::vector<int> data = LoadData();
    return data;  // 可能触发拷贝
}

// Good: RVO 优化
std::vector<int> GetData() {
    return LoadData();  // 编译器优化，无拷贝
}

// Good: 传引用避免拷贝
void ProcessData(const std::vector<int>& data) {  // const&
    // ...
}
```

### 优先使用栈对象

```cpp
// Bad: 不必要的堆分配
void Process() {
    auto widget = std::make_unique<Widget>();
    widget->DoSomething();
}

// Good: 栈对象
void Process() {
    Widget widget;
    widget.DoSomething();
}
```
