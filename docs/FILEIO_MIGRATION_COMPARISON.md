# 文件I/O迁移分析报告

## Android版本 vs 鸿蒙版本对比

| 功能 | Android版本 | 鸿蒙版本 |
|------|-------------|----------|
| 文件API | `java.io.File`, `FileInputStream`, `FileOutputStream` | `@kit.CoreFileKit.fileIo` |
| 原子写入 | `AtomicFile` | ❌ 未实现 |
| SAF支持` | `ContentResolver`, `DocumentFile` | ❌ 未实现 |
| 异步操作 | `AsyncTask`/`ExecutorService` | `Promise` |
| 文件路径 | `context.getFilesDir()` | `context.filesDir` |

---

## 关键差异分析

### 1. AtomicFile缺失 🔴 严重问题

**Android版本:**

```java
private static AtomicFile getAtomicFile(Context context) {
    return new AtomicFile(new File(context.getFilesDir(), FILENAME));
}

public static void writeToFile(Context context, InputStream inStream) throws IOException {
    AtomicFile file = VaultRepository.getAtomicFile(context);
    FileOutputStream outStream = null;
    try {
        outStream = file.startWrite();  // 开始写入
        IOUtils.copy(inStream, outStream);
        file.finishWrite(outStream);  // 原子性完成
    } catch (IOException e) {
        if (outStream != null) {
            file.failWrite(outStream);  // 失败时回滚
        }
        throw e;
    }
}
```

**鸿蒙版本:**

```typescript
writeVaultFile(content: string): void {
    const filePath = `${this.context.filesDir}/${VAULT_FILENAME}`;
    const file = fileIo.openSync(filePath,
        fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
    const encoder = new util.TextEncoder();
    const data = encoder.encodeInto(content);
    fileIo.writeSync(file.fd, data.buffer);
    fileIo.closeSync(file);
    // ❌ 没有原子性保证！
}
```

**问题:**
- 鸿蒙版本直接覆盖文件，如果写入过程中崩溃，可能导致数据损坏
- Android使用 AtomicFile 写入临时文件，成功后才替换原文件

---

### 2. Storage Access Framework (SAF) 完全缺失 🔴 严重问题

**Android版本支持的功能:**

```java
// 通过SAF导入文件
try (InputStream inStream = context.getContentResolver().openInputStream(uri)) {
    File tempFile = File.createTempFile(...);
    try (FileOutputStream outStream = new FileOutputStream(tempFile)) {
        IOUtils.copy(inStream, outStream);
    }
}

// 通过SAF导出文件
try (OutputStream outStream = resolver.openOutputStream(fileUri, "wt")) {
    IOUtils.copy(inStream, outStream);
}

// 备份到用户选择的目录
DocumentFile dir = DocumentFile.fromTreeUri(_context, dirUri);
DocumentFile file = dir.createFile("application/json", filename);
OutputStream outStream = _context.getContentResolver().openOutputStream(file.getUri());
```

**鸿蒙版本:**

```typescript
// ❌ 没有SAF相关代码
// ExportPage.ets 只能导出到 cacheDir
const filePath = `${ctx.cacheDir}/${fileName}`;
```

**影响:**
- 鸿蒙版本无法从用户选择的文件导入
- 鸿蒙版本无法导出到用户选择的位置
- 鸿蒙版本无法实现备份功能

---

### 3. 文件读取方式差异 ⚠️

**Android版本:**

```java
// 使用FileInputStream + DataInputStream
try (DataInputStream outStream = new DataInputStream(in)) {
    byte[] fileBytes = new byte[(int) inStream.getChannel().size()];
    outStream.readFully(fileBytes);
    return fileBytes;
}
```

**鸿蒙版本:**

```typescript
// 使用fileIo + ArrayBuffer
const stat = fileIo.statSync(filePath);
const buffer = new ArrayBuffer(stat.size);
fileIo.readSync(file.fd, buffer);
const decoder = new util.TextDecoder('utf-8');
return decoder.decodeToString(new Uint8Array(buffer));
```

**潜在问题:**
- 鸿蒙版本一次性读取整个文件到内存，大文件可能导致内存问题
- Android使用流式读取，更高效

---

### 4. 临时文件处理缺失 ⚠️

**Android版本:**

```java
// 创建临时文件
File tempFile = File.createTempFile(prefix, suffix, context.getCacheDir());
// 使用后删除
tempFile.delete();
```

**鸿蒙版本:**

```typescript
// ❌ 没有发现临时文件处理代码
// ExportPage.ets 直接写入到cacheDir，没有使用createTempFile
```

---

### 5. 备份功能完全缺失 🔴

**Android版本有:**
- `VaultBackupManager.java` - 内置备份管理器
- `AegisBackupAgent.java` - Android系统备份
- 支持单文件/多版本备份
- 支持备份到用户选择的目录

**鸿蒙版本:**

```typescript
// ❌ VaultService.ets 中没有备份相关代码
// ❌ 没有对应的 BackupManager
// ❌ 没有对应的 BackupAgent
```

---

### 6. 图标包管理缺失 🔴

**Android版本:**

```java
// IconPackManager.java
// - 从ZIP导入图标包
// - 扫描本地图标包
// - 删除图标包
// - 使用ZipFile和IOUtils.copy()
```

**鸿蒙版本:**

```typescript
// ❌ 没有IconPackManager的对应实现
```

---

### 7. QR码导入缺失 🔴

**Android版本:**

```java
// QrDecodeTask.java
// - 从ContentResolver打开图片文件
// - 使用QrCodeHelper.decodeFromStream()解码
// - 支持批量处理
```

**鸿蒙版本:**

```typescript
// ❌ 没有QR码导入功能
```

---

### 8. 导入器功能缺失 🔴

**Android版本:**

```java
// ImportFileTask.java - 从SAF导入文件
// 支持多种导入器 (GoogleAuth, Authy, etc.)
// 使用SqlImporterHelper读取其他应用数据库
```

**鸿蒙版本:**

```typescript
// ❌ 没有任何导入器实现
// ❌ 没有从其他应用迁移数据的功能
```

---

### 9. 文件权限检查缺失 ⚠️

**Android版本:**

```java
// VaultBackupManager.java
public boolean hasPermissionsAt(Uri uri) {
    for (UriPermission perm : _context.getContentResolver().getPersistedUriPermissions()) {
        if (perm.getUri().equals(uri)) {
            return perm.isReadPermission() && perm.isWritePermission();
        }
    }
    return false;
}
```

**鸿蒙版本:**

```typescript
// ❌ 没有权限检查代码
```

---

### 10. 异常处理不完整 ⚠️

**Android版本:**

```java
try {
    // 操作
} catch (IOException e) {
    // 处理异常
} finally {
    // 清理资源
    tempFile.delete();
}
```

**鸿蒙版本:**

```typescript
writeVaultFile(content: string): void {
    // ❌ 没有try-catch
    const file = fileIo.openSync(...);
    fileIo.writeSync(file.fd, data.buffer);
    fileIo.closeSync(file);
    // ❌ 如果openSync失败，closeSync可能执行失败
}
```

---

## ⚠️ 潜在迁移问题总结

### 🔴 严重问题（必须修复）

| 问题 | 影响 | 建议修复 |
|------|------|----------|
| AtomicFile缺失 | 写入崩溃可能导致数据损坏 | 实现原子写入：写入临时文件，成功后重命名 |
| SAF完全缺失 | 无法导入/导出用户文件 | 实现鸿蒙文件选择器API |
| 备份功能缺失 | 无法备份vault数据 | 实现备份管理器 |
| 导入器缺失 | 无法从其他应用迁移数据 | 实现导入器框架 |
| 图标包管理缺失 | 无法管理自定义图标 | 实现图标包管理器 |
| QR码导入缺失 | 无法通过QR码添加账户 | 实现QR码扫描和导入 |

### 🟡 中等问题（建议修复）

| 问题 | 影响 | 建议修复 |
|------|------|----------|
| 大文件内存问题 | 大vault文件可能OOM | 实现流式读取 |
| 异常处理不完整 | 资源泄漏风险 | 添加try-finally确保文件关闭 |
| 文件权限检查缺失 | 无权限验证 | 添加权限检查逻辑 |
| 进度反馈缺失 | 用户无反馈 | 添加进度回调 |

### 🟢 低优先级问题

| 问题 | 影响 | 建议修复 |
|------|------|----------|
| 临时文件命名 | 可能冲突 | 使用UUID生成唯一文件名 |
| 目录清理 | 缓存可能积累 | 实现定期清理机制 |

---

## 建议的鸿蒙文件I/O实现

### 1. 原子写入实现

```typescript
async writeVaultFileAtomic(content: string): Promise<void> {
    const filePath = `${this.context.filesDir}/${VAULT_FILENAME}`;
    const tempPath = `${filePath}.tmp`;

    try {
        // 写入临时文件
        const file = fileIo.openSync(tempPath,
            fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
        const encoder = new util.TextEncoder();
        const data = encoder.encodeInto(content);
        fileIo.writeSync(file.fd, data.buffer);
        fileIo.closeSync(file);

        // 原子性重命名
        fileIo.renameSync(tempPath, filePath);
    } catch (err) {
        // 清理临时文件
        try {
            fileIo.unlinkSync(tempPath);
        } catch (e) {
            // 忽略
        }
        throw err;
    }
}
```

### 2. 文件选择器实现

```typescript
import { picker } from '@kit.CoreFileKit';

async importVault(): Promise<void> {
    const documentPicker = new picker.DocumentViewPicker();
    documentPicker.selectMode = picker.SelectMode.SINGLE;
    documentPicker.fileSuffixFilters = ['.json', '.txt'];

    const documentSelectResult = await documentPicker.pick();
    if (documentSelectResult === undefined) {
        return;
    }

    const uri = documentSelectResult[0];
    // 读取文件...
}
```

### 3. 流式读取实现

```typescript
async readVaultFileStream(): Promise<string> {
    const filePath = `${this.context.filesDir}/${VAULT_FILENAME}`;
    const file = fileIo.openSync(filePath, fileIo.OpenMode.READ_ONLY);

    try {
        const buffer = new ArrayBuffer(4096); // 4KB缓冲区
        const chunks: Uint8Array[] = [];
        let readLen = 0;

        while ((readLen = fileIo.readSync(file.fd, buffer)) > 0) {
            chunks.push(new Uint8Array(buffer, 0, readLen));
        }

        // 合并chunks
        const totalLength = chunks.reduce((sum, chunk) => sum + chunk.length, 0);
        const result = new Uint8Array(totalLength);
        let offset = 0;
        for (const chunk of chunks) {
            result.set(chunk, offset);
            offset += chunk.length;
        }

        const decoder = new util.TextDecoder('utf-8');
        return decoder.decodeToString(result);
    } finally {
        fileIo.closeSync(file);
    }
}
```

---

## 总结

鸿蒙版本的文件I/O迁移非常不完整，主要缺失：

1. 核心安全功能：原子写入、权限检查
2. 用户交互功能：SAF文件选择、QR码扫描
3. 数据迁移功能：导入器、备份、图标包管理

建议优先实现原子写入和文件选择器，这是应用基本功能所必需的。
