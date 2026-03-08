# Aegis Importers 设计文档

## 概述

Aegis Importers 是一个灵活的导入框架，用于从各种双因素认证(2FA)应用导入OTP条目到Aegis。该设计支持从文件导入和直接从已安装应用内部存储导入（需要root权限）。

## 架构设计

### 核心类层次结构

```
DatabaseImporter (抽象基类)
├── AegisImporter
├── AndOtpImporter
├── AuthenticatorPlusImporter
├── AuthyImporter
├── BattleNetImporter
├── BitwardenImporter
├── DuoImporter
├── EnteAuthImporter
├── FreeOtpImporter
├── FreeOtpPlusImporter
├── GoogleAuthImporter
├── GoogleAuthUriImporter
├── MicrosoftAuthImporter
├── ProtonAuthenticatorImporter
├── SteamImporter
├── StratumImporter
├── TotpAuthenticatorImporter
├── TwoFASImporter
└── WinAuthImporter
```

### 核心组件

#### 1. DatabaseImporter (抽象基类)

**位置**: `app/src/main/java/com/beemdevelopment/aegis/importers/DatabaseImporter.java`

**职责**:
- 定义所有importer的通用接口和行为
- 管理已注册的importer列表
- 提供工厂方法创建importer实例

**核心方法**:
```java
// 必须由子类实现
protected abstract SuFile getAppPath() throws DatabaseImporterException, PackageManager.NameNotFoundException;
protected abstract State read(InputStream stream, boolean isInternal) throws DatabaseImporterException;

// 可选重写
public boolean isInstalledAppVersionSupported() { return true; }

// 导入方法
public State read(InputStream stream) throws DatabaseImporterException;
public State readFromApp(Shell shell) throws PackageManager.NameNotFoundException, DatabaseImporterException;
```

**注册的Importers** (按字母顺序):
| 名称 | 类名 | 支持直接导入 |
|------|------|---------------|
| 2FAS Authenticator | TwoFASImporter | false |
| Aegis | AegisImporter | false |
| andOTP | AndOtpImporter | false |
| Authenticator Plus | AuthenticatorPlusImporter | false |
| Authy | AuthyImporter | true |
| Battle.net Authenticator | BattleNetImporter | true |
| Bitwarden | BitwardenImporter | false |
| Duo | DuoImporter | true |
| Ente Auth | EnteAuthImporter | false |
| FreeOTP | FreeOtpImporter | true |
| Free FreeOTP+ (JSON) | FreeOtpPlusImporter | true |
| Google Authenticator | GoogleAuthImporter | true |
| Microsoft Authenticator | MicrosoftAuthImporter | true |
| Plain text | GoogleAuthUriImporter | false |
| Proton Authenticator | ProtonAuthenticatorImporter | false |
| Steam | SteamImporter | true |
| Stratum (Authenticator Pro) | StratumImporter | true |
| TOTP Authenticator | TotpAuthenticatorImporter | true |
| WinAuth | WinAuthImporter | false |

#### 2. Definition 类

**职责**: 描述一个importer的元数据

**字段**:
- `name`: 认证应用名称
- `type`: importer类类型
- `help`: 帮助文本资源ID
- `supportsDirect`: 是否支持直接从应用内部存储导入

#### 3. State 类 (抽象)

**职责**: 表示导入后的中间状态（加密或解密）

**子类**:
- `EncryptedState`: 加密状态，需要解密
- `DecryptedState`: 已解密状态，可直接转换

**核心方法**:
```java
public boolean isEncrypted()
public void decrypt(Context context, DecryptListener listener)
public Result convert()
```

#### 4. Result 类

**职责**: 存储导入转换后的最终结果

**字段**:
- `entries`: 成功导入的VaultEntry列表
- `groups`: 导入的VaultGroup列表
- `errors`: 导入过程中发生的错误列表

#### 5. DecryptListener (抽象)

**职责**: 异步解密回调接口

**方法**:
```java
protected abstract void onStateDecrypted(State state);
protected abstract void onError(Exception e);
protected abstract void onCanceled();
```

### 辅助组件

#### SqlImporterHelper

**职责**: 帮助从SQLite数据库导入数据

**功能**:
- 读取SQLite数据库文件
- 支持从文件或SuFile（需要root）读取
- 提供类型安全的Cursor访问方法

**关键方法**:
```java
public <T extends Entry> List<T> read(Class<T> type, InputStream inStream, String table)
public <T extends Entry> List<T> read(Class<T> type, SuFile path, String table)
```

## 导入流程

### 文件导入流程

```
用户选择文件
    ↓
ImportFileTask 读取文件到临时目录
    ↓
DatabaseImporter.read(InputStream)
    ↓
State (加密/解密)
    ↓
如果加密: State.decrypt() → 用户输入密码
    ↓
State.convert() → Result
    ↓
ImportEntriesActivity 显示导入结果
    ↓
用户选择要导入的条目
    ↓
保存到Vault
```

### 直接从应用导入流程 (需要root)

```
用户选择已安装应用
    ↓
检查应用版本是否支持 (isInstalledAppVersionSupported)
    ↓
RootShellTask 获取root shell
    ↓
DatabaseImporter.readFromApp(Shell)
    ↓
获取应用内部存储路径 (getAppPath)
    ↓
读取并解析数据
    ↓
后续同文件导入流程
```

## 支持的数据格式

### 1. JSON 格式
- **应用**: andOTP, FreeOTP+, Bitwarden, 2FAS, Proton Authenticator
- **特点**: 结构化数据，易于解析
- **加密**: 支持加密（如andOTP, 2FAS）

### 2. XML 格式
- **应用**: Google Authenticator, FreeOTP, Battle.net, Authy, TOTP Authenticator
- **特点**: Android SharedPreferences 格式

### 3. SQLite 数据库
- ****应用**: Google Authenticator, Microsoft Authenticator, Stratum
- **特点**: 使用 SqlImporterHelper 读取

### 4. CSV 格式
- **应用**: Bitwarden
- **特点**: 使用 simpleflatmapper 解析

### 5. 纯文本/URI 格式
- **应用**: GoogleAuthUriImporter, EnteAuth, WinAuth
- **特点**: 每行一个 otpauth:// URI

### 6. 自定义二进制格式
- **应用**: FreeOTP (V2), Stratum (加密)
- **特点**: 需要自定义解析器

## 加密支持

### 支持的加密方式

| 应用 | 加密算法 | 密钥派生 |
|------|----------|----------|
| andOTP | AES/GCM/NoPadding | PBKDF2WithHmacSHA1 |
| Authy | AES/CBC/PKCS5Padding | PBKDF2WithHmacSHA1 |
| FreeOTP | AES/GCM/NoPadding | PBKDF2WithHmacSHA1/SHA512 |
| Stratum | AES/GCM/NoPadding | Argon2id |
| TOTP Authenticator | AES/CBC/PKCS5Padding | SHA-256 (不安全) |
| 2FAS | AES/GCM/NoPadding | PBKDF2WithHmacSHA256 |
| Aegis | 使用VaultFile加密 | 多种 |

### 解密流程

1. 检测State是否加密 (`state.isEncrypted()`)
2. 如果加密，调用 `state.decrypt(context, listener)`
3. 显示密码输入对话框
4. 使用适当的密钥派生函数派生密钥
5. 解密数据
6. 返回DecryptedState

## 错误处理

### 异常层次

```
DatabaseImporterException
└── 表示导入过程中的整体错误

DatabaseImporterEntryException
└── 表示单个条目导入失败
    ├── 包含原始文本数据
    ├── 允许继续处理其他条目
    └── 在Result中收集所有错误
```

### 错误处理策略

1. **整体错误**: 整个导入过程失败，无法继续
2. **条目错误**: 单个条目失败，继续处理其他条目
3. **错误收集**: 所有条目错误收集到Result.errors中
4. **用户通知**: 导入完成后显示错误摘要

## UI 组件

### ImportEntriesActivity

**职责**: 管理导入流程和用户界面

**关键功能**:
- 显示导入的条目列表
- 允许用户选择要导入的条目
- 检测重复条目
- 处理组(group)导入
- 提供清空vault选项

### ImportEntriesAdapter

**职责**: RecyclerView适配器，显示导入条目

### ImportEntry

**职责**: 包装VaultEntry，添加选择状态

## 扩展指南

### 添加新的Importer

1. **创建Importer类**，继承DatabaseImporter:
```java
public class MyAppImporter extends DatabaseImporter {
    public MyAppImporter(Context context) {
        super(context);
    }

    @Override
    protected SuFile getAppPath() throws PackageManager.NameNotFoundException {
        // 返回应用内部存储路径
        return getAppPath("com.example.app", "path/to/file");
    }

    @Override
    public State read(InputStream stream, boolean isInternal) throws DatabaseImporterException {
        // 解析输入流
        // 返回State对象
    }
}
```

2. **定义State类**:
```java
public static class State extends DatabaseImporter.State {
    private List<MyEntry> _entries;

    public State(List<MyEntry> entries) {
        super(false); // false表示未加密
        _entries = entries;
    }

    @Override
    public Result convert() {
        Result result = new Result();
        for (MyEntry entry : _entries) {
            try {
                VaultEntry vaultEntry = convertEntry(entry);
                result.addEntry(vaultEntry);
            } catch (DatabaseImporterEntryException e) {
                result.addError(e);
            }
        }
        return result;
    }
}
```

3. **注册Importer** (在DatabaseImporter静态初始化块中):
```java
_importers.add(new Definition("My App", MyAppImporter.class,
    R.string.importer_help_myapp, true));
```

4. **添加帮助文本** (在strings.xml中):
```xml
<string name="importer_help_myapp">Select a backup file exported from My App</string>
```

## 特殊实现说明

### 1. AegisImporter
- 支持Aegis自身的导入
- 使用VaultFile格式
- 支持加密和非加密
- 可以保留原始凭证

### 2. GoogleAuthUriImporter
- 纯文本导入器
- 每行一个otpauth:// URI
- 被多个其他importer复用

### 3. FreeOtpImporter
- 支持V1 (XML) 和 V2 (加密) 格式
- V2使用自定义的SerializedHashMapParser
- 使用BouncyCastle解析ASN.1

### 4. StratumImporter
- 支持现代和旧版加密格式
- 现代使用Argon2id
- 旧版使用PBKDF2WithHmacSHA1

### 5. WinAuthImporter
- 委托给GoogleAuthUriImporter
- 转换issuer和name字段

## 安全注意事项

1. **密码处理**: 使用安全的密码输入对话框
2. **密钥派生**: 使用PBKDF2或Argon2等安全算法
3. **内存清理**: 及时清理敏感数据
4. **Root权限**: 直接导入需要root权限，谨慎使用
5. **加密存储**: 支持的加密格式使用标准加密算法

## 性能考虑

1. **异步处理**: 使用后台线程处理导入
2. **进度反馈**: 显示进度对话框
3. **批量处理**: 优化大文件处理
4. **临时文件**: 使用缓存目录存储临时文件

## 依赖库

- **LibSU**: 用于root访问和SuFile操作
- **BouncyCastle**: 用于加密和ASN.1解析
- **SimpleFlatMapper**: 用于CSV解析
- **Zip4j**: 用于ZIP文件解压（AuthenticatorPlus）

## 总结

Aegis Importers设计提供了一个灵活、可扩展的框架，支持从多种2FA应用导入数据。其核心优势包括：

1. **统一的接口**: 所有importer遵循相同的接口
2. **加密支持**: 支持多种加密格式
3. **错误恢复**: 单个条目失败不影响整体导入
4. **灵活的导入方式**: 支持文件和直接应用导入
5. **易于扩展**: 添加新importer只需实现几个方法
