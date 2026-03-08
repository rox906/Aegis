# Room数据库迁移分析报告

## Android版本 vs 鸿蒙版本对比

| 项目 | Android版本 | 鸿蒙版本 |
|------|-------------|----------|
| ORM框架 | Room (Android Jetpack) | `@kit.ArkData` (RdbStore) |
| 数据库名 | `aegis-db` | `aegis.db` |
| 表结构 | 相同 | 相同 |
| 查询方式 | SQL + LiveData | RdbPredicates + ResultSet |

---

## 表结构对比

**Android Room:**

```sql
CREATE TABLE audit_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    event_type INTEGER NOT NULL,
    reference TEXT,
    timestamp INTEGER NOT NULL
)
```

**鸿蒙版本 (相同):**

```sql
CREATE TABLE IF NOT EXISTS audit_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    event_type INTEGER NOT NULL,
    reference TEXT,
    timestamp INTEGER NOT NULL
)
```

---

## 关键差异

### 1. 查询方式不同

**Android版本 (使用SQLite函数):**

```java
@Query("SELECT * FROM audit_logs WHERE timestamp >= strftime('%s', 'now', '-30 days') ORDER BY timestamp DESC")
LiveData<List<AuditLogEntry>> getAll();
```

**鸿蒙版本 (使用Java计算时间):**

```typescript
const cutoff = Date.now() - THIRTY_DAYS_MS;  // 前端计算
const predicates = new relationalStore.RdbPredicates('audit_logs');
predicates.greaterThanOrEqualTo('timestamp', cutoff);
predicates.orderByDesc('timestamp');
```

### 2. 返回类型不同

- **Android版本**: 返回 `LiveData<List<AuditLogEntry>>`，支持自动UI更新
- **鸿蒙版本**: 返回 `Promise<AuditLogEntry[]>`，需要手动刷新

---

## ⚠️ 潜在迁移问题总结

### 1. 时间计算精度问题 ⚠️

**问题**: Android使用SQLite的 `strftime('%s', 'now', '-30 days')` 计算时间30天前的截止点，而鸿蒙版本使用JavaScript的 `Date.now() - THIRTY_DAYS_MS`。

**潜在影响:**
- SQLite的 `strftime` 使用设备本地时区
- JavaScript的 `Date.now()` 返回UTC时间戳
- 如果设备时区不是UTC，两者结果可能不一致

**建议:**

```typescript
// 鸿蒙版本应该考虑时区，或者直接使用SQLite函数计算
// 当前实现：
const cutoff = Date.now() - THIRTY_DAYS_MS;

// 更好的实现（如果鸿蒙支持SQL函数）：
// 使用SQL查询让数据库计算，保持与Android一致
```

### 2. LiveData缺失 ⚠️

**问题**: Android使用Room的 LiveData 实现数据自动观察和UI更新，鸿蒙版本返回普通Promise。

**影响:**
- 鸿蒙版本需要手动调用 `getAuditLogs()` 来刷新数据
- 无法实现自动数据同步

当前鸿蒙代码中未发现自动刷新机制，需要在UI组件中手动调用。

### 3. 空值处理差异 ⚠️

**Android版本:**

```java
@ColumnInfo(name = = "reference")
private final String _reference;  // 可以是null
```

**鸿蒙版本:**

```typescript
const refIndex = resultSet.getColumnIndex('reference');
const reference = resultSet.isColumnNull(refIndex) ? '' : resultSet.getString(refIndex);
```

**问题**: 鸿蒙版本将null转为空字符串 `''`，而Android版本保持null。

**影响:**
- `AuditLogEntry.reference` 类型语义变化
- 如果代码依赖 `reference === null` 判断，鸿蒙版本会失败

### 4. 数据库文件名不同 ⚠️

- Android: `aegis-db`
- 鸿蒙: `aegis.db`

**影响**: 如果用户在同一设备上同时使用两个版本，数据不会共享（这可能是预期的）。

### 5. 缺少审计日志记录调用 ⚠️

检查鸿蒙版本代码，发现以下情况：

**Android版本在以下位置记录审计日志:**
- `VaultManager.initNew()` / `loadFrom()` - 记录解锁
- `VaultBackupManager.scheduleBackup()` - 记录备份创建
- `AegisBackupAgent.onFullBackup()` - 记录Android备份
- 导出功能 - 记录导出事件

**鸿蒙版本:**
- `DatabaseService.insertAuditLog()` 方法已实现
- 但在 `VaultService`、`ExportPage`、`AuthPage` 等关键位置未调用

**示例 - AuthPage.ets:**

```typescript
aboutToAppear(): void {
    const vault = VaultService.getInstance();
    if (!vault.isEncrypted()) {
        try {
            vault.loadVault();
            router.replaceUrl({ url: 'pages/Index' });
            // ❌ 缺少: DatabaseService.getInstance().insertAuditLog(EventType.VAULT_UNLOCKED);
        } catch (err) {
            this.errorMessage = 'Failed to load vault';
            // ❌ 缺少: 记录失败事件
        }
    }
}
```

### 6. 安全级别设置 ℹ️

```typescript
const config: relationalStore.StoreConfig = {
    name: DB_NAME,
    securityLevel: relationalStore.SecurityLevel.S1  // 基础加密
};
```

**问题**: `SecurityLevel.S1` 是基础加密级别，Android版本没有对应的安全级别设置。

**建议**: 考虑使用更高安全级别（如 S3 或 S4）以保护审计日志数据。

### 7. 缺少异常处理 ⚠️

**Android版本:**

```java
@Insert
void insert(AuditLogEntry log);  // Room自动处理异常
```

**鸿蒙版本:**

```typescript
async insertAuditLog(eventType: EventType, reference?: string): Promise<void> {
    // ...
    await this.rdbStore.insert('audit_logs', valueBucket);
    // ❌ 如果插入失败，调用方可能不知道
}
```

---

## 建议修复清单

| 优先级 | 问题 | 建议修复 |
|--------|------|----------|
| 🔴 高 | 缺少审计日志调用 | 在VaultService、ExportPage、AuthPage等关键位置添加 `insertAuditLog()` 调用 |
| 🟡 中 | LiveData缺失 | 考虑实现类似LiveData的观察者模式，或手动刷新机制 |
| 🟡 中 | 空值处理不一致 | 统一null/空字符串的处理，建议保持null以与Android一致 |
| 🟢 低 | 时区问题 | 如果支持SQL函数，使用数据库计算时间；否则文档说明时区差异 |
| 🟢 低 | 安全级别 | 评估是否需要更高的加密级别 |
| 🟢 低 | 异常处理 | 在insertAuditLog中添加try-catch并记录错误 |

---

## 关键代码缺失位置

需要添加审计日志记录的文件：

1. `VaultService.ets` - `loadVault()` 成功时记录 `VAULT_UNLOCKED`
2. `ExportPage.ets` - `exportVault()` 成功时记录 `VAULT_EXPORTED`
3. `AuthPage.ets` - 解锁成功/失败时记录相应事件
