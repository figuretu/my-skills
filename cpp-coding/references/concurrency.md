# 并发编程最佳实践

## 基本原则

1. **避免共享可变状态** - 优先使用消息传递而非共享内存
2. **最小化临界区** - 持有锁的时间越短越好
3. **避免死锁** - 使用锁顺序、超时、try_lock
4. **使用 RAII 管理锁** - 永远不要手动 lock/unlock

## 互斥锁

### std::mutex 和 RAII 锁

```cpp
class ThreadSafeCounter {
public:
    void Increment() {
        std::lock_guard<std::mutex> lock(mutex_);
        ++count_;
    }  // 自动释放锁

    int Get() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return count_;
    }

private:
    mutable std::mutex mutex_;
    int count_ = 0;
};
```

### std::unique_lock - 更灵活的锁

```cpp
void FlexibleLocking() {
    std::unique_lock<std::mutex> lock(mutex_);

    // 可以提前释放锁
    DoSomethingWithLock();
    lock.unlock();

    // 做一些不需要锁的工作
    DoSomethingWithoutLock();

    // 重新获取锁
    lock.lock();
    DoMoreWithLock();
}
```

### 避免死锁

```cpp
// Bad: 可能死锁
void Transfer(Account& from, Account& to, int amount) {
    std::lock_guard<std::mutex> lock1(from.mutex_);
    std::lock_guard<std::mutex> lock2(to.mutex_);  // 如果另一个线程反向锁定，死锁！
    from.balance_ -= amount;
    to.balance_ += amount;
}

// Good: 使用 std::lock 同时锁定多个互斥锁
void Transfer(Account& from, Account& to, int amount) {
    std::scoped_lock lock(from.mutex_, to.mutex_);  // C++17
    from.balance_ -= amount;
    to.balance_ += amount;
}
```

## 原子操作

### std::atomic - 无锁同步

```cpp
class ThreadSafeCounter {
public:
    void Increment() {
        count_.fetch_add(1, std::memory_order_relaxed);
    }

    int Get() const {
        return count_.load(std::memory_order_relaxed);
    }

private:
    std::atomic<int> count_{0};
};
```

### 内存顺序

```cpp
// Relaxed: 最弱的顺序，仅保证原子性
counter.fetch_add(1, std::memory_order_relaxed);

// Acquire-Release: 同步点
// Release: 写操作对其他线程可见
data.store(42, std::memory_order_release);

// Acquire: 读操作看到之前的写操作
int value = data.load(std::memory_order_acquire);

// Sequentially Consistent: 最强的顺序（默认）
counter.fetch_add(1, std::memory_order_seq_cst);
```

## 条件变量

### 生产者-消费者模式

```cpp
class Queue {
public:
    void Push(int value) {
        {
            std::lock_guard<std::mutex> lock(mutex_);
            queue_.push(value);
        }
        cv_.notify_one();  // 通知等待的线程
    }

    int Pop() {
        std::unique_lock<std::mutex> lock(mutex_);
        cv_.wait(lock, [this] { return !queue_.empty(); });  // 等待直到队列非空
        int value = queue_.front();
        queue_.pop();
        return value;
    }

private:
    std::mutex mutex_;
    std::condition_variable cv_;
    std::queue<int> queue_;
};
```

## 线程安全的单例

### Meyers Singleton (C++11)

```cpp
class Singleton {
public:
    static Singleton& Instance() {
        static Singleton instance;  // C++11 保证线程安全
        return instance;
    }

    Singleton(const Singleton&) = delete;
    Singleton& operator=(const Singleton&) = delete;

private:
    Singleton() = default;
};
```

### std::call_once

```cpp
class Singleton {
public:
    static Singleton& Instance() {
        std::call_once(init_flag_, []() {
            instance_.reset(new Singleton());
        });
        return *instance_;
    }

private:
    static std::once_flag init_flag_;
    static std::unique_ptr<Singleton> instance_;
};
```

## 读写锁

### std::shared_mutex (C++17)

```cpp
class ThreadSafeCache {
public:
    std::string Get(const std::string& key) const {
        std::shared_lock<std::shared_mutex> lock(mutex_);  // 共享读锁
        return cache_.at(key);
    }

    void Set(const std::string& key, const std::string& value) {
        std::unique_lock<std::shared_mutex> lock(mutex_);  // 独占写锁
        cache_[key] = value;
    }

private:
    mutable std::shared_mutex mutex_;
    std::map<std::string, std::string> cache_;
};
```

## 常见陷阱

### 数据竞争

```cpp
// Bad: 数据竞争
class Counter {
public:
    void Increment() { ++count_; }  // 不是原子操作！
    int Get() const { return count_; }

private:
    int count_ = 0;
};

// Good: 使用互斥锁或原子变量
class Counter {
public:
    void Increment() {
        std::lock_guard<std::mutex> lock(mutex_);
        ++count_;
    }

private:
    std::mutex mutex_;
    int count_ = 0;
};
```

### 虚假唤醒

```cpp
// Bad: 没有检查条件
cv_.wait(lock);
// 可能被虚假唤醒，条件不满足

// Good: 使用谓词
cv_.wait(lock, [this] { return !queue_.empty(); });
```

### 持有锁时调用外部代码

```cpp
// Bad: 持有锁时调用回调
void Process() {
    std::lock_guard<std::mutex> lock(mutex_);
    callback_();  // 回调可能很慢或死锁！
}

// Good: 释放锁后调用回调
void Process() {
    {
        std::lock_guard<std::mutex> lock(mutex_);
        // 准备数据
    }
    callback_();  // 在锁外调用
}
```

## 性能考虑

### 减少锁竞争

```cpp
// Bad: 粗粒度锁
class Cache {
    std::mutex mutex_;
    std::map<std::string, Data> cache_;
};

// Good: 细粒度锁（分片）
class Cache {
    static constexpr size_t kShards = 16;
    std::array<std::mutex, kShards> mutexes_;
    std::array<std::map<std::string, Data>, kShards> shards_;

    size_t GetShard(const std::string& key) const {
        return std::hash<std::string>{}(key) % kShards;
    }
};
```

### 无锁数据结构

对于高性能场景，考虑使用无锁数据结构（如 lock-free queue），但要注意复杂性。
