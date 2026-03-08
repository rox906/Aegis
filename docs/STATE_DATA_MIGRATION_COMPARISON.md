# 状态数据处理迁移分析报告

## 概述

本报告分析了Aegis Android版本中各种状态数据（Preferences、Vault、OTP模型等）在鸿蒙版本中的迁移情况，并识别潜在问题。

---

## 1. Preferences（偏好设置）迁移分析

### Android版本

**文件**: `app/src/main/java/com/beemdevelopment/aegis/Preferences.java`

- 使用 `SharedPreferences` 存储设置
- 包含约40+个偏好设置项
- 支持JSON序列化存储复杂数据（如UUID映射）
- 包含 `BackupResult` 内部类用于备份结果

### 鸿蒙版本

**文件**: `Aegis-hmos_fixcompile/Aegis-hmos/entry/src/main/ets/service/PreferencesService.ets`

- 使用 `@kit.ArkData.preferences` 存储
- 单例模式
- 所有方法都是异步的（`Promise`）

### 迁移对比

| 功能 | Android版本 | 鸿蒙版本 | 状态 |
|------|-------------|----------|------|
| 基本布尔设置 | `getBoolean()` | `async get...(): Promise<boolean>` | ✅ 正确迁移 |
| 基本数值设置 | `getInt()` | `async get...(): Promise<number>` | ✅ 正确迁移 |
| 基本字符串设置 | `getString()` | `async get...(): Promise<string>` | ✅ 正确迁移 |
| UUID映射存储 | JSON序列化 | 仅存储JSON字符串 | ⚠️ 部分迁移 |
| BackupResult类 | 内部类，完整实现 | ❌ 未实现 | 🔴 缺失 |
| `migratePreferences()` | 支持旧版本迁移 | ❌ 未实现 | 🔴 缺失 |

### 🔴 严重问题

#### 1.1 BackupResult类完全缺失

**Android版本** (第623-689行):

```java
public static class BackupResult {
    private final Date _time;
    private boolean _isBuiltIn;
    private final String _error;
    private final boolean _isPermissionError;

    public String toJson() { ... }
    public static BackupResult fromJson(String json) { ... }
    public String getElapsedSince(Context context) { ... }
}
```

**鸿蒙版本**: 完全没有对应的实现

**影响**:
- 无法记录备份结果
- 无法显示备份成功/失败状态
- 无法显示备份时间

#### 1.2 migratePreferences()方法缺失

**Android版本** (第71-83行):

```java
public void migratePreferences() {
    // Change copy on tap to copy behavior to new preference and delete the old key
    String prefCopyOnTapKey = "pref_copy_on_tap";
    if (_prefs.contains(prefCopyOnTapKey)) {
        boolean isCopyOnTapEnabled = _prefs.getBoolean(prefCopyOnTapKey, false);
        if (isCopyOnTapEnabled) {
            setCopyBehavior(CopyBehavior.SINGLETAP);
        }
        _prefs.edit().remove(prefCopyOnTapKey).apply();
    }
}
```

**鸿蒙版本**: 完全没有迁移逻辑

**影响**:
- 如果用户从旧版本升级，旧设置无法正确迁移
- `pref_copy_on_tap` 设置无法转换为新格式

#### 1.3 UUID映射存储处理不一致

**Android版本** (第298-358行):

```java
public Map<UUID, Long> getLastUsedTimestamps() {
    Map<UUID, Long> lastUsedTimestamps = new HashMap<>();
    String lastUsedTimestamp = _prefs.getString("pref_last_used_timestamps", "");
    try {
        JSONArray arr = new JSONArray(lastUsedTimestamp);
        for (int i = 0; i < arr.length(); i++) {
            JSONObject json = arr.getJSONObject(i);
            lastUsedTimestamps.put(UUID.fromString(json.getString("uuid")),
                                   json.getLong("timestamp"));
        }
    } catch (JSONException ignored) { }
    return lastUsedTimestamps;
}
```

**鸿蒙版本** (第461-472行):

```typescript
async getLastUsedTimestamps(): Promise<string> {
  const store = this.ensureInitialized();
  return (await store.get('pref_last_used_timestamps', '')) as string;
}
```

**问题**: 鸿蒙版本只返回原始JSON字符串，没有解析成Map结构

**影响**:
- 调用方需要自己解析JSON
- 类型不一致，容易出错

---

## 2. Vault数据模型迁移分析

### Android版本

**文件**: `app/src/main/java/com/beemdevelopment/aegis/vault/Vault.java`

- 使用 `UUIDMap<VaultEntry>` 存储条目
- 使用 `UUIDMap<VaultGroup>` 存储分组
- 支持 `EntryFilter` 用于过滤导出
- 包含旧分组迁移逻辑

### 鸿蒙版本

**文件**: `Aegis-hmos_fixcompile/Aegis-hmos/entry/src/main/ets/model/VaultModels.ets`

- 使用 `VaultEntry[]` 数组存储条目
- 使用 `VaultGroup[]` 数组存储分组
- TypeScript接口定义

### 迁移对比

| 功能 | Android版本 | 鸿蒙版本 | 状态 |
|------|-------------|----------|------|
| 条目存储 | `UUIDMap<VaultEntry>` | `VaultEntry[]` | ⚠️ 结构不同 |
| 分组存储 | `UUIDMap<VaultGroup>` | `VaultGroup[]` | ⚠️ 结构不同 |
| EntryFilter | 支持过滤导出 | ❌ 未实现 | 🔴 缺失 |
| 旧分组迁移 | `migrateOldGroup()` | ❌ 未实现 | 🔴 缺失 |
| iconsOptimized | 支持标志 | ✅ 支持 | ✅ 正确 |

### 🔴 严重问题

#### 2.1 UUIDMap结构缺失

**Android版本** 使用 `UUIDMap`（自定义数据结构）:

```java
private final UUIDMap<VaultEntry> _entries = new UUIDMap<>();
private final UUIDMap<VaultGroup> _groups = new UUIDMap<>();
```

**鸿蒙版本** 使用普通数组:

```typescript
entries: VaultEntry[];
groups: VaultGroup[];
```

**问题**:
- `UUIDMap` 提供UUID作为键的高效查找
- 鸿蒙版本使用数组，查找效率O(n) vs O(1)
- 缺少UUID唯一性保证

#### 2.2 EntryFilter缺失

**Android版本** (第148-150行):

```java
public interface EntryFilter {
    boolean includeEntry(VaultEntry entry);
}

public JSONObject toJson(@Nullable EntryFilter filter) {
    // ...
    for (VaultEntry e : _entries) {
        if (filter == null || filter.includeEntry(e)) {
            entriesArray.put(e.toJson());
        }
    }
}
```

**鸿蒙版本**: 没有过滤功能

**影响**:
- 无法在导出时过滤特定条目
- 可能导致导出敏感数据

#### 2.3 旧分组迁移逻辑缺失

**Android版本** (第118-138行):

```java
public boolean migrateOldGroup(VaultEntry entry) {
    if (entry.getOldGroup() != null) {
        Optional<VaultGroup> optGroup = getGroups().getValues()
            .stream()
            .filter(g -> g.getName().equals(entry.getOldGroup()))
            .findFirst();

        if (optGroup.isPresent()) {
            entry.addGroup(optGroup.get().getUUID());
        } else {
            VaultGroup group = new VaultGroup(entry.getOldGroup());
            getGroups().add(group);
            entry.addGroup(group.getUUID());
        }

        entry.setOldGroup(null);
        return true;
    }
    return false;
}
```

**鸿蒙版本**: 没有旧分组字段和迁移逻辑

**影响**:
- 旧版本vault文件中的 `group` 字段无法正确迁移
- 用户的分组设置可能丢失

---

## 3. VaultEntry数据模型迁移分析

### Android版本

**文件**: `app/src/main/java/com/beemdevelopment/aegis/vault/VaultEntry.java`

- 继承自 `UUIDMap.Value`
- 包含 `VaultEntryIcon` 对象
- 包含 `Set<UUID> _groups` 用于分组关联
- 包含 `String _oldGroup` 用于旧分组迁移
- 包含 `int _usageCount` 和 `long _lastUsedTimestamp`

### 鸿蒙版本

**文件**: `Aegis-hmos_fixcompile/Aegis-hmos/entry/src/main/ets/model/VaultModels.ets`

```typescript
export interface VaultEntry {
  uuid: string;
  name: string;
  issuer: string;
  info: AnyOtpInfo;
  icon: VaultEntryIcon | undefined;
  isFavorite: boolean;
  usageCount: number;
  lastUsedTimestamp: number;
  note: string;
  groups: Set<string>; // Set of group UUIDs
}
```

### 迁移对比

| 字段 | Android版本 | 鸿蒙版本 | 状态 |
|------|-------------|----------|------|
| uuid | `UUID` | `string` | ✅ 正确 |
| name | `String` | `string` | ✅ 正确 |
| issuer | `String` | `string` | ✅ 正确 |
| info | `OtpInfo` | `AnyOtpInfo` | ✅ 正确 |
| icon | `VaultEntryIcon` | `VaultEntryIcon \| undefined` | ✅ 正确 |
| isFavorite | `boolean` | `boolean` | ✅ 正确 |
| usageCount | `int` | `number` | ✅ 正确 |
| lastUsedTimestamp | `long` | `number` | ✅ 正确 |
| note | `String` | `string` | ✅ 正确 |
| groups | `Set<UUID>` | `Set<string>` | ✅ 正确 |
| oldGroup | `String` | ❌ 缺失 | 🔴 缺失 |

### 🔴 严重问题

#### 3.1 oldGroup字段缺失

**Android版本** (第28行):

```java
private String _oldGroup;
```

**鸿蒙版本**: 没有 `oldGroup` 字段

**影响**:
- 无法正确从旧版本vault文件迁移分组
- 旧分组设置会丢失

#### 3.2 VaultEntryIcon实现差异

**Android版本** (`VaultEntryIcon.java`):

```java
public class VaultEntryIcon implements Serializable {
    private final byte[] _bytes;
    private final byte[] _hash;  // SHA-256 hash
    private final IconType _type;

    // Hash计算: SHA-256(mimeType + bytes)
    private static byte[] generateHash(byte[] bytes, IconType type) {
        MessageDigest md = MessageDigest.getInstance("SHA-256");
        md.update(type.toMimeType().getBytes(StandardCharsets.UTF_8));
        return md.digest(bytes);
    }

    // equals() 使用hash比较
    @Override
    public boolean equals(Object o) {
        if (!(o instanceof VaultEntryIcon)) {
            return false;
        }
        VaultEntryIcon entry = (VaultEntryIcon) o;
        return Arrays.equals(getHash(), entry.getHash());
    }
}
```

**鸿蒙版本** (`VaultModels.ets`):

```typescript
export interface VaultEntryIcon {
  type: IconType;
  data: Uint8Array;
}
```

**问题**:
- 鸿蒙版本没有 `hash` 字段
- 没有hash计算逻辑
- equals()比较方式不同（Android用hash，鸿蒙可能用全量比较）

**影响**:
- 图标比较效率降低
- 无法检测重复图标

---

## 4. OTP数据模型迁移分析

### Android版本

**文件**: `app/src/main/java/com/beemdevelopment/aegis/otp/`

- `OtpInfo` - 抽象基类
- `TotpInfo` - TOTP实现
- `HotpInfo` - HOTP实现
- `SteamInfo` - Steam OTP实现
- `MotpInfo` - mOTP实现
- `YandexInfo` - Yandex OTP实现

### 鸿蒙版本

**文件**: `Aegis-hmos_fixcompile/Aegis-hmos/entry/src/main/ets/model/OtpModels.ets`

- 使用TypeScript接口和枚举
- `AnyOtpInfo` 联合类型

### 迁移对比

| 功能 | Android版本 | 鸿蒙版本 | 状态 |
|------|-------------|----------|------|
| OtpInfo基类 | 抽象类 | 接口 | ✅ 正确 |
| TOTP | `TotpInfo` | `TotpInfo` 接口 | ✅ 正确 |
| HOTP | `HotpInfo` | `HotpInfo` 接口 | ✅ 正确 |
| Steam | `SteamInfo` | `SteamInfo` 接口 | ✅ 正确 |
| mOTP | `MotpInfo` | `MotpInfo` 接口 | ✅ 正确 |
| Yandex | `YandexInfo` | `YandexInfo` 接口 | ✅ 正确 |
| 验证逻辑 | `isDigitsValid()`, `isAlgorithmValid()` | ❌ 缺失 | 🔴 缺失 |
| equals() | 完整实现 | ❌ 缺失 | 🔴 缺失 |

### 🔴 严重问题

#### 4.1 验证逻辑缺失

**Android版本** (`OtpInfo.java`):

```java
public static boolean isAlgorithmValid(String algorithm) {
    return algorithm.equals("SHA1") || algorithm.equals("SHA256") ||
           algorithm.equals("SHA512") || algorithm.equals("MD5");
}

public static boolean isDigitsValid(int digits) {
    // allow a max of 10 digits, as truncation will only extract 31 bits
    return digits > 0 && digits <= 10;
}

public static boolean isPeriodValid(int period) {
    if (period <= 0) {
        return false;
    }
    return period <= Integer.MAX_VALUE / 1000;
}

public void setDigits(int digits) throws OtpInfoException {
    if (!isDigitsValid(digits)) {
        throw new OtpInfoException(String.format("unsupported amount of digits: %d", digits));
    }
    _digits = digits;
}
```

**鸿蒙版本**: 没有验证逻辑

**影响**:
- 无效的OTP参数可能被接受
- 可能导致OTP生成错误

#### 4.2 equals()方法缺失

**Android版本** (`OtpInfo.java`, 第147-148行):

```java
@Override
public boolean equals(Object o) {
    if (this == o) {
        return true;
    }
    if (!(o instanceof OtpInfo)) {
        return false;
    }
    OtpInfo info = (OtpInfo) o;
    return getTypeId().equals(info.getTypeId())
            && Arrays.equals(getSecret(), info.getSecret())
            && getAlgorithm(false).equals(info.getAlgorithm(false))
            && getDigits() == info.getDigits();
}
```

**鸿蒙版本**: 没有自定义equals

**影响**:
- 对象比较可能不正确
- 无法正确检测重复条目

#### 4.3 Yandex OTP校验和验证缺失

**Android版本** (`YandexInfo.java`, 第110-162行):

```java
public static void validateSecret(byte[] secret) throws OtpInfoException {
    if (secret.length != SECRET_LENGTH && secret.length != SECRET_FULL_LENGTH) {
        throw new OtpInfoException(String.format("Invalid Yandex secret length: %d bytes", secret.length));
    }

    // Secrets originating from a QR code do not have a checksum, so we assume those are valid
    if (secret.length == SECRET_LENGTH) {
        return;
    }

    // Checksum validation logic...
    if (accum != originalChecksum) {
        throw new OtpInfoException("Yandex secret checksum invalid");
    }
}
```

**鸿蒙版本**: 没有校验和验证

**影响**:
- 损坏的Yandex secret可能被接受
- 可能导致错误的OTP生成

---

## 5. 编码工具迁移分析

### Base32编码

**Android版本** (`Base32.java`):

```java
public static String encode(byte[] data) {
    return BaseEncoding.base32().omitPadding().encode(data);
}
```

**鸿蒙版本** (`Encoding.ets`):

```typescript
static encode(data: Uint8Array): string {
    // ... 手动实现
    if (bits > 0) {
      result += BASE32_ALPHABET.charAt((value << (5 - bits)) & 0x1f);
    }
    return result;  // ❌ 没有省略padding
}
```

**问题**: 鸿蒙版本没有省略padding

### Base64编码

**Android版本**:

```java
public static String encode(byte[] data) {
    return BaseEncoding.base64().encode(data);
}
```

**鸿蒙版本**:

```typescript
static encode(data: Uint8Array): string {
    // ... 手动实现
    result += i + 2 < data.length ? BASE64_CHARS.charAt(c & 0x3f) : '=';
    result += i + 3 < data.length ? BASE64_CHARS.charAt(c & 0x3f) : '=';
}
```

**状态**: ✅ 正确实现

### Hex编码

**Android版本**:

```java
public static String encode(byte[] data) {
    return BaseEncoding.base16().lowerCase().encode(data);
}
```

**鸿蒙版本**:

```typescript
static encode(data: Uint8Array): string {
    let result = '';
    for (let i = 0; i < data.length; i++) {
      result += data[i].toString(16).padStart(2, '0');
    }
    return result;
}
```

**状态**: ✅ 正确实现

---

## 6. GoogleAuthInfo迁移分析

### Android版本

**文件**: `app/src/main/java/com/beemdevelopment/aegis/otp/GoogleAuthInfo.java`

- 支持 `otpauth://` URI解析
- 支持 `otpauth-migration://` 导出URI解析
- 包含 `Export` 内部类用于批量导出
- 支持 `GoogleAuthProtos` (protobuf)

### 鸿蒙版本

**文件**: `Aegis-hmos_fixcompile/Aegis-hmos/entry/src/main/ets/util/OtpUriParser.ets`

```typescript
export class OtpUriParser {
  static parse(uri: string): OtpInfo | null {
    // 基础实现
  }
}
```

### 迁移对比

| 功能 | Android版本 | 鸿蒙版本 | 状态 |
|------|-------------|----------|------|
| otpauth URI解析 | 完整实现 | 基础实现 | ⚠️ 部分实现 |
| otpauth-migration导出 | 完整支持 | ❌ 未实现 | 🔴 缺失 |
| GoogleAuthProtos | 支持 | ❌ 未实现 | 🔴 缺失 |
| 批量导出 | Export类 | ❌ 未实现 | 🔴 缺失 |

### 🔴 严重问题

#### 6.1 otpauth-migration完全缺失

**Android版本** (第171-272行):

```java
public static Export parseExportUri(String s) throws GoogleAuthInfoException {
    // 解析 otpauth-migration://offline?data=...
    GoogleAuthProtos.MigrationPayload payload;
    byte[] bytes = Base64.decode(data);
    payload = GoogleAuthProtos.MigrationPayload.parseFrom(bytes);

    List<GoogleAuthInfo> infos = new ArrayList<>();
    for (GoogleAuthProtos.MigrationPayload.OtpParameters params : payload.getOtpParametersList()) {
        // 处理每个OTP参数
    }
    return new Export(infos, payload.getBatchId(), payload.getBatchIndex(), payload.getBatchSize());
}
```

**鸿蒙版本**: 完全没有实现

**影响**:
- 无法从Google Authenticator批量导入
- 无法批量导出到Google Authenticator

#### 6.2 缺少参数验证

**Android版本** 包含详细的参数验证:

**鸿蒙版本**: 验证较少

---

## 7. 数据序列化/反序列化问题

### Android版本

- 使用 `JSONObject` 进行序列化
- 使用 `JSONException` 处理错误
- 支持可选字段 (`optString`, `optBoolean`)

### 鸿蒙版本

- 使用 `JSON.parse()` 和 `JSON.stringify()`
- 错误处理较简单

### 🔴 严重问题

#### 7.1 缺少可选字段处理

**Android版本**:

```java
entry.setNote(obj.optString("note", ""));
entry.setIsFavorite(obj.optBoolean("favorite", false));
```

**鸿蒙版本** (`VaultService.ets`):

```typescript
note: obj['note'] as string || '',
isFavorite: obj['favorite'] as boolean || false,
```

**问题**: 鸿蒙版本使用 `||` 运算符，对于 `false` 值可能有问题

**示例**:
- Android: `obj.optBoolean("favorite", false)` - 如果字段不存在，返回 `false`
- 鸿蒙: `obj['favorite'] as boolean || false` - 如果值为 `false`，会被 `||` 转换为默认值

---

## 问题总结

### 🔴 严重问题（必须修复）

| 问题 | 影响 | 建议修复 |
|------|------|----------|
| BackupResult类缺失 | 无法记录备份结果 | 实现BackupResult类和相关方法 |
| migratePreferences()缺失 | 旧设置无法迁移 | 实现偏好设置迁移逻辑 |
| UUIDMap结构缺失 | 查找效率低，无唯一性保证 | 使用Map或保持UUID作为键 |
| EntryFilter缺失 | 无法过滤导出 | 实现EntryFilter接口 |
| 旧分组迁移逻辑缺失 | 旧分组设置丢失 | 实现migrateOldGroup() |
| oldGroup字段缺失 | 旧分组无法迁移 | 添加oldGroup字段 |
| VaultEntryIcon hash缺失 | 图标比较效率低 | 添加hash字段和计算逻辑 |
| OTP验证逻辑缺失 | 无效参数可能被接受 | 实现验证方法 |
| equals()方法缺失 | 对象比较不正确 | 实现equals()方法 |
| Yandex校验和验证缺失 | 损坏secret可能被接受 | 实现校验和验证 |
| otpauth-migration缺失 | 无法批量导入/导出 | 实现GoogleAuthProtos支持 |
| 可选字段处理问题 | false值可能被错误处理 | 使用显式检查而非\|\| |

### 🟡 中等问题（建议修复）

| 问题 | 影响 | 建议修复 |
|------|------|----------|
| UUID映射存储不一致 | 调用方需自己解析 | 统一处理方式 |
| Base32编码padding | 与Android不完全一致 | 添加omitPadding选项 |
| OtpUriParser参数验证 | 验证较少 | 添加完整参数验证 |

### 🟢 低优先级问题

| 问题 | 影响 | 建议修复 |
|------|------|----------|
| 异步API风格 | 与Android同步风格不同 | 这是TypeScript特性，无需修改 |

---

## 建议的修复优先级

1. **高优先级** - 影响数据完整性和用户数据:
   - 实现BackupResult类
   - 实现migratePreferences()
   - 实现旧分组迁移逻辑
   - 修复可选字段处理问题

2. **中优先级** - 影响功能完整性:
   - 实现otpauth-migration支持
   - 实现OTP验证逻辑
   - 实现equals()方法

3. **低优先级** - 性能和代码质量:
   - 添加VaultEntryIcon hash
   - 优化UUID映射存储
