# Aegis Authenticator for HarmonyOS NEXT - 设计说明书

## 文档信息
- **项目名称**: Aegis Authenticator (HarmonyOS 移植版)
- **目标平台**: HarmonyOS NEXT (API 12+)
- **开发语言**: ArkTS
- **SDK版本**: 6.0.2(22)
- **文档日期**: 2026-03-07
- **原始项目**: Aegis Authenticator (Android, Java)

---

## 1. 项目概述

### 1.1 项目简介
Aegis Authenticator 是一个开源的两步验证（2FA）令牌管理应用，支持多种 OTP（一次性密码）算法。本项目是将 Android 原版应用移植到 HarmonyOS NEXT 平台的版本。

### 1.2 核心功能
- 支持 TOTP、HOTP、Steam、mOTP、Yandex 等多种 OTP 类型
- 密钥库（Vault）管理（加密/未加密）
- 令牌分组管理
- 导出/导入功能
- 偏好设置管理
- 审计日志

### 1.3 技术栈
| 技术 | 版本/说明 |
|------|----------|
| ArkTS | HarmonyOS 声明式 UI 框架 |
| API Level | 12 (6.0.2) |
| 构建工具 | Hvigor |
| 测试框架 | Hypium 1.0.25 + Hamock 1.0.0 |

---

## 2. 系统架构

### 2.1 整体架构图

```
┌─────────────────────────────────────────────────────────────────┐
│                        UI Layer (Pages)                       │
├─────────────────────────────────────────────────────────────────┤
│  Index.ets    AuthPage.ets   EditEntryPage.ets  IntroPage.ets │
│  PreferencesPage.ets  GroupManagerPage.ets  ExportPage.ets    │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                      Service Layer                             │
├─────────────────────────────────────────────────────────────────┤
│  VaultService      OtpService      PreferencesService           │
│  DatabaseService   (审计日志)                                   │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                      Model Layer                              │
├─────────────────────────────────────────────────────────────────┤
│  VaultModels.ets    OtpModels.ets                              │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                      Utility Layer                            │
├─────────────────────────────────────────────────────────────────┤
│  Encoding.ets (Base32, Base64, Hex, UUID)                    │
│  OtpUriParser.ets (QR码解析)                                  │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                  HarmonyOS System Kits                        │
├─────────────────────────────────────────────────────────────────┤
│  @kit.AbilityKit      @kit.ArkUI      @kit.CryptoArchitectureKit│
│  @kit.CoreFileKit     @kit.ArkData    @kit.BasicServicesKit    │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 模块划分

#### 2.2.1 Ability 层
- **EntryAbility.ets**: 应用入口 Ability
  - 初始化各项服务
  - 加载主页面

- **EntryBackupAbility.ets**: 备份扩展 Ability
  - 处理应用数据备份

#### 2.2.2 Pages 层（UI）
| 页面 | 文件 | 功能描述 |
|------|------|----------|
| 主页 | Index.ets | 显示 OTP 令牌列表，支持搜索、排序、分组筛选 |
| 认证页 | AuthPage.ets | 密码解锁页面 |
| 编辑条目 | EditEntryPage.ets | 添加/编辑 OTP 条目 |
| 介绍页 | IntroPage.ets | 首次启动引导页面 |
| 设置页 | PreferencesPage.ets | 应用偏好设置 |
| 分组管理 | GroupManagerPage.ets | 创建/编辑/删除分组 |
| 导出页 | ExportPage.ets | 导出密钥库 |
| 关于页 | AboutPage.ets | 应用信息 |

#### 2.2.3 Service 层
| 服务 | 文件 | 功能描述 |
|------|------|----------|
| VaultService | VaultService.ets | 密钥库管理（CRUD、加密/解密） |
| OtpService | OtpService.ets | OTP 代码生成 |
| PreferencesService | PreferencesService.ets | 偏好设置持久化 |
| DatabaseService | DatabaseService.ets | 审计日志数据库 |

#### 2.2.4 Model 层
| 模型 | 文件 | 功能描述 |
|------|------|----------|
| VaultModels | VaultModels.ets | 密钥库数据模型、分组、条目、加密参数 |
| OtpModels | OtpModels.ets | OTP 类型定义、算法枚举 |

#### 2.2.5 Utility 层
| 工具 | 文件 | 功能描述 |
|------|------|----------|
| Encoding | Encoding.ets | Base32/64/Hex 编解码、UUID 生成 |
| OtpUriParser | OtpUriParser.ets | OTP URI 解析（QR码） |

---

## 3. 数据模型

### 3.1 VaultModels.ets

#### 3.1.1 VaultEntry（密钥库条目）
```typescript
interface VaultEntry {
  uuid: string;              // 唯一标识符
  name: string;              // 账户名称
  issuer: string;            // 发行者
  info: AnyOtpInfo;          // OTP 信息
  icon: VaultEntryIcon;      // 图标
  isFavorite: boolean;        // 是否收藏
  usageCount: number;         // 使用次数
  lastUsedTimestamp: number;  // 最后使用时间
  note: string;              // 备注
  groups: Set<string>;        // 所属分组 UUID 集合
}
```

#### 3.1.2 VaultGroup（分组）
```typescript
interface VaultGroup {
  uuid: string;  // 唯一标识符
  name: string;   // 分组名称
}
```

#### 3.1.3 VaultData（密钥库数据）
```typescript
interface VaultData {
  version: number;          // 密钥库版本
  entries: VaultEntry[];    // 条目列表
  groups: VaultGroup[];     // 分组列表
  iconsOptimized: boolean;   // 图标是否优化
}
```

#### 3.1.4 VaultFileData（文件格式）
```typescript
interface VaultFileData {
  version: number;           // 文件格式版本
  header: VaultFileHeader;  // 文件头（加密信息）
  db: string | object;      // 数据库（加密字符串或 JSON 对象）
}
```

### 3.2 OtpModels.ets

#### 3.2.1 OTP 类型枚举
```typescript
enum OtpType {
  TOTP = 'totp',      // 基于时间的 OTP
  HOTP = 'hotp',      // 基于计数器的 OTP
  STEAM = 'steam',    // Steam Guard
  MOTP = 'motp',      // Mobile OTP
  YANDEX = 'yandex'   // Yandex OTP
}
```

#### 3.2.2 算法枚举
```typescript
enum OtpAlgorithm {
  SHA1 = 'SHA1',
  SHA256 = 'SHA256',
  SHA512 = 'SHA512',
  MD5 = 'MD5'
}
```

#### 3.2.3 OTP 信息接口
```typescript
interface OtpInfo {
  type: OtpType;
  secret: Uint8Array;
  algorithm: OtpAlgorithm;
  digits: number;
}

interface TotpInfo extends OtpInfo {
  type: OtpType.TOTP;
  period: number;  // 时间周期（秒）
}

interface HotpInfo extends OtpInfo {
  type: OtpType.HOTP;
  counter: number;  // 计数器
}

interface SteamInfo extends OtpInfo {
  type: OtpType.STEAM;
  period: number;
}

interface MotpInfo extends OtpInfo {
  type: OtpType.MOTP;
  period: number;
  pin: string;  // PIN 码
}

interface YandexInfo extends OtpInfo {
  type: OtpType.YANDEX;
  period: number;
  pin: string;
}
```

---

## 4. 核心服务设计

### 4.1 VaultService（密钥库服务）

#### 4.1.1 职责
- 密钥库文件的读写
- 条目的增删改查
- 分组管理
- 加密/解密（当前仅支持未加密）

#### 4.1.2 主要方法
| 方法 | 功能 |
|------|------|
| `init(context)` | 初始化服务 |
| `vaultFileExists()` | 检查密钥库文件是否存在 |
| `loadVault()` | 加载密钥库 |
| `saveVault()` | 保存密钥库 |
| `initNewVault()` | 初始化新密钥库 |
| `getEntries()` | 获取所有条目 |
| `addEntry(entry)` | 添加条目 |
| `updateEntry(entry)` | 更新条目 |
| `removeEntry(uuid)` | 删除条目 |
| `getGroups()` | 获取所有分组 |
| `addGroup(group)` | 添加分组 |
| `removeGroup(uuid)` | 删除分组 |
| `isEncrypted()` | 检查是否加密 |
| `exportVault()` | 导出密钥库为 JSON |

#### 4.1.3 文件格式
密钥库文件 `aegis.json` 存储在应用的 `filesDir` 目录下：

```json
{
  "version": 1,
  "header": {
    "slots": null,      // 加密槽（未加密时为 null）
    "params": null       // 加密参数（未加密时为 null）
  },
  "db": {
    "version": 3,
    "entries": [...],
    "groups": [...],
    "icons_optimized": true
  }
}
```

### 4.2 OtpService（OTP 服务）

#### 4.2.1 职责
- 生成各种类型的 OTP 代码
- 计算时间进度
- 格式化代码显示

#### 4.2.2 主要方法
| 方法 | 功能 |
|------|------|
| `generateCode(info)` | 生成 OTP 代码 |
| `generateTotp(info)` | 生成 TOTP 代码 |
| `generateHotpCode(info)` | 生成 HOTP 代码 |
| `generateSteam(info)` | 生成 Steam 代码 |
| `generateMotp(info)` | 生成 mOTP 代码 |
| `generateYandex(info)` | 生成 Yandex 代码 |
| `getTotpProgress(period)` | 获取 TOTP 倒计时进度 |
| `formatCodeWithGrouping(code, size)` | 格式化代码（分组显示） |

#### 4.2.3 算法实现
- **HMAC**: 使用 `@kit.CryptoArchitectureKit` 的 `createMac`
- **Digest**: 使用 `createMd` 进行 MD5/SHA 哈希
- **动态截断**: RFC 4226 标准

### 4.3 PreferencesService（偏好设置服务）

#### 4.3.1 职责
- 应用设置的持久化
- 使用 HarmonyOS Preferences API

#### 4.3.2 支持的设置项
| 设置键 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| pref_intro | boolean | false | 是否已完成介绍 |
| pref_tap_to_reveal | boolean | false | 点击显示代码 |
| pref_tap_to_reveal_time | number | 30 | 显示时长（秒） |
| pref_highlight_entry | boolean | false | 高亮条目 |
| pref_haptic_feedback | boolean | true | 触觉反馈 |
| pref_secure_screen | boolean | true | 安全屏幕 |
| pref_current_sort_category | number | 0 | 排序类别 |
| pref_current_copy_behavior | number | 0 | 复制行为 |
| pref_code_group_size_string | string | GROUPING_THREES | 代码分组 |
| pref_show_icons | boolean | true | 显示图标 |
| pref_show_next_code | boolean | false | 显示下一个代码 |
| pref_expiration_state | boolean | true | 显示过期状态 |
| pref_timeout | number | -1 | 自动锁定超时 |
| pref_backups | boolean | false | 启用备份 |
| pref_pin_keyboard | boolean | false | PIN 键盘 |
| pref_focus_search | boolean | false | 启动时聚焦搜索 |
| pref_minimize_on_copy | boolean | false | 复制后最小化 |
| pref_groups_multiselect | boolean | false | 分组多选 |
| pref_dynamic_colors | boolean | false | 动态颜色 |
| pref_warn_time_sync | boolean | true | 时间同步警告 |
| pref_lang | string | system | 语言 |
| pref_auto_lock_mask | number | 10 | 自动锁定掩码 |
| pref_search_behavior_mask | number | 3 | 搜索行为掩码 |

---

## 5. UI 设计

### 5.1 主页（Index.ets）

#### 5.1.1 布局结构
```
┌─────────────────────────────────────────┐
│  Aegis    🔍  🔒  ⇅  ⋮              │  工具栏
├─────────────────────────────────────────┤
│  [All] [Work] [Personal] [Finance]    │  分组筛选（水平滚动）
├─────────────────────────────────────────┤
│  Sorted by: Account (A-Z) [Clear]     │  排序指示器
├─────────────────────────────────────────┤
│  ┌───────────────────────────────────┐ │
│  │ ★ Google  [TOTP]      ⏱  Copy │ │  条目卡片
│  │   john@example.com                │ │
│  │   123 456                        │ │
│  └───────────────────────────────────┘ │
│  ┌───────────────────────────────────┐ │
│  │   GitHub  [TOTP]      ⏱  Copy │ │
│  │   user@github.com                │ │
│  │   789 012                        │ │
│  └───────────────────────────────────┘ │
│                                     │ │
│                                     │ │
└─────────────────────────────────────────┘
                              +         FAB
```

#### 5.1.2 交互功能
- **搜索**: 点击搜索图标显示搜索框
- **锁定**: 点击锁图标锁定密钥库
- **排序**: 点击排序图标选择排序方式
- **复制**: 点击 Copy 按钮复制代码到剪贴板
- **长按**: 显示操作菜单（复制、编辑、收藏、删除）
- **FAB**: 跳转到添加条目页面

### 5.2 认证页（AuthPage.ets）

#### 5.2.1 布局结构
```
┌─────────────────────────────────────────┐
│                                         │
│              [Logo]                    │
│                                         │
│            Vault Locked                  │
│                                         │
│      ┌─────────────────────┐            │
│      │  Enter password     │            │
│      └─────────────────────┘            │
│                                         │
│          [Unlock]                       │
│                                         │
└─────────────────────────────────────────┘
```

### 5.3 编辑条目页（EditEntryPage.ets）

#### 5.3.1 表单字段
- Issuer（发行者）
- Account Name（账户名）
- Secret（密钥，Base32）
- Type（OTP 类型选择器）
- Advanced Settings（高级设置）
  - Algorithm（算法）
  - Digits（位数）
  - Period/Counter（周期/计数器）
  - PIN（mOTP/Yandex）
- Note（备注）
- Favorite（收藏开关）
- Groups（分组选择）

### 5.4 设置页（PreferencesPage.ets）

#### 5.4.1 设置分组
- **Appearance**: Theme, View Mode, Show Icons, Show Next Code, Show Expiration State
- **Behavior**: Copy Behavior, Tap to Reveal, Highlight Entry, Haptic Feedback, Minimize on Copy, Focus Search on Start
- **Security**: Secure Screen, PIN Keyboard, Time Sync Warning
- **Backups**: Export Vault
- **Groups**: Manage Groups

---

## 6. 安全设计

### 6.1 当前状态
- **加密支持**: 密钥库文件格式支持加密，但当前实现仅支持未加密模式
- **安全屏幕**: 防止屏幕截图
- **自动锁定**: 支持多种自动锁定触发条件

### 6.2 待实现的安全功能
1. **密码加密**: 使用 SCrypt 派生密钥
2. **AES-GCM**: 加密密钥库内容
3. **生物识别**: 支持指纹/面容解锁
4. **安全剪贴板**: 自动清除剪贴板内容

### 6.3 加密方案设计

#### 6.3.1 密钥派生（SCrypt）
```
masterKey = SCrypt(password, salt, N=32768, r=8, p=1, keyLen=32)
```

#### 6.3.2 加密流程
```
1. 生成随机 nonce (12 bytes)
2. 生成随机 masterKey (32 bytes)
3. 使用 SCrypt 从密码派生 keyWrapKey
4. 使用 AES-GCM 加密 masterKey，得到 encryptedMasterKey
5. 使用 AES-GCM 加密 vaultData，得到 encryptedDb
6. 保存到文件
```

---

## 7. 数据持久化

### 7.1 存储位置
| 数据 | 位置 | API |
|------|------|-----|
| 密钥库 | `filesDir/aegis.json` | fileIo |
| 偏好设置 | `preferences/aegis_prefs` | @kit.ArkData |
| 审计日志 | `database/audit.db` | relationalStore |
| 导出文件 | `cacheDir/` | fileIo |

### 7.2 数据备份
- **EntryBackupAbility**: 实现应用数据备份扩展
- 备份配置文件: `resources/base/profile/backup_config.json`

---

## 8. 测试策略

### 8.1 单元测试
- OTP 生成算法测试
- 编解码工具测试
- 数据模型序列化测试

### 8.2 集成测试
- 密钥库读写测试
- 偏好设置持久化测试

### 8.3 UI 测试
- 页面导航测试
- 表单提交测试
- 用户交互测试

---

## 9. 已知限制与待办事项

### 9.1 当前限制
1. **加密功能**: 密钥库加密未实现
2. **二维码扫描**: QR 码导入功能未实现
3. **导入功能**: 仅支持导出，不支持导入
4. **云同步**: 无云备份功能
5. **生物识别**: 未实现
6. **时间同步警告**: 未实现
7. **暗色主题**: 仅支持浅色主题

### 9.2 待办事项
| 优先级 | 功能 | 状态 |
|--------|------|------|
| P0 | 密钥库加密/解密 | 待实现 |
| P0 | QR 码扫描导入 | 待实现 |
| P1 | 暗色主题支持 | 待实现 |
| P1 | 生物识别解锁 | 待实现 |
| P1 | 导入功能 | 待实现 |
| P2 | 云备份 | 待实现 |
| P2 | 时间同步警告 | 待实现 |
| P3 | 小组件 | 待实现 |

---

## 10. 开发规范

### 10.1 命名规范
- **文件名**: PascalCase (如 `VaultService.ets`)
- **类名**: PascalCase (如 `VaultService`)
- **接口名**: PascalCase (如 `VaultEntry`)
- **枚举名**: PascalCase (如 `OtpType`)
- **变量/函数名**: camelCase (如 `vaultService`)
- **常量**: UPPER_SNAKE_CASE (如 `VAULT_FILENAME`)

### 10.2 代码组织
- 使用单例模式管理服务类
- 使用 `@State` 装饰器管理 UI 状态
- 使用 `@Builder` 装饰器创建可复用 UI 组件
- 异步操作使用 `async/await`

### 10.3 错误处理
- 使用 try-catch 捕获异常
- 使用 `promptAction.showToast` 显示用户友好的错误信息
- 关键操作失败时提供降级方案

---

## 11. 版本信息

| 组件 | 版本 |
|------|------|
| 密钥库格式版本 | 3 |
| 文件格式版本 | 1 |
| 目标 SDK | 6.0.2(22) |
| 兼容 SDK | 6.0.2(22) |
| API Level | 12 |

---

## 12. 参考资料

- [Aegis Authenticator GitHub](https://github.com/beemdevelopment/Aegis)
- [HarmonyOS NEXT 开发文档](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/)
- [RFC 4226 - HOTP](https://tools.ietf.org/html/rfc4226)
- [RFC 6238 - TOTP](https://tools.ietf.org/html/rfc6238)
