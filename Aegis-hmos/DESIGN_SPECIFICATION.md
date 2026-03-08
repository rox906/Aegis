# Aegis 鸿蒙版 (Aegis-HarmonyOS) 设计说明书

## 项目概述

Aegis-HarmonyOS 是开源双因素认证应用 Aegis 的鸿蒙(HarmonyOS)移植版本。该项目使用 ArkTS 语言和鸿蒙原生框架构建，实现了完整的 2FA 功能，包括 TOTP、HOTP、Steam 等多种 OTP 算法支持。

## 技术栈

- **开发语言**: ArkTS (TypeScript 扩展)
- **框架**: HarmonyOS Next (鸿蒙 Next)
- **最低版本**: API 12+
- **构建工具**: hvigor
- **加密库**: @kit.CryptoArchitectureKit
- **存储**: @kit.ArkData (Preferences), @kit.CoreFileKit (文件系统)

## 项目结构

```
Aegis-hmos/
├── AppScope/                 # 应用级共享模块
├── entry/                    # 主模块入口
│   ├── src/main/ets/
│   │   ├── entryability/     # 应用入口能力
│   │   ├── entrybackupability/ # 备份能力
│   │   ├── model/            # 数据模型
│   │   ├── pages/            # UI 页面
│   │   ├── service/          # 业务服务
│   │   └── util/             # 工具类
├── oh_modules/              # 依赖模块
├── build-profile.json5       # 构建配置
├── oh-package.json5         # 包配置
└── hvigorfile.ts            # 构建脚本
```

## 核心架构设计

### 1. 应用入口 (EntryAbility)

**文件**: `entry/src/main/ets/entryability/EntryAbility.ets`

**职责**:
- 应用生命周期管理
- 服务初始化
- 主页面加载

**初始化流程**:
```
onCreate()
  └── setColorMode() // 设置颜色模式
onWindowStageCreate()
  ├── VaultService.init(context)      // 初始化保险库服务
  ├── PreferencesService.init(context) // 初始化偏好设置
  └── DatabaseService.init(context)   // 初始化数据库服务
  └── loadContent('pages/Index') // 加载主页面
```

### 2. 服务层架构

#### 2.1 VaultService - 保险库服务

**文件**: `entry/src/main/ets/service/VaultService.ets`

**职责**:
- 保险库数据管理 (CRUD)
- 文件读写操作
- 数据序列化/反序列化
- 锁/解锁状态管理

**核心方法**:

| 方法 | 说明 |
|------|------|
| `init(context)` | 初始化服务，设置文件目录 |
| `vaultFileExists()` | 检查保险库文件是否存在 |
| `loadVault()` | 从文件加载保险库 |
| `saveVault()` | 保存保险库到文件 |
| `initNewVault()` | 初始化新的空保险库 |
| `isVaultLocked()` | 检查保险库是否锁定 |
| `isVaultLoaded()` | 检查保险库是否已加载 |
| `isVaultInitNeeded()` | 检查是否需要初始化 |
| `lock()` | 锁定保险库 |
| `exportVault()` | 导出保险库为 JSON 字符串 |

**数据模型**:
```typescript
interface VaultData {
  version: number;           // 数据版本
  entries: VaultEntry[];     // OTP 条目列表
  groups: VaultGroup[];      // 分组列表
  iconsOptimized: boolean;   // 图标是否已优化
}

interface VaultEntry {
  uuid: string;              // 唯一标识符
  name: string;              // 账户名
  issuer: string;           // 发行方
  info: AnyOtpInfo;        // OTP 信息
  icon: VaultEntryIcon | undefined; // 图标
  isFavorite: boolean;      // 是否收藏
  usageCount: number;       // 使用次数
  lastUsedTimestamp: number; // 最后使用时间戳(秒)
  note: string;            // 备注
  groups: Set<string>;     // 所属分组 UUID 集合
}
```

**文件格式**:
```json
{
  "version": 1,
  "header": {
    "slots": null,
    "params": null
  },
  "db": {
    "version": 3,
    "entries": [...],
    "groups": [...],
    "icons_optimized": true
  }
}
```

#### 2.2 OtpService - OTP 生成服务

**文件**: `entry/src/main/ets/service/OtpService.ets`

**职责**:
- 各种 OTP 算法的代码生成
- 代码格式化和分组
- 进度计算

**支持的 OTP 类型**:

| 类型 | 算法 | 说明 |
|------|------|------|
| TOTP | 时间型 | 基于时间的 HMAC，默认 30 秒刷新 |
| HOTP | 计数型 | 基于计数器的 HMAC |
| Steam | Steam Guard | TOTP 变体，使用自定义字母表 |
| mOTP | Mobile OTP | 基于 PIN 和时间的 OTP |
| Yandex | Yandex OTP | 基于 PIN 和时间的 OTP |

**核心方法**:
```typescript
class OtpService {
  static async generateCode(info: AnyOtpInfo): Promise<string>
  static async generateTotp(info: TotpInfo, timeSeconds?: number): Promise<string>
  static async generateHotpCode(info: HotpInfo): Promise<string>
  static async generateSteam(info: SteamInfo, timeSeconds?:?: Promise<string>
  static async generateMotp(info: MotpInfo, timeSeconds?: number): Promise<string>
  static async generateYandex(info: YandexInfo, timeSeconds?: number): Promise<string>

  static getMillisTillNextRotation(period: number): number
  static getTotpProgress(period: number): number
  static formatCodeWithGrouping(code: string, groupSize: number): string
}
```

**加密实现**:
- 使用 `@kit.CryptoArchitectureKit` 进行 HMAC 和摘要计算
- 支持 SHA1、SHA256、SHA512、MD5 算法
- TOTP/HOTP 基于 RFC 4226 标准
- Steam 使用自定义字母表: `23456789BCDFGHJKMNPQRTVWXY`

#### 2.3 PreferencesService - 偏好设置服务

**文件**: `entry/src/main/ets/service/PreferencesService.ets`

**职责**:
- 应用偏好设置管理
- 使用 `@kit.ArkData.preferences` 持久化存储

**支持的设置**:

| 设置键 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| pref_intro | boolean | false | 是否已完成介绍 |
| pref_tap_to_reveal | boolean | false | 点击显示代码 |
| pref_tap_to_reveal_time | number | 30 | 显示时间(秒) |
| pref_highlight_entry | boolean | false | 高亮当前条目 |
| pref_haptic_feedback | boolean | true | 触觉反馈 |
| pref_pause_entry | boolean | false | 暂停条目 |
| pref_secure_screen | boolean | true | 安全屏幕 |
| pref_current_sort_category | number | 0 | 排序类别 |
| pref_current_view_mode | number | 0 | 视图模式 |
| pref_current_theme | number | 0 | 主题 |
| pref_current_copy_behavior | number | 0 | 复制行为 |
| pref_code_group_size_string | string | "GROUPING_THREES" | 代码分组 |
| pref_show_icons | boolean | true | 显示图标 |
| pref_show_next_code | boolean | false | 显示下一个代码 |
| pref_expiration_state | boolean | true | 显示过期状态 |
| pref_auto_lock_mask | number | 10 | 自动锁定掩码 |
| pref_search_behavior_mask | number | 3 | 搜索行为掩码 |

#### 2.4 DatabaseService - 数据库服务

**文件**: `entry/src/main/ets/service/DatabaseService.ets`

**职责**:
- 审计日志管理
- 使用关系型数据库存储审计事件

**审计事件类型**:
```typescript
enum EventType {
  VAULT_UNLOCKED = 0,           // 保险库解锁
  VAULT_BACKUP_CREATED = 1,      // 备份创建
  VAULT_ANDROID_BACKUP_CREATED = 2, // Android 备份创建
  VAULT_EXPORTED = 3,            // 保险库导出
  ENTRY_SHARED = 4,              // 条目分享
  VAULT_UNLOCK_FAILED_PASSWORD = 5,  // 密码解锁失败
  VAULT_UNLOCK_FAILED_BIOMETRICS = 6 // 生物识别解锁失败
}
```

### 3. 数据模型层

#### 3.1 OtpModels - OTP 模型

**文件**: `entry/src/main/ets/model/OtpModels.ets`

**类型定义**:
```typescript
enum OtpType {
  TOTP = 'totp',
  HOTP = 'hotp',
  STEAM = 'steam',
  MOTP = 'motp',
  YANDEX = 'yandex'
}

enum OtpAlgorithm {
  SHA1 = 'SHA1',
  SHA256 = 'SHA256',
  SHA512 = 'SHA512',
  MD5 = 'MD5'
}

interface OtpInfo {
  type: OtpType;
  secret: Uint8Array;
  algorithm: OtpAlgorithm;
  digits: number;
}

interface TotpInfo extends OtpInfo {
  type: OtpType.TOTP;
  period: number;
}

interface HotpInfo extends OtpInfo {
  type: OtpType.HOTP;
  counter: number;
}

interface SteamInfo extends OtpInfo {
  type: OtpType.STEAM;
  period: number;
}

interface MotpInfo extends OtpInfo {
  type: OtpType.MOTP;
  period: number;
  pin: string;
}

interface YandexInfo extends OtpInfo {
  type: OtpType.YANDEX;
  period: number;
  pin: string;
}

type AnyOtpInfo = TotpInfo | HotpInfo | SteamInfo | MotpInfo | YandexInfo;
```

#### 3.2 VaultModels - 保险库模型

**文件**: `entry/src/main/ets/model/VaultModels.ets`

**类型定义**:
```typescript
interface VaultEntry {
  uuid: string;
  name: string;
  issuer: string;
  info: AnyOtpInfo;
  icon: VaultEntryIcon | undefined;
  isFavorite: boolean;
  usageCount: number;
  lastUsedTimestamp: number;
  note: string;
  groups: Set<string>;
}

interface VaultEntryIcon {
  type: IconType;
  data: Uint8Array;
}

enum IconType {
  JPEG = 'jpeg',
  PNG = 'png',
  SVG = 'svg'
}

interface VaultGroup {
  uuid: string;
  name: string;
}

enum SortCategory {
  CUSTOM = 0,
  ACCOUNT = 1,
  ACCOUNT_REVERSED = 2,
  ISSUER = 3,
  ISSUER_REVERSED = 4,
  USAGE_COUNT = 5,
  LAST_USED = 6
}

enum ViewMode {
  NORMAL = 0,
  COMPACT = 1,
  SMALL = 2,
  TILES = 3
}

enum CopyBehavior {
  NEVER = 0,
  SINGLETAP = 1,
  DOUBLETAP = 2
}

enum AppTheme {
  SYSTEM = 0,
  LIGHT = 1,
  DARK = 2,
  AMOLED = 3,
  SYSTEM_AMOLED = 4
}
```

### 4. UI 页面层

#### 4.1 Index - 主页面

**文件**: `entry/src/main/ets/pages/Index.ets`

**功能**:
- 显示 OTP 条目列表
- 代码自动刷新 (每秒)
- 代码复制到剪贴板
- 搜索和过滤
- 排序选项
- 分组管理
- 条目操作 (编辑、删除、收藏)

**状态管理**:
```typescript
@State entries: EntryDisplayItem[] = [];
@State searchQuery: string = '';
@State selectedGroupUuid: string = '';
@State sortCategory: SortCategory = SortCategory.CUSTOM;
@State groups: VaultGroup[] = [];
@State isSearchVisible: boolean = false;
@State isMenuVisible: boolean = false;
@State isSortMenuVisible: boolean = false;
@State isLoading: boolean = true;
```

**刷新机制**:
```typescript
// 每 1 秒刷新代码
this.timerId = setInterval(() => {
  this.refreshCodes();
}, 1000);

// 代码生成是异步的，避免阻塞 UI
OtpService.generateCode(entry.info).then((code: string) => {
  // 更新显示
});
```

#### 4.2 AuthPage - 认证页面

**文件**: `entry/src/main/ets/pages/AuthPage.ets`

**功能**:
- 显示密码输入界面
- 解锁加密保险库 (当前为占位符)

**注意**: 当前版本加密解密功能尚未实现。

#### 4.3 IntroPage - 介绍页面

**文件**: `entry/src/main/ets/pages/IntroPage.ets`

**功能**:
- 欢迎界面
- 创建新保险库
- 导入现有保险库 (计划功能)

#### 4.4 EditEntryPage - 编辑条目页面

**文件**: `entry/src/main/ets/pages/EditEntryPage.ets`

**功能**:
- 添加/编辑 OTP 条目
- 支持所有 OTP 类型
- 高级设置 (算法、位数、周期等)
- 分组分配

#### 4.5 PreferencesPage - 设置页面

**文件**: `entry/src/main/ets/pages/PreferencesPage.ets`

**功能**:
- 外观设置 (主题、视图模式)
- 行为设置 (复制、点击显示)
- 安全设置 (安全屏幕、PIN 键盘)
- 备份设置
- 分组管理

#### 4.6 GroupManagerPage - 分组管理页面

**文件**: `entry/src/main/ets/pages/GroupManagerPage.ets`

**功能**:
- 创建/编辑/删除分组
- 分组重命名

#### 4.7 ExportPage - 导出页面

**文件**: `entry/src/main/ets/pages/ExportPage.ets`

**功能**:
- 导出保险库为 JSON
- 导出为 QR 码 (计划功能)

### 5. 工具层

#### 5.1 Encoding - 编码工具

**文件**: `entry/src/main/ets/util/Encoding.ets`

**功能**:
- Base32 编码/解码
- Base64 编码/解码
- Hex 编码/解码
- UUID 生成

**实现示例**:
```typescript
class Base32 {
  static decode(input: string): Uint8Array {
    // RFC 4648 Base32 解码
  }
  static encode(data: Uint8Array): string {
    // RFC 4648 Base32 编码
  }
}

function generateUUID(): string {
  // 生成 UUID v4 格式
  // 格式: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
}
```

#### 5.2 OtpUriParser - OTP URI 解析器

**文件**: `entry/src/main/ets/util/OtpUriParser.ets`

**功能**:
- 解析 `otpauth://` URI
- 支持所有 OTP 类型参数
- 创建 VaultEntry 对象

**URI 格式**:
```
otpauth://TYPE/LABEL?PARAMS
```

- **TYPE**: totp, hotp, steam, motp, yandex
- **LABEL**: issuer:accountName 或 accountName
- **PARAMS**: secret, issuer, algorithm, digits, period, counter, pin

### 6. 应用生命周期

```
应用启动
  └── EntryAbility.onCreate()
      └── VaultService.init()
      └── PreferencesService.init()
      └── DatabaseService.init()
      └── 加载 Index 页面
          └── 检查保险库状态
              ├── 未初始化 → IntroPage
              ├── 加密且锁定 → AuthPage
              └── 已加载 → 显示条目列表

页面切换
  └── Index.aboutToAppear()
      └── 加载保险库数据
      └── 启动定时器 (1秒刷新)
  └── Index.aboutToDisappear()
() └── 停止定时器
```

## 安全设计

### 数据安全

1. **保险库加密**: 计划支持密码加密 (当前仅支持未加密）
2. **安全屏幕**: 防止截图和录屏
3. **PIN 键盘**: 敏感时使用 PIN 键盘
4. **自动锁定**: 支持多种自动锁定场景

### 数据存储

1. **保险库文件**: 存储在应用私有目录 `filesDir/aegis.json`
2. **偏好设置**: 使用 HarmonyOS Preferences API
3. **审计日志**: 使用关系型数据库存储

## 加密实现细节

### OTP 算法加密

| 算法 | 算法 | 密钥派生 |
|------|------|----------|
| TOTP | HMAC-SHA1/256/512 | secret + time_counter |
| HOTP | HMAC-SHA1/256/512 | secret + counter |
| Steam | HMAC-SHA1 |256/512 | secret + time_counter + 自定义字母表( |
| mOTP | MD5(secret + pin + time_counter) | - |
| Yandex | SHA256(key_hash + time_counter) | key_hash = SHA256(pin + secret) |

### HMAC 实现

使用 `@kit.CryptoArchitectureKit`:
```typescript
```
import { cryptoFramework } from '@kit.CryptoArchitectureKit';

// 创建 MAC
const mac = cryptoFramework.createMac(`HMAC|${algoName}`);

// 创建密钥
const symKeyBlob: cryptoFramework.DataBlob = { data: secret };
const symKeyGenerator = cryptoFramework.createSymKeyGenerator(`HMAC`);
const symKey = await symKeyGenerator.convertKey(symKeyBlob);

// 初始化 MAC
await mac.init(symKey);

// 更新数据
await mac.update({ data: data });

// 计算结果
const result = await mac.doFinal();
return result.data;
```

## 性能优化

1. **异步代码生成**: OTP 生成在 Worker 线程中执行，避免阻塞 UI
2. **增量更新**: 仅更新变化的条目，避免全量刷新
3. **延迟加载**: 保险库数据按需加载
4. **内存管理**: 使用 Uint8Array 存储二进制数据

## 待实现功能

1. **加密保险库支持**
   - 密码加密/解密
   - 密钥派生 (SCrypt/Argon2)
   - 生物识别解锁

2. **导入功能**
   - 从其他认证器应用导入
   - QR 码扫描导入
   - URI 导入

3. **备份功能**
   - 云端备份
   - 自动备份
   - 备份恢复

4. **高级功能**
   - 条目图标
   - 动态主题
   - 小组件
   - 快捷方式

## 鸸蒙 API 使用

| 功能 | 鸿蒙 API | 说明 |
|------|---------|------|
| UI 框架 | @kit.ArkUI | ArkTS 组件、路由、状态管理 |
| 剪贴板 | @kit.BasicServicesKit | pasteboard |
| 文件系统 | @kit.CoreFileKit | fileIo |
| 数据存储 | @kit.ArkData | preferences |
| 加密 | @kit.CryptoArchitectureKit | cryptoFramework |
| 日志 | @kit.PerformanceAnalysisKit | hilog |
| 能力 | @kit.AbilityKit | UIAbility、Context |

## 构建和部署

### 构建命令

```bash
# 清理构建产物
hvigor clean

# 构建 debug 版本
hvigor assembleHap --mode debug

# 构建 release 版本
hvigor assembleHap --mode release

# 安装到设备
hvigor install
```

### 运行

```bash
# 启动应用
hvigor start

# 停止应用
hvigor stop
```

## 兼容性说明

- **最低系统版本**: HarmonyOS 4.0 (API 12+)
- **设备支持**: 手机、平板
- **权限要求**: 无特殊权限要求

## 开发规范

### 代码风格

1. 使用 ArkTS 类型注解
2. 遵循 HarmonyOS 命名约定
3. 组件使用 @Entry 和 @Component 装饰器
4. 状态使用 @State 装饰器
5. 私有方法使用 private 修饰

### 文件组织

```
entry/src/main/ets/
├── entryability/     # 应用入口
├── model/            # 数据模型
├── pages/            # UI 页面
├── service/          # 业务服务
└── util/             # 工具类
```

### 错误处理

1. 使用 try-catch 捕获异常
2. 使用 promptAction.showToast() 显示用户友好错误
3. 关键操作失败时提供降级方案

## 测试策略

### 单元测试

```typescript
// 测试 OTP 生成
describe('OtpService', () => {
  it('should generate TOTP code', async () => {
    const info: TotpInfo = {
      type: OtpType.TOTP,
      secret: Base32.decode('JBSWY3DPEHPK3PXP'),
      algorithm: OtpAlgorithm.SHA1,
      digits: 6,
      period: 30
    };
    const code = await OtpService.generateCode(info);
    expect(code.length).toBe(6);
  });
});
```

### 集成测试

```typescript
// 测试保险库读写
describe('VaultService', () => {
  it('should save and load vault', () => {
    const service = VaultService.getInstance();
    service.init(context);
    service.initNewVault();

    const entry: VaultEntry = {
      // ... 创建条目
    };
    service.addEntry(entry);
    service.saveVault();

    service.loadVault();
    const entries = service.getEntries();
    expect(entries.length).toBe(1);
  });
});
```

## 已知限制

1. **加密保险库**: 当前仅支持未加密保险库
2. **导入功能**: 未实现从其他应用导入
3. **备份功能**: 未实现云端备份
4. **图标**: 未实现自定义图标
5. **生物识别**: 未实现

## 参考资料

- [HarmonyOS Next 开发文档](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5)
- [ArkTS 语言规范](https://developer.huawei.com/consumer/cn/doc/harmonyos-ts-guides-V5)
- [Aegis 原项目](https://github.com/beemdevelopment/aegis)
- [RFC 4226 - HOTP/TOTP](https://datatracker.ietf.org/doc/html/rfc4226.html)
