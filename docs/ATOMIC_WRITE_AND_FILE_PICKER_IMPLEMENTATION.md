# 原子写入和文件选择器功能实现报告

> 实现日期: 2026-03-09
> 项目: Aegis-hmos_fixcompile (鸿蒙 ArkTS)

---

## 实现概述

本次实现为鸿蒙版本 Aegis 添加了两个关键功能：
1. **原子文件写入** - 替代 Android 的 AtomicFile 功能
2. **文件选择器** - 替代 Android 的 Storage Access Framework (SAF)

---

## 1. 原子文件写入实现

### 1.1 实现位置
`Aegis-hmos/entry/src/main/ets/service/VaultService.ets`

### 1.2 新增方法

#### `writeVaultFileAtomic(content: string): void`
```typescript
// Atomically write vault file to disk
// Writes to a temp file first, then renames atomically
writeVaultFileAtomic(content: string): void {
  const filePath = `${this.context.filesDir}/${VAULT_FILENAME}`;
  const tempPath = `${filePath}.tmp`;

  try {
    // Write to temp file first
    file = fileIo.openSync(tempPath, CREATE | WRITE_ONLY | TRUNC);
    // ... write content ...
    fileIo.closeSync(file);

    // Atomic rename: temp file -> actual file
    fileIo.renameSync(tempPath, filePath);
  } catch (err) {
    // Clean up temp file if something went wrong
    fileIo.unlinkSync(tempPath);
    throw err;
  }
}
```

**工作原理：**
1. 先写入到临时文件 (`aegis.json.tmp`)
2. 写入成功后，使用 `renameSync` 原子性地重命名文件
3. 如果写入失败，清理临时文件，原文件保持不变

**优势：**
- 保证数据完整性：要么完全写入成功，要么原文件不变
- 防止写入过程中崩溃导致数据损坏
- 与 Android AtomicFile 行为一致

#### `readVaultFileFromPath(filePath: string): string`
从指定路径读取 vault 文件内容（用于导入功能）

#### `writeVaultFileToPath(content: string, filePath: string): void`
将 vault 内容写入到指定路径（用于导出功能）

### 1.3 修改的方法

#### `saveVault()`
将 `writeVaultFile()` 改为 `writeVaultFileAtomic()`，使用原子写入保存 vault。

---

## 2. 文件选择器实现

### 2.1 导出功能实现

#### 实现位置
`Aegis-hmos/entry/src/main/ets/pages/ExportPage.ets`

#### 新增方法
`exportVaultWithPicker(): Promise<void>`

**功能：**
1. 使用 `picker.DocumentViewPicker` 创建文件保存选择器
2. 配置默认文件名和后缀过滤器
3. 用户选择保存位置后，将 vault 内容写入到选定位置

**代码片段：**
```typescript
const documentPicker = new picker.DocumentViewPicker();
const pickerOptions: picker.DocumentSaveOptions = {
  newFileNames: [defaultFileName],
  fileSuffixChoices: ['.json']
};

const result = await documentPicker.save(pickerOptions);
if (result !== undefined && result.length > 0) {
  const selectedUri = result[0];
  // Write to selected URI
  fileIo.copyFileSync(tempPath, selectedUri);
}
```

#### UI 更新
- 添加"Export to JSON (Save to Location)"按钮 - 使用文件选择器
- 保留"Export to Cache (Quick)"按钮 - 快速导出到缓存目录

### 2.2 导入功能实现

#### 实现位置
`Aegis-hmos/entry/src/main/ets/pages/ImportPage.ets` (新建)

#### 主要功能
1. **文件选择器对话框**
   - 页面加载时自动显示文件选择器
   - 支持 `.json` 和 `.txt` 文件

2. **文件解析**
   - 支持 Aegis vault 格式
   - 支持数组格式（其他应用导出）
   - 支持 Aegis entry 格式
   - 支持 otpauth URI 格式

3. **条目选择**
   - 显示所有可导入的条目
   - 支持全选/取消全选
   - 支持单独选择

4. **导入执行**
   - 检查重复条目（按 UUID）
   - 重复条目自动生成新 UUID
   - 导入成功后返回主页

#### 代码结构
```typescript
@Entry
@Component
struct ImportPage {
  @State importEntries: ImportEntry[] = [];
  @State isImporting: boolean = false;

  private async showFilePickerDialog(): Promise<void> { ... }
  private async loadImportFile(uri: string): Promise<void> { ... }
  private parseAegisVault(fileObj: Record<string, Object>): void { ... }
  private parseArrayFormat(arr: Array<Record<string, Object>>): void { ... }
  private parseEntryAegisFormat(obj: Record<string, Object>): VaultEntry { ... }
  private parseEntryFromJson(obj: Record<string, Object>): VaultEntry { ... }
  private async performImport(): Promise<void> { ... }
}
```

### 2.3 路由配置更新

#### 修改文件
`Aegis-hmos/entry/src/main/resources/base/profile/main_pages.json`

**更新内容：**
```json
{
  "src": [
    "pages/Index",
    "pages/AuthPage",
    "pages/IntroPage",
    "pages/EditEntryPage",
    "pages/PreferencesPage",
    "pages/GroupManagerPage",
    "pages/AboutPage",
    "pages/ExportPage",
    "pages/ImportPage"  // 新增
  ]
}
```

### 2.4 主菜单更新

#### 修改文件
`Aegis-hmos/entry/src/main/ets/pages/Index.ets`

**更新内容：**
在"更多"菜单中添加"Import"和"Export"选项

```typescript
private showMoreMenu(): void {
  ActionSheet.show({
    sheets: [
      { title: 'Import', action: () => { router.pushUrl({ url: 'pages/ImportPage' }); } },
      { title: 'Export', action: () => { router.pushUrl({ url: 'pages/ExportPage' }); } },
      { title: 'Settings', action: () => { ... } },
      { title: 'About', action: () => { ... } }
    ]
  });
}
```

---

## 3. 与 Android 版本对比

| 功能 | Android 版本 | 鸿蒙版本 | 状态 |
|------|-------------|----------|------|
| **原子写入** | `AtomicFile.startWrite()/finishWrite()` | `writeVaultFileAtomic()` | ✅ 已实现 |
| **文件选择器** | `Storage Access Framework` | `picker.DocumentViewPicker` | ✅ 已实现 |
| **导出功能** | `VaultRepository.export()` | `ExportPage` | ✅ 已实现 |
| **导入功能** | `ImportExportPreferencesFragment` | `ImportPage` | ✅ 已实现 |
| **多格式支持** | Aegis, Google Auth, HTML 等 | Aegis JSON | ⚠️ 部分实现 |

---

## 4. API 对比

### 4.1 文件选择器

| 操作 | Android (SAF) | 鸿蒙 (picker) |
|------|---------------|----------------|
| **选择文件** | `Intent.ACTION_OPEN_DOCUMENT` | `DocumentViewPicker.pick()` |
| **保存文件** | `Intent.ACTION_CREATE_DOCUMENT` | `DocumentViewPicker.save()` |
| **文件过滤** | `Intent.setType()` | `fileSuffixFilters` |
| **读取内容** | `ContentResolver.openInputStream()` | `picker.open().readText()` |
| **写入内容** | `ContentResolver.openOutputStream()` | `fileIo.copyFileSync()` |

### 4.2 原子写入

| 操作 | Android (AtomicFile) | 鸿蒙 (fileIo) |
|------|---------------------|-----------------|
| **开始写入** | `startWrite()` | `openSync(..., CREATE \| WRITE_ONLY \| TRUNC)` |
| **完成写入** | `finishWrite()` | `renameSync(tempPath, targetPath)` |
| **失败回滚** | `failWrite()` | `unlinkSync(tempPath)` |

---

## 5. 技术细节

### 5.1 原子性保证

鸿蒙的 `fileIo.renameSync()` 在同一文件系统内是原子操作：
- 如果目标文件已存在，会被原子性地替换
- 如果操作失败，原文件保持不变
- 不会出现部分写入的情况

### 5.2 文件 URI 处理

鸿蒙文件选择器返回的 URI 格式：
- `file://` 协议用于本地文件
- 使用 `picker.open()` 可以直接打开 URI 进行读写
- 使用 `fileIo.copyFileSync()` 可以复制到 URI 位置

### 5.3 错误处理

所有异步操作都包含 try-catch 错误处理：
- 文件选择器取消 → 返回上一页
- 文件读取失败 → 显示错误提示并返回
- 导入失败 → 显示错误提示
- 导出失败 → 显示错误提示

---

## 6. 测试建议

### 6.1 原子写入测试
1. 添加新条目到 vault
2. 在写入过程中模拟崩溃（可选）
3. 验证 vault 文件完整性

### 6.2 导出测试
1. 导出 vault 到选择的位置
2. 验证导出文件格式正确
3. 尝试导出到不同位置（内部存储、外部存储）

### 6.3 导入测试
1. 导入 Aegis JSON 格式文件
2. 导入包含多个条目的文件
3. 导入包含重复条目的文件
4. 导入无效格式的文件

---

## 7. 已知限制

1. **导出格式**：目前仅支持 Aegis JSON 格式，不支持 Google Auth URI 或 HTML 格式
2. **加密 vault**：目前仅支持未加密 vault 的导入导出
3. **图标处理**：导入时图标数据可能需要额外处理

---

## 8. 后续改进建议

1. **添加更多导出格式**：
   - Google Authenticator URI 格式
   - HTML 格式（带二维码）

2. **支持加密 vault**：
   - 导出时可选加密
   - 导入时支持密码解密

3. **批量操作**：
   - 导出时支持选择部分条目
   - 导入时支持合并/替换选项

4. **进度显示**：
   - 大文件导入时显示进度条

---

**实现完成日期**: 2026-03-09
