# Aegis Authenticator 设计文档

> 版本: 3.4.2  
> 日期: 2026-03-06  
> 包名: `com.beemdevelopment.aegis`

## 目录

1. [项目概述](#1-项目概述)
2. [系统架构](#2-系统架构)
3. [核心模块设计](#3-核心模块设计)
4. [安全设计](#4-安全设计)
5. [数据存储格式](#5-数据存储格式)
6. [UI架构](#6-ui架构)
7. [依赖和第三方库](#7-依赖和第三方库)

---

## 1. 项目概述

### 1.1 项目简介

**Aegis Authenticator** 是一个免费、安全、开源的 Android 双因素认证(2FA)应用。它旨在为用户的在线服务提供安全的身份验证器，同时包含了一些现有身份验证器应用中缺失的功能，如适当的加密和备份。

### 1.2 主要功能

- **兼容性**: 支持 HOTP (RFC 4226) 和 TOTP (RFC 6238) 算法
- **安全性**: 
  - 保险库加密 (AES-256-GCM)
  - 密码解锁 (scrypt)
  - 生物识别解锁 (Android Keystore)
  - 屏幕截图防护
  - 点击显示
- **组织功能**:
  - 按字母/自定义排序
  - 自定义或自动生成图标
  - 分组管理
  - 高级条目编辑
  - 按名称/发行者搜索
- **导入导出**: 支持从 17+ 个其他认证器应用导入
- **备份**: 自动备份到指定位置
- **UI**: Material Design，支持 Light/Dark/AMOLED 主题

### 1.3 技术栈

| 类别 | 技术 |
|------|------|
| 平台 | Android (minSdk: 23, targetSdk: 35) |
| 语言 | Java 17 |
| 构建工具 | Gradle 8.10.0 |
| 依赖注入 | Dagger Hilt 2.56.2 |
| 数据库 | Room 2.7.1 (审计日志) |
| 序列化 | Protocol Buffers |
| 相机 | CameraX 1.4.2 |
| 图像加载 | Glide 4.16.0 |

---

## 2. 系统架构

### 2.1 整体架构图

```
┌─────────────────────────────────────────────────────────────────┐
│                          UI Layer                                │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐   │
│  │ Main    │ │ Edit    │ │ Scanner │ │ Pref    │ │ Auth    │   │
│  │Activity │ │Entry    │ │Activity │ │Activity │ │Activity │   │
│  └────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘   │
│       └────────────┴────────────┴────────────┴────────────┘     │
│                              │                                   │
│                         EntryListView                            │
└──────────────────────────────┬──────────────────────────────────┘
                               │
┌──────────────────────────────┼──────────────────────────────────┐
│                         Business Layer                          │
│  ┌─────────────┐  ┌──────────┴──────────┐  ┌─────────────────┐  │
│  │ VaultManager│  │   VaultRepository   │  │ IconPackManager │  │
│  └─────────────┘  └─────────────────────┘  └─────────────────┘  │
│         │                    │                      │           │
│  ┌─────────────┐  ┌──────────┴──────────┐  ┌─────────────────┐  │
│  │ VaultBackup │  │      Vault          │  │   IconPack      │  │
│  │   Manager   │  │  (Entries/Groups)   │  │                 │  │
│  └─────────────┘  └─────────────────────┘  └─────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                               │
┌──────────────────────────────┼──────────────────────────────────┐
│                          Data Layer                             │
│  ┌───────────────────────────┼─────────────────────────────┐   │
│  │                      Vault File                          │   │
│  │  ┌─────────┐  ┌─────────┐ │ ┌─────────┐  ┌─────────┐    │   │
│  │  │  Slots  │  │ Entries │ │ │ Groups  │  │ Headers │    │   │
│  │  └─────────┘  └─────────┘ │ └─────────┘  └─────────┘    │   │
│  └───────────────────────────┼─────────────────────────────┘   │
│                              │                                  │
│  ┌───────────────────────────┼─────────────────────────────┐   │
│  │                   Security Layer                         │   │
│  │  ┌─────────┐  ┌─────────┐ │ ┌─────────┐  ┌─────────┐    │   │
│  │  │AES-256 │  │ scrypt  │ │ │KeyStore │  │Biometric│    │   │
│  │  │  GCM   │  │  KDF    │ │ │         │  │         │    │   │
│  │  └─────────┘  └─────────┘ │ └─────────┘  └─────────┘    │   │
│  └───────────────────────────┴─────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 模块划分

| 模块 | 包路径 | 职责 |
|------|--------|------|
| **Vault** | `com.beemdevelopment.aegis.vault.*` | 核心数据模型、存储、加密 |
| **OTP** | `com.beemdevelopment.aegis.otp.*` | OTP算法实现、URI解析 |
| **Crypto** | `com.beemdevelopment.aegis.crypto.*` | 加密工具、密钥管理 |
| **UI** | `com.beemdevelopment.aegis.ui.*` | 界面、Activity、Fragment |
| **Importer** | `com.beemdevelopment.aegis.importers.*` | 第三方应用数据导入 |
| **Icons** | `com.beemdevelopment.aegis.icons.*` | 图标包管理 |
| **Database** | `com.beemdevelopment.aegis.database.*` | 审计日志数据库 |

---

## 3. 核心模块设计

### 3.1 Vault 模块 (核心)

#### 3.1.1 类层次结构

```
VaultManager (单例)
    ├── VaultRepository
    │       ├── Vault
    │       │       ├── UUIDMap<VaultEntry>
    │       │       └── UUIDMap<VaultGroup>
    │       ├── VaultFile
    │       └── VaultFileCredentials
    │               └── SlotList
    │                       ├── PasswordSlot
    │                       ├── BiometricSlot
    │                       └── RawSlot
    └── VaultBackupManager
```

#### 3.1.2 核心类说明

**VaultManager**
- 单例模式，由 Hilt 依赖注入管理
- 负责保险库的生命周期管理（初始化、加载、锁定）
- 管理自动锁定逻辑
- 协调备份操作

```java
public class VaultManager {
    // 主要方法
    VaultRepository initNew(@Nullable VaultFileCredentials creds)
    VaultRepository loadFrom(VaultFile vaultFile, VaultFileCredentials creds)
    void lock(boolean userInitiated)
    void enableEncryption(VaultFileCredentials creds)
    void disableEncryption()
    void saveAndBackup()
}
```

**VaultRepository**
- 数据访问层，封装对 Vault 的所有操作
- 负责文件的读写（使用 AtomicFile 保证原子性）
- 支持多种导出格式（加密/明文/URI/HTML）

```java
public class VaultRepository {
    public static final String FILENAME = "aegis.json";
    
    // CRUD 操作
    void addEntry(VaultEntry entry)
    VaultEntry removeEntry(VaultEntry entry)
    VaultEntry editEntry(VaultEntry entry, EntryEditor editor)
    void moveEntry(VaultEntry entry1, VaultEntry entry2)
    
    // 导出
    void export(OutputStream stream)
    void exportGoogleUris(OutputStream outStream, EntryFilter filter)
    void exportHtml(OutputStream outStream, EntryFilter filter)
}
```

**Vault**
- 核心数据模型
- 包含条目列表和分组列表
- 支持版本迁移

```java
public class Vault {
    private static final int VERSION = 3;
    private final UUIDMap<VaultEntry> _entries;
    private final UUIDMap<VaultGroup> _groups;
    
    JSONObject toJson()
    static Vault fromJson(JSONObject obj)
}
```

**VaultEntry**
- 单个 2FA 条目
- 包含 OTP 信息、图标、分组关联

```java
public class VaultEntry extends UUIDMap.Value {
    private String _name;           // 账户名
    private String _issuer;         // 服务提供商
    private OtpInfo _info;          // OTP 配置
    private VaultEntryIcon _icon;   // 图标
    private boolean _isFavorite;    // 收藏标记
    private int _usageCount;        // 使用次数
    private long _lastUsedTimestamp;// 最后使用时间
    private String _note;           // 备注
    private Set<UUID> _groups;      // 所属分组
}
```

### 3.2 OTP 模块

#### 3.2.1 类层次结构

```
OtpInfo (抽象基类)
    ├── TotpInfo      (TOTP 算法)
    ├── HotpInfo      (HOTP 算法)
    ├── SteamInfo     (Steam 专用)
    ├── MotpInfo      (mOTP 算法)
    └── YandexInfo    (Yandex 专用)
```

#### 3.2.2 OTP 算法实现

| 算法 | 说明 | 默认参数 |
|------|------|----------|
| TOTP | 基于时间的一次性密码 | SHA1, 6位, 30秒周期 |
| HOTP | 基于计数器的一次性密码 | SHA1, 6位 |
| Steam | Steam 专用 TOTP | SHA1, 5位, 30秒周期 |
| MOTP | 移动 OTP | MD5, 6位, 10秒周期, 需要 PIN |
| Yandex | Yandex 专用 | SHA256, 8位, 30秒周期, 需要 PIN |

#### 3.2.3 Google Auth URI 支持

支持标准的 `otpauth://` URI 格式：
```
otpauth://totp/Example:alice@google.com?secret=JBSWY3DPEHPK3PXP&issuer=Example
```

以及 Google Authenticator 的批量导出格式：
```
otpauth-migration://offline?data=...
```

### 3.3 安全/加密模块

#### 3.3.1 加密架构

```
┌─────────────────────────────────────────────────────────┐
│                     Vault 文件结构                       │
├─────────────────────────────────────────────────────────┤
│  {                                                      │
│      "version": 1,                                      │
│      "header": {                                        │
│          "slots": [...],      // 密钥槽列表              │
│          "params": {           // 加密参数               │
│              "nonce": "...",   // 96-bit nonce          │
│              "tag": "..."      // 认证标签               │
│          }                                              │
│      },                                                 │
│      "db": "..."  // Base64 加密的 Vault 内容           │
│  }                                                      │
└─────────────────────────────────────────────────────────┘
```

#### 3.3.2 密钥槽系统 (Slot System)

受 LUKS 启发设计的密钥槽系统，支持多凭证解锁：

```
Master Key (256-bit 随机密钥)
    │
    ├──[Slot 1: Password]── scrypt(password) ──► AES-GCM ──► 加密后的 Master Key
    │
    ├──[Slot 2: Biometric]── Android Keystore ──► AES-GCM ──► 加密后的 Master Key
    │
    └──[Slot 3: Backup Password]── scrypt(password) ──► AES-GCM ──► 加密后的 Master Key
```

**Slot 类型:**

| 类型 | ID | 说明 |
|------|-----|------|
| Raw | 0x00 | 原始 AES 密钥 |
| Password | 0x01 | 密码 + scrypt |
| Biometric | 0x02 | Android Keystore + 生物识别 |

**scrypt 参数:**
- N: 2^15 = 32768
- r: 8
- p: 1

#### 3.3.3 加密工具类

**CryptoUtils**
- AES-256-GCM 加密/解密
- 随机数生成
- 密钥派生

**KeyStoreHandle**
- Android Keystore 封装
- 生物识别密钥管理
- 密钥有效性检测

### 3.4 导入模块

#### 3.4.1 支持的导入源

支持从 17+ 个应用导入：

| 应用 | 需要 Root | 说明 |
|------|-----------|------|
| 2FAS Authenticator | ❌ | JSON 导出文件 |
| Aegis | ❌ | JSON 导出文件 |
| andOTP | ❌ | JSON/备份文件 |
| Authenticator Plus | ❌ | 备份文件 |
| Authy | ✅ | 内部数据库 |
| Battle.net | ✅ | 内部数据库 |
| Bitwarden | ❌ | JSON 导出 |
| Duo | ✅ | 内部数据库 |
| Ente Auth | ❌ | 加密备份 |
| FreeOTP | ✅ | 内部存储 |
| FreeOTP+ | ✅ | 内部存储 |
| Google Authenticator | ✅ | 内部数据库 |
| Microsoft Authenticator | ✅ | 内部数据库 |
| Proton Authenticator | ❌ | JSON 导出 |
| Steam | ✅ | 内部数据库 |
| Stratum | ✅ | 内部数据库 |
| TOTP Authenticator | ✅ | 内部数据库 |
| WinAuth | ❌ | 导出文件 |

#### 3.4.2 导入器架构

```java
public abstract class DatabaseImporter {
    // 工厂方法
    static DatabaseImporter create(Context context, Class<? extends DatabaseImporter> type)
    
    // 读取文件
    State read(InputStream stream)
    
    // 直接从应用读取 (需要 root)
    State readFromApp(Shell shell)
    
    // 转换结果
    class Result {
        UUIDMap<VaultEntry> entries;
        UUIDMap<VaultGroup> groups;
        List<DatabaseImporterEntryException> errors;
    }
}
```

### 3.5 图标包模块

#### 3.5.1 图标包格式

图标包是 ZIP 压缩包，包含：
- `pack.json`: 包定义文件
- 图标文件 (支持 SVG/PNG/JPEG)

**pack.json 结构:**
```json
{
    "uuid": "c553f06f-2a17-46ca-87f5-56af90dd0500",
    "name": "Icon Pack Name",
    "version": 1,
    "icons": [
        {
            "name": "Google",
            "filename": "services/Google.png",
            "category": "Services",
            "issuer": ["google", "gmail"]
        }
    ]
}
```

#### 3.5.2 图标包管理

```
存储路径: /data/data/com.beemdevelopment.aegis/files/icons/
    └── {uuid}/
        └── {version}/
            ├── pack.json
            └── [图标文件]
```

### 3.6 数据库模块

仅用于审计日志：

```java
@Database(entities = {AuditLogEntry.class}, version = 1)
public abstract class AppDatabase extends RoomDatabase {
    public abstract AuditLogDao auditLogDao();
}
```

**审计日志类型:**
- 保险库解锁
- 备份完成
- 导入操作
- 条目修改

---

## 4. 安全设计

### 4.1 威胁模型

| 威胁 | 缓解措施 |
|------|----------|
| 设备丢失/被盗 | AES-256-GCM 加密 |
| 密码破解 | scrypt KDF，内存困难 |
| 备份文件泄露 | 加密备份 + 可选独立备份密码 |
| 恶意应用访问 | Android 沙箱 + 加密 |
| 屏幕截图 | FLAG_SECURE |
| 近期应用缩略图 | 空白 Activity 覆盖 |

### 4.2 自动锁定策略

```java
// 自动锁定触发条件
AUTO_LOCK_ON_MINIMIZE  // 应用切换到后台
AUTO_LOCK_ON_BACK_BUTTON // 点击返回键
AUTO_LOCK_ON_DEVICE_LOCK // 设备锁屏
AUTO_LOCK_ON_INACTIVITY  // 一段时间无操作
```

### 4.3 生物识别安全

- 使用 Android Keystore 存储密钥
- 设置 `setUserAuthenticationRequired(true)`
- 密钥与生物识别注册绑定
- 添加新指纹时密钥自动失效

---

## 5. 数据存储格式

### 5.1 Vault 文件格式

**文件位置:** `/data/data/com.beemdevelopment.aegis/files/aegis.json`

**顶层结构:**
```json
{
    "version": 1,
    "header": {
        "slots": [...],
        "params": {
            "nonce": "hex",
            "tag": "hex"
        }
    },
    "db": "base64_encrypted_or_plain_json"
}
```

### 5.2 Vault 内容格式

```json
{
    "version": 3,
    "entries": [
        {
            "type": "totp",
            "uuid": "...",
            "name": "alice@example.com",
            "issuer": "Google",
            "note": "",
            "favorite": false,
            "icon": null,
            "icon_mime": null,
            "icon_hash": null,
            "info": {
                "secret": "BASE32SECRET",
                "algo": "SHA1",
                "digits": 6,
                "period": 30
            },
            "groups": ["uuid-1", "uuid-2"]
        }
    ],
    "groups": [
        {
            "uuid": "...",
            "name": "Personal"
        }
    ],
    "icons_optimized": true
}
```

### 5.3 偏好设置存储

使用 Android SharedPreferences 存储：
- 主题设置
- 排序方式
- 自动锁定策略
- 备份配置
- 使用统计

---

## 6. UI架构

### 6.1 Activity 结构

```
MainActivity (主界面)
    ├── AuthActivity (解锁)
    ├── IntroActivity (首次引导)
    │       ├── WelcomeSlide
    │       ├── SecurityPickerSlide
    │       ├── SecuritySetupSlide
    │       └── DoneSlide
    ├── EditEntryActivity (编辑条目)
    ├── ScannerActivity (扫描二维码)
    ├── PreferencesActivity (设置)
    │       ├── AppearancePreferencesFragment
    │       ├── SecurityPreferencesFragment
    │       ├── BackupsPreferencesFragment
    │       ├── BehaviorPreferencesFragment
    │       └── ImportExportPreferencesFragment
    ├── GroupManagerActivity (分组管理)
    ├── AssignIconsActivity (分配图标)
    └── ImportEntriesActivity (导入条目)
```

### 6.2 主要 UI 组件

**EntryListView**
- 使用 RecyclerView 显示条目列表
- 支持多种视图模式 (Normal/Compact/Small/Tile)
- 支持搜索和分组过滤
- 自动刷新 TOTP 代码

**视图模式:**
| 模式 | 描述 |
|------|------|
| Normal | 标准视图，显示图标、发行者、账户名、代码 |
| Compact | 紧凑视图 |
| Small | 小视图 |
| Tile | 磁贴视图 |

### 6.3 快捷操作

**应用快捷方式:**
- 长按图标 -> "New entry" -> 打开扫码界面

**快速设置磁贴 (Quick Settings Tile):**
- "Open vault": 打开应用
- "Open scanner": 直接打开扫描器

---

## 7. 依赖和第三方库

### 7.1 AndroidX 库

| 库 | 版本 | 用途 |
|----|------|------|
| activity | 1.10.1 | Activity API |
| appcompat | 1.7.0 | 向后兼容 |
| biometric | 1.1.0 | 生物识别 |
| cameraX | 1.4.2 | 相机扫描 |
| constraintlayout | 2.2.1 | 布局 |
| preference | 1.2.1 | 设置界面 |
| recyclerview | 1.4.0 | 列表视图 |
| room | 2.7.1 | 数据库 |
| viewpager2 | 1.1.0 | 引导页 |

### 7.2 第三方库

| 库 | 版本 | 用途 |
|----|------|------|
| BouncyCastle | 1.80 | 加密算法 |
| Glide | 4.16.0 | 图像加载 |
| Guava | 33.4.8 | 工具类 |
| Hilt | 2.56.2 | 依赖注入 |
| libsu | 6.0.0 | Root Shell |
| Material | 1.12.0 | Material Design |
| Protobuf | 4.31.0 | 序列化 |
| ZXing | 3.5.3 | 二维码处理 |
| zip4j | 2.11.5 | ZIP 处理 |
| zxcvbn | 1.9.0 | 密码强度检测 |

### 7.3 构建配置

```gradle
android {
    compileSdk 35
    minSdkVersion 23
    targetSdkVersion 35
    versionCode 81
    versionName "3.4.2"
    
    compileOptions {
        targetCompatibility JavaVersion.VERSION_17
        sourceCompatibility JavaVersion.VERSION_17
        coreLibraryDesugaringEnabled true
    }
}
```

---

## 附录

### A. 目录结构

```
app/src/main/java/com/beemdevelopment/aegis/
├── crypto/          # 加密相关
├── database/        # 审计日志数据库
├── helpers/         # 辅助类
├── icons/           # 图标包管理
├── importers/       # 导入器
├── otp/             # OTP 实现
├── receivers/       # 广播接收器
├── services/        # 后台服务
├── ui/              # UI 层
├── util/            # 工具类
└── vault/           # Vault 核心
```

### B. 测试结构

```
app/src/
├── test/            # 单元测试
│   ├── crypto/      # 加密测试
│   ├── importers/   # 导入器测试
│   ├── otp/         # OTP 测试
│   └── vault/       # Vault 测试
└── androidTest/     # 集成测试
    └── ...
```

---

**文档结束**

*本文档基于 Aegis Authenticator v3.4.2 版本源码分析生成*
