# 导入器功能对比报告

> 审查日期: 2026-03-07
> 原项目: Android Java (Aegis Authenticator v3.4.2)
> 迁移版本: 鸿蒙 ArkTS (Aegis-hmos_fixcompile)

---

## Android 原版导入器功能

### 1. 支持的导入器列表

原版 Aegis 支持从 **17+ 个其他认证器应用**导入数据：

| 导入器 | 文件 | 需要 Root | 说明 |
|---------|------|:-------:|------|
| 2FAS Authenticator | `TwoFASImporter.java` | ❌ | JSON 导出文件 |
| Aegis | `AegisImporter.java` | ❌ | JSON 导出文件 |
| andOTP | `AndOtpImporter.java` | ❌ | JSON/备份文件 |
| Authenticator Plus | `AuthenticatorPlusImporter.java` | ❌ | 备份文件 |
| Authy | `AuthyImporter.java` | ✅ | 内部数据库 |
| Battle.net | `BattleNetImporter.java` | ✅ | 内部数据库 |
| Bitwarden | `BitwardenImporter.java` | ❌ | JSON 导出 |
| Duo | `DuoImporter.java` | ✅ | 内部数据库 |
| Ente Auth | `EnteAuthImporter.java` | ❌ | 加密备份 |
| FreeOTP | `FreeOtpImporter.java` | ✅ | 内部存储 |
| FreeOTP+ | `FreeOtpPlusImporter.java` | ✅ | 内部存储 |
| Google Authenticator | `GoogleAuthImporter.java` | ✅ | 内部数据库 |
| Microsoft Authenticator | `MicrosoftAuthImporter.java` | ✅ | 内部数据库 |
| Plain text | `GoogleAuthUriImporter.java` | ❌ | 文本/URI |
| Proton Authenticator | `ProtonAuthenticatorImporter.java` | ❌ | JSON 导出 |
| Steam | `SteamImporter.java` | ✅ | 内部数据库 |
| Stratum | `StratumImporter.java` | ✅ | 内部数据库 |
| TOTP Authenticator | `TotpAuthenticatorImporter.java` | ✅ | 内部数据库 |
| WinAuth | `WinAuthImporter.java` | ❌ | 导出文件 |

### 2. 核心导入器类

**文件**: `DatabaseImporter.java`

关键功能：
- **反射创建实例**: `DatabaseImporter.create()` 使用反射动态创建导入器实例
- **导入器定义列表**: 静态注册所有支持的导入器
- **支持直接导入**: 从已安装应用的内部存储直接读取（需要 Root）
- **支持文件导入**: 从导出的 JSON/文本文件导入
- **加密数据库支持**: 部分导入器支持加密数据库的解密

### 3. 导入器选择对话框

**文件**: `Dialogs.java:515-540`

```java
public static void showImportersDialog(Context context, boolean isDirect, ImporterListener listener) {
    List<DatabaseImporter.Definition> importers = DatabaseImporter.getImporters(isDirect);
    // 显示导入器列表对话框
}
```

### 4. 导入处理流程

**文件**: `ImportEntriesActivity.java`

关键流程：
1. 用户选择导入器类型
2. 如果是文件导入 → 打开文件选择器
3. 如果是直接导入 → 使用 Root Shell 读取应用内部存储
4. 处理加密数据库（如需要）
5. 解析并转换为 VaultEntry
6. 显示导入的条目列表供用户确认
7. 保存到 Vault

### 5. 扫描二维码功能

**文件**: `ScannerActivity.java`

使用 CameraX 和 ZXing 库扫描二维码：
- 支持标准 `otpauth://` URI
- 支持 Google Authenticator 批量导出 `otpauth-migration://` URI
- 支持前后摄像头切换

---

## 鸿蒙版本功能

### 1. 现有文件

| 文件 | 功能 |
|------|------|
| `OtpUriParser.ets` | ✅ 解析 otpauth:// URI |
| `EditEntryPage.ets` | ✅ 手动添加/编辑条目 |
| `ExportPage.ets` | ✅ 导出为 JSON |
| `PreferencesPage.ets` | ✅ 设置页面 |
| `Index.ets` | ✅ 主页面 |

### 2. URI 解析功能

**文件**: `OtpUriParser.ets`

支持的 URI 格式：
- `otpauth://` - 标准 OTP URI
- `motp://` - mOTP 专用

支持的 OTP 类型：
- TOTP
- HOTP
- Steam
- mOTP
- Yandex

### 3. 缺失的功能

❌ **导入器功能完全缺失**
- 没有任何从其他应用导入的功能
- 没有导入器选择对话框
- 没有文件导入功能（除了手动输入）

❌ **二维码扫描功能完全缺失**
- 没有扫描器页面
- 没有相机集成
- 没有 ZXing 或类似库集成

---

## 确认结论

### P0 问题确认

| 问题 | 状态 | 说明 |
|------|------|------|
| **导入器功能** | ❌ 完全缺失 | 鸿蒙版本不支持从其他认证器应用导入数据 |
| **二维码扫描** | ❌ 完全缺失 | 鸿蒙版本没有二维码扫描功能 |
| **审计日志数据库** | ❌ 完全缺失 | 没有 DatabaseService 的审计日志实现 |

### 需要修复的 P0 问题

1. **导入器功能** - 需要实现从其他应用导入数据
2. **二维码扫描** - 需要实现相机和二维码扫描
3. **审计日志数据库** - 需要实现审计日志功能

---

**报告生成时间**: 2026-03-07
