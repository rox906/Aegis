# Aegis Android项目数据处理架构分析

根据对代码的分析，以下是Aegis Android项目中数据处理相关代码的详细分析：

---

## 1. 本地数据库 (Room)

**位置**: `com.beemdevelopment.aegis.database`

- `AppDatabase.java` - Room数据库主类
  - 使用 `@Database(entities = {AuditLogEntry.class}, version = 1)` 注解
  - 目前只包含审计日志表 `audit_logs`
- `AuditLogEntry.java` - 审计日志实体
  - 字段：`id`, `event_type`, `reference`, `timestamp`
  - 使用 `@Entity(tableName = "audit_logs")` 注解
- `AuditLogDao.java` - 数据访问对象
  - `insert()` - 插入日志
  - `getAll()` - 获取最近30天的日志（使用SQLite的strftime函数）

---

## 2. 文件I/O操作

**核心类**: `com.beemdevelopment.aegis.util.IOUtils`

### 主要方法：
- `readFile(FileInputStream)` - 读取文件到字节数组
- `readAll(InputStream)` - 读取所有输入流数据
- `copy(InputStream, OutputStream)` - 流复制（4KB缓冲区）
- `clearDirectory(File, boolean)` - 递归删除目录

### Vault文件存储 (`VaultRepository.java`):
- 使用 `AtomicFile` 保证原子性写入
- 主文件路径: `context.getFilesDir()/aegis.json`
- `save()` - 保存vault到本地文件
- `export()` - 导出vault到输出流

---

## 3. 网络请求

**注意**: 此项目主要是一个离线的OTP认证应用，没有发现传统的HTTP网络请求代码。

数据传输主要通过以下方式：
- **Android Backup Agent** (`AegisBackupAgent.java`) - 系统级备份
- **SAF** (Storage Access Framework) - 文件导入/导出
- **QR码扫描** - 从图片解码获取数据

---

## 4. 备份数据处理

### `AegisBackupAgent.java` - Android备份代理

**关键方法**：
- `onFullBackup()` - 完整备份vault文件
- `onRestoreFile()` - 恢复vault文件
- `getVaultBackupFile()` - 获取备份文件路径

### `VaultBackupManager.java` - 内置备份管理器

- 支持两种策略：单文件备份 / 多版本备份
- 使用 `DocumentFile` 和 SAF 进行文件操作
- 版本管理：按时间戳命名，保留指定数量的旧版本

---

## 5. 数据导入/导出

### 导入任务 (`ImportFileTask.java`)

**流程**：
1. 通过 `ContentResolver` 打开输入流
2. 创建临时文件
3. 复制数据到临时文件
4. 返回临时文件路径供后续处理

### 导出出任务 (`ExportTask.java`)

**流程**：
1. 从临时文件读取数据
2. 通过 `ContentResolver` 打开输出流
3. 复制数据到目标URI
4. 删除临时文件

### QR码解码 (`QrDecodeTask.java`)

- 使用 `QrCodeHelper.decodeFromStream()` 解码图片
- 支持批量处理多个URI

---

## 6. 数据库导入器

### `DatabaseImporter.java` - 抽象基类

- 支持18种不同的认证器导入格式
- 使用 `SuFile` 和 `SuFileInputStream` 处理root权限下的文件访问

### `SqlImporterHelper.java` - SQLite导入辅助类

**关键方法**：
- `read(Class, SuFile, String)` - 从root权限路径读取数据库
- `read(Class, InputStream, String)` - 从输入流读取数据库
- `read(Class, File, String)` - 从本地文件读取数据库

### 支持的导入器包括：
- Google Authenticator
- Authy（支持加密数据库解密）
- Microsoft Authenticator
- Bitwarden
- FreeOTP
- andOTP
- 等等...

---

## 7. 加密数据处理

### `CryptoUtils.java` - 加密工具类

**加密配置**：
- 算法: `AES/GCM/NoPadding`
- 密钥大小: 32字节
- Tag大小: 16字节
- Nonce大小: 12字节
- SCrypt参数: `N=32768, r=8, p=1`

**主要方法**：
- `deriveKey()` - 使用SCrypt派生密钥
- `encrypt()` - AES-GCM加密
- `decrypt()` - AES-GCM解密
- `generateKey()` - 生成随机密钥

### `VaultFile.java` - Vault文件格式处理

- JSON格式存储，包含版本、header和db字段
- 支持加密和非加密两种模式
- `exportable()` - 导出时移除普通密码槽，只保留备份密码槽

---

## 8. 图标包管理

### `IconPackManager.java`

**功能**：
- `importPack()` - 从从ZIP文件导入图标包
- `rescanIconPacks()` - 扫描本地图标包
- `removeIconPack()` - 删除图标包

**图标包结构**：
```
icons/
  {UUID}/
    {version}/
      pack.json
      icons/
        ...
```

---

## 9. SharedPreferences管理

### `Preferences.java` - 应用偏好设置

- 使用 `PreferenceManager.getDefaultSharedPreferences()`
- 存储各种设置：自动锁、搜索行为、备份配置等
- 使用JSON序列化存储复杂数据（如UUID集合、备份结果等）

---

## 安全注意事项

1. **加密存储**: Vault数据使用AES-GCM加密，SCrypt密钥派生
2. **原子写入**: 使用AtomicFile确保数据完整性
3. **临时文件清理**: 所有临时文件在使用后都会删除
4. **权限检查**: 备份时检查URI读写权限
5. **路径验证**: 防止目录遍历攻击（如IconPackManager中的路径检查）
