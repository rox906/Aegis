# Aegis 完整 Java 序列化迁移对比报告

> 审查日期: 2026-03-07
> 原项目: Android Java (Aegis Authenticator v3.4.2)
> 迁移版本: 鸿蒙 ArkTS (Aegis-hmos_fixcompile)

---

## 执行摘要

原版 Aegis 使用了两种主要序列化机制：
1. **Java Serializable 接口** - 用于内存中对象的深拷贝和临时状态保持
2. **JSON 序列化 (toJson/fromJson)** - 用于持久化存储和数据交换

鸿蒙版本使用 ArkTS 语言，使用 `JSON.stringify()` 和 `JSON.parse()` 进行所有数据序列化，不再使用 Java 的 Serializable 机制。

---

## 1. Java Serializable 实现类对比

### 1.1 UUIDMap 和 UUIDMap.Value

| 特性 | Android Java | 鸿蒙 ArkTS |
|------|--------------|------------|
| **类定义** | `UUIDMap<T extends UUIDMap.Value> implements Iterable<T>, Serializable` | `interface VaultData` + 数组操作 |
| **用途** | 维护 UUID 到对象的映射，保持插入顺序 | 使用普通数组和 Map 替代 |
| **序列化** | Java Serializable | 不支持，使用 JSON 序列化替代 |

**Android 代码** (`app/src/main/java/com/beemdevelopment/aegis/util/UUIDMap.java`):
```java
public class UUIDMap<T extends UUIDMap.Value> implements Iterable<T>, Serializable {
    private LinkedHashMap<UUID, T> _map = new LinkedHashMap<>();

    public static abstract class Value implements Serializable {
        private UUID _uuid;
        protected Value() {
            this(UUID.randomUUID());
        }
        @NonNull
        public final UUID getUUID() {
            return _uuid;
        }
    }
}
```

**鸿蒙代码** (`Aegis-hmos_fixcompile/Aegis-hmos/entry/src/main/ets/model/VaultModels.ets`):
```typescript
export interface VaultData {
  version: number;
  entries: VaultEntry[];
  groups: VaultGroup[];
  iconsOptimized: boolean;
}
```

**审查意见**: ⚠️ 部分迁移
- UUIDMap 的链表顺序特性未完全在鸿蒙版本中实现
- 鸿蒙版本使用数组操作来维护顺序

---

### 1.2 VaultEntry

| 特性 | Android Java | 鸿蒙 ArkTS |
|------|--------------|------------|
| **继承** | extends `UUIDMap.Value` | `interface`，无继承 |
| **序列化** | Serializable + JSON (toJson/fromJson) | 仅 JSON |

**Android 代码** (`app/src/main/java/com/beemdevelopment/aegis/vault/VaultEntry.java`):
```java
public class VaultEntry extends UUIDMap.Value {
    private String _name = "";
    private String _issuer = "";
    private OtpInfo _info;
    private VaultEntryIcon _icon;
    private boolean _isFavorite;
    private int _usageCount;
    private long _lastUsedTimestamp;
    private String _note = "";
    private Set<UUID> _groups = new TreeSet<>();

    public JSONObject toJson() {
        JSONObject obj = new JSONObject();
        obj.put("type", _info.getTypeId());
        obj.put("uuid", getUUID().toString());
        obj.put("name", _name);
        obj.put("issuer", _issuer);
        obj.put("note", _note);
        obj.put("favorite", _isFavorite);
        VaultEntryIcon.toJson(_icon, obj);
        obj.put("info", _info.toJson());
        // ... groups serialization
        return obj;
    }
}
```

**鸿蒙代码** (`Aegis-hmos_fixcompile/Aegis-hmos/entry/src/main/ets/model/VaultModels.ets`):
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
  groups: Set<string>;
}
```

**审查意见**: ✅ 迁移正确
- 字段映射完整
- JSON 序列化格式兼容

---

### 1.3 VaultGroup

| 特性 | Android Java | 鸿蒙 ArkTS |
|------|--------------|------------|
| **继承** | extends `UUIDMap.Value` | `interface`，无继承 |
| **序列化** | Serializable + JSON | 仅 JSON |

**Android 代码**:
```java
public class VaultGroup extends UUIDMap.Value {
    private String _name;
}
```

**鸿蒙代码**:
```typescript
export interface VaultGroup {
  uuid: string;
  name: string;
}
```

**审查意见**: ✅ 迁移正确

---

### 1.4 OtpInfo 及其子类

| 特性 | Android Java | 鸿蒙 ArkTS |
|------|--------------|------------|
| **类型** | 抽象类 + 子类 | 联合类型 (Union Types) |
| **序列化** | Serializable + toJson/fromJson | 仅对象字面量 |

**Android 代码** (`app/src/main/java/com/beemdevelopment/aegis/otp/OtpInfo.java`):
```java
public abstract class OtpInfo implements Serializable {
    public static final int DEFAULT_DIGITS = 6;
    public static final String DEFAULT_ALGORITHM = "SHA1";
    private byte[] _secret;
    private String _algorithm;
    private int _digits;

    public JSONObject toJson() {
        JSONObject obj = new JSONObject();
        obj.put("secret", Base32.encode(getSecret()));
        obj.put("algo", getAlgorithm(false));
        obj.put("digits", getDigits());
        return obj;
    }

    public static OtpInfo fromJson(String type, JSONObject obj) throws OtpInfoException {
        // 根据 type 创建不同子类实例
        switch (type) {
            case TotpInfo.ID:
                info = new TotpInfo(secret, algo, digits, obj.getInt("period"));
                break;
            case HotpInfo.ID:
                info = new HotpInfo(secret, algo, digits, obj.getLong("counter"));
                break;
            // ... 其他类型
        }
    }
}
```

**鸿蒙代码** (`Aegis-hmos_fixcompile/Aegis-hmos/entry/src/main/ets/model/OtpModels.ets`):
```typescript
export interface OtpInfo {
  type: OtpType;
  secret: Uint8Array;
  algorithm: OtpAlgorithm;
  digits: number;
}

export interface TotpInfo extends OtpInfo {
  type: OtpType.TOTP;
  period: number;
}

export interface HotpInfo extends OtpInfo {
  type: OtpType.HOTP;
  counter: number;
}

export type AnyOtpInfo = TotpInfo | HotpInfo | SteamInfo | MotpInfo | YandexInfo;
```

**审查意见**: ✅ 迁移正确
- 使用 TypeScript 联合类型替代 Java 继承
- 类型安全等效

---

### 1.5 Slot 和 SlotList

| 特性 | Android Java | 鸿蒙 ArkTS |
|------|--------------|------------|
| **继承** | Slot extends `UUIDMap.Value` | `interface SlotData` |
| **子类** | RawSlot, PasswordSlot, BiometricSlot | 使用类型字段区分 |
| **序列化** | Serializable + toJson/fromJson | 仅 JSON |

**Android 代码** (`app/src/main/java/com/beemdevelopment/aegis/vault/slots/Slot.java`):
```java
public abstract class Slot extends UUIDMap.Value {
    public final static byte TYPE_RAW = 0x00;
    public final static byte TYPE_PASSWORD = 0x01;
    public final static byte TYPE_BIOMETRIC = 0x02;

    private byte[] _encryptedMasterKey;
    private CryptParameters _encryptedMasterKeyParams;

    public static Slot fromJson(JSONObject obj) throws SlotException {
        Slot slot;
        switch (obj.getInt("type")) {
            case Slot.TYPE_RAW:
                slot = new RawSlot(uuid, key, keyParams);
                break;
            case Slot.TYPE_PASSWORD:
                // ... PasswordSlot
                break;
            case Slot.TYPE_BIOMETRIC:
                slot = new BiometricSlot(uuid, key, keyParams);
                break;
        }
    }
}
```

**鸿蒙代码** (`Aegis-hmos_fixcompile/Aegis-hmos/entry/src/main/ets/model/VaultModels.ets`):
```typescript
export enum SlotType {
  RAW = 0,
  PASSWORD = 1,
  BIOMETRIC = 2
}

export interface SlotData {
  type: SlotType;
  uuid: string;
  key: Uint8Array;
  keyParams: CryptParams;
}

export interface PasswordSlotData extends SlotData {
  type: SlotType.PASSWORD;
  n: number;
  r: number;
  p: number;
  salt: Uint8Array;
  repaired: boolean;
  isBackup: boolean;
}
```

**审查意见**: ⚠️ 需要确认
- 鸿蒙版本未完整实现 Slot 的反序列化逻辑
- `VaultService.loadVault()` 中加密 vault 处理不完整（仅标记为 locked）

---

### 1.6 CryptParameters

| 特性 | Android Java | 鸿蒙 ArkTS |
|------|--------------|------------|
| **序列化** | Serializable + toJson/fromJson | 仅 interface |

**Android 代码**:
```java
public class CryptParameters implements Serializable {
    private byte[] _nonce;
    private byte[] _tag;

    public JSONObject toJson() {
        JSONObject obj = new JSONObject();
        obj.put("nonce", Hex.encode(_nonce));
        obj.put("tag", Hex.encode(_tag));
        return obj;
    }
}
```

**鸿蒙代码**:
```typescript
export interface CryptParams {
  nonce: Uint8Array;
  tag: Uint8Array;
}
```

**审查意见**: ✅ 迁移正确

---

### 1.7 SCryptParameters

| 特性 | Android Java | 鸿蒙 ArkTS |
|------|--------------|------------|
| **序列化** | Serializable | 仅 interface |

**Android 代码**:
```java
public class SCryptParameters implements Serializable {
    private int _n;
    private int _r;
    private int _p;
    private byte[] _salt;
}
```

**鸿蒙代码**:
```typescript
export interface SCryptParams {
  n: number;
  r: number;
  p: number;
  salt: Uint8Array;
}
```

**审查意见**: ✅ 迁移正确

---

### 1.8 MasterKey

| 特性 | Android Java | 鸿蒙 ArkTS |
|------|--------------|------------|
| **序列化** | Serializable (标记密钥对象) | ❌ 未实现 |

**Android 代码**:
```java
public class MasterKey implements Serializable {
    private SecretKey _key;

    public static MasterKey generate() {
        return new MasterKey(CryptoUtils.generateKey());
    }

    public CryptResult encrypt(byte[] bytes) throws MasterKeyException {
        // 使用 _key 加密
    }

    public CryptResult decrypt(byte[] bytes, CryptParameters params) throws MasterKeyException {
        // 使用 _key 解密
    }
}
```

**鸿蒙代码**: ❌ 未找到对应实现

**审查意见**: ❌ 缺失
- MasterKey 类在鸿蒙版本中未实现
- 加密/解密功能依赖于此，当前仅支持未加密 vault

---

### 1.9 VaultEntryIcon

| 特性 | Android Java | 鸿蒙 ArkTS |
|------|--------------|------------|
| **序列化** | Serializable + toJson/fromJson | 仅 interface |

**Android 代码**:
```java
public class VaultEntryIcon implements Serializable {
    private final byte[] _bytes;
    private final byte[] _hash;
    private final IconType _type;
    public static final int MAX_DIMENS = 512;

    static void toJson(@Nullable VaultEntryIcon icon, @NonNull JSONObject obj) throws JSONException {
        obj.put("icon", icon == null ? JSONObject.NULL : Base64.encode(icon.getBytes()));
        if (icon != null) {
            obj.put("icon_mime", icon.getType().toMimeType());
            obj.put("icon_hash", Hex.encode(icon.getHash()));
        }
    }

    @Nullable
    static VaultEntryIcon fromJson(@NonNull JSONObject obj) throws VaultEntryIconException {
        // 解析 Base64 和 MIME 类型
    }
}
```

**鸿蒙代码**:
```typescript
export interface VaultEntryIcon {
  type: IconType;
  data: Uint8Array;
}

export enum IconType {
  JPEG = 'jpeg',
  PNG = 'png',
  SVG = 'svg'
}
```

**审查意见**: ⚠️ 部分迁移
- 鸿蒙版本缺少 `icon_hash` 字段的序列化
- 缺少 `MAX_DIMENS` 尺寸限制检查

---

### 1.10 VaultFileCredentials

| 特性 | Android Java | 鸿蒙 ArkTS |
|------|--------------|------------|
| **序列化** | Serializable + Cloner.clone() | ❌ 未实现 |
| **用途** | 管理加密密钥和 slots | - |

**Android 代码**:
```java
public class VaultFileCredentials implements Serializable {
    private MasterKey _key;
    private SlotList _slots;

    public VaultFileCredentials() {
        _key = MasterKey.generate();
        _slots = new SlotList();
    }

    @NonNull
    @Override
    public VaultFileCredentials clone() {
        return Cloner.clone(this);
    }
}
```

**鸿蒙代码**: ❌ 未找到对应实现

**审查意见**: ❌ 缺失
- 加密 vault 的核心凭证管理缺失
- `Cloner.clone()` 使用 Java 序列化深拷贝，鸿蒙无等效实现

---

### 1.11 UI 模型类 (Serializable)

#### ImportEntry
**Android 代码**:
```java
public class ImportEntry implements Serializable {
    private final VaultEntry _entry;
    private transient Listener _listener;
    private boolean _isChecked = true;
}
```

**鸿蒙代码**: ❌ 未找到对应实现

#### AssignIconEntry
**Android 代码**:
```java
public class AssignIconEntry implements Serializable {
    private final VaultEntry _entry;
    private IconPack.Icon _newIcon;
    private transient AssignIconEntry.Listener _listener;
}
```

**鸿蒙代码**: ❌ 未找到对应实现

#### VaultGroupModel
**Android 代码**:
```java
public class VaultGroupModel implements Serializable {
    private final VaultGroup _group;
    private final GroupPlaceholderType _placeholderType;
    private final String _placeholderText;
}
```

**鸿蒙代码**: ❌ 未找到对应实现

**审查意见**: ⚠️ 功能缺失
- 这些 UI 模型类用于 Activity/Fragment 间传递数据
- 鸿蒙版本使用不同的页面导航机制，可能不需要这些类

---

### 1.12 IconPack.Icon

**Android 代码**:
```java
public static class Icon implements Serializable {
    private final String _relFilename;
    private final String _name;
    private final String _category;
    private final List<String> _issuers;
    private File _file;
}
```

**鸿蒙代码**: ❌ 未找到对应实现

**审查意见**: ❌ 缺失
- 图标包功能在鸿蒙版本中未实现

---

### 1.13 GoogleAuthInfo 和 GoogleAuthInfo.Export

**Android 代码**:
```java
public class GoogleAuthInfo implements Transferable, Serializable {
    private OtpInfo _info;
    private String _accountName;
    private String _issuer;
}

public static class Export implements Transferable, Serializable {
    private int _batchId;
    private int _batchIndex;
    private int _batchSize;
    private List<GoogleAuthInfo> _entries;
}
```

**鸿蒙代码**: 部分在 `OtpUriParser.ets` 中实现

**审查意见**: ⚠️ 部分迁移
- `OtpUriParser.ets` 实现了 URI 解析功能
- 但 Google Authenticator 批量导出协议 (otpauth-migration) 可能未完整实现

---

### 1.14 DatabaseImporter.Definition

**Android 代码**:
```java
public static class Definition implements Serializable {
    private final String _name;
    private final Class<? extends DatabaseImporter> _type;
    private final @StringRes int _help;
    private final boolean _supportsDirect;
}
```

**鸿蒙代码**: ❌ 未找到对应实现

**审查意见**: ❌ 缺失
- 导入器框架在鸿蒙版本中缺失
- 这是 P0 级别缺失功能

---

## 2. Java 对象流序列化 (Object Streams)

### 2.1 Cloner 工具类

**Android 代码** (`app/src/main/java/com/beemdevelopment/aegis/util/Cloner.java`):
```java
public class Cloner {
    public static <T extends Serializable> T clone(T obj) {
        try {
            ByteArrayOutputStream baos = new ByteArrayOutputStream();
            ObjectOutputStream oos = new ObjectOutputStream(baos);
            oos.writeObject(obj);

            ByteArrayInputStream bais = new ByteArrayInputStream(baos.toByteArray());
            ObjectInputStream ois = new ObjectInputStream(bais);
            return (T) ois.readObject();
        } catch (ClassNotFoundException | IOException e) {
            throw new RuntimeException(e);
        }
    }
}
```

**鸿蒙代码**: ❌ 未实现

**审查意见**: ✅ 无需迁移
- ArkTS 不支持 Java 对象流
- 鸿蒙版本使用对象解构 `{...obj}` 实现浅拷贝
- 对于深拷贝需求，需要手动实现或使用 JSON 序列化：`JSON.parse(JSON.stringify(obj))`

---

## 3. JSON 序列化对比

### 3.1 Vault 序列化

**Android 代码** (`app/src/main/java/com/beemdevelopment/aegis/vault/Vault.java`):
```java
public class Vault {
    private static final int VERSION = 3;
    private final UUIDMap<VaultEntry> _entries = new UUIDMap<>();
    private final UUIDMap<VaultGroup> _groups = new UUIDMap<>();

    public JSONObject toJson(@Nullable EntryFilter filter) {
        JSONArray entriesArray = new JSONArray();
        for (VaultEntry e : _entries) {
            if (filter == null || filter.includeEntry(e)) {
                entriesArray.put(e.toJson());
            }
        }
        JSONArray groupsArray = new JSONArray();
        for (VaultGroup group : _groups) {
            groupsArray.put(group.toJson());
        }
        JSONObject obj = new JSONObject();
        obj.put("version", VERSION);
        obj.put("entries", entriesArray);
        obj.put("groups", groupsArray);
        obj.put("icons_optimized", _iconsOptimized);
        return obj;
    }
}
```

**鸿蒙代码** (`VaultService.ets`):
```typescript
private serializeEntry(entry: VaultEntry): object {
    const infoObj: Record<string, Object> = {
      'secret': Base32.encode(entry.info.secret),
      'algo': entry.info.algorithm as string,
      'digits': entry.info.digits
    };
    // ... 类型特定字段

    const obj: Record<string, Object> = {
      'type': entry.info.type as string,
      'uuid': entry.uuid,
      'name': entry.name,
      'issuer': entry.issuer,
      'note': entry.note,
      'favorite': entry.isFavorite,
      'info': infoObj,
      'groups': groupsArr
    };
    return obj;
}
```

**审查意见**: ✅ 迁移正确
- JSON 格式与 Android 版本兼容

---

### 3.2 VaultFile 序列化

**Android 代码**:
```java
public class VaultFile {
    public static final byte VERSION = 1;
    private Object _content;
    private Header _header;

    public JSONObject toJson() {
        JSONObject obj = new JSONObject();
        obj.put("version", VERSION);
        obj.put("header", _header.toJson());
        obj.put("db", _content);
        return obj;
    }
}
```

**鸿蒙代码**:
```typescript
const fileObj: Record<string, Object> = {
  'version': VAULT_FILE_VERSION,
  'header': header,
  'db': db
};
const json = JSON.stringify(fileObj, null, 4);
```

**审查意见**: ⚠️ 部分迁移
- 未加密 vault 支持完整
- ❌ 加密 vault 解密逻辑缺失

---

## 4. SharedPreferences 序列化

### 4.1 复杂类型存储

**Android 代码** (Preferences.java):
```java
// 存储 Map<UUID, Integer> 为 JSON
public void setUsageCount(Map<UUID, Integer> usageCounts) {
    JSONArray usageCountJson = new JSONArray();
    for (Map.Entry<UUID, Integer> entry : usageCounts.entrySet()) {
        JSONObject entryJson = new JSONObject();
        entryJson.put("uuid", entry.getKey());
        entryJson.put("count", entry.getValue());
        usageCountJson.put(entryJson);
    }
    _prefs.edit().putString("pref_usage_count", usageCountJson.toString()).apply();
}

// BackupResult 对象序列化
public String toJson() {
    JSONObject obj = new JSONObject();
    obj.put("time", _time.getTime());
    obj.put("error", _error == null ? JSONObject.NULL : _error);
    obj.put("isPermissionError", _isPermissionError);
    return obj.toString();
}
```

**鸿蒙代码** (PreferencesService.ets):
```typescript
async getUsageCount(): Promise<string> {
    return (await store.get('pref_usage_count', '')) as string;
}

async setUsageCount(jsonArray: string): Promise<void> {
    await store.put('pref_usage_count', jsonArray);
    await store.flush();
}
```

**审查意见**: ✅ 迁移正确
- 鸿蒙版本将 JSON 序列化留给调用方处理
- 存储格式与 Android 兼容

---

## 5. 问题汇总

### 5.1 P0 级别问题 (严重)

| # | 问题 | 影响 | 建议 |
|---|------|------|------|
| 1 | **加密功能缺失** - MasterKey, VaultFileCredentials, Slot 解密未实现 | 无法打开加密 vault | 实现加密模块，使用鸿蒙 crypto API |
| 2 | **导入器框架缺失** - DatabaseImporter 及所有子类未实现 | 无法从其他应用导入 | 实现导入器框架 |

### 5.2 P1 级别问题 (重要)

| # | 问题 | 影响 | 建议 |
|---|------|------|------|
| 3 | **UUIDMap 链表顺序** - 鸿蒙使用数组，可能丢失顺序语义 | 条目排序可能不一致 | 在 VaultService 中实现 moveEntry 完整逻辑 |
| 4 | **VaultEntryIcon 哈希** - icon_hash 字段缺失 | 图标缓存可能失效 | 添加 icon_hash 计算和存储 |

### 5.3 P2 级别问题 (次要)

| # | 问题 | 影响 | 建议 |
|---|------|------|------|
| 5 | **图标包功能缺失** - IconPack 未实现 | 无法使用自定义图标包 | 实现图标包加载和缓存 |
| 6 | **Google Auth 批量导出** - Export 类未完整实现 | 无法导入 Google Auth 批量导出 | 完成 otpauth-migration 协议支持 |

---

## 6. 迁移正确性总结

| 序列化特性 | 状态 | 说明 |
|-----------|------|------|
| **UUIDMap** | ⚠️ 部分 | 功能替代，但链表顺序语义弱化 |
| **VaultEntry JSON** | ✅ 已迁移 | 格式兼容 |
| **VaultGroup JSON** | ✅ 已迁移 | 格式兼容 |
| **OtpInfo JSON** | ✅ 已迁移 | 使用联合类型替代继承 |
| **Slot/SlotList** | ⚠️ 部分 | 定义存在，解密未实现 |
| **CryptParameters** | ✅ 已迁移 | 格式兼容 |
| **SCryptParameters** | ✅ 已迁移 | 格式兼容 |
| **MasterKey** | ❌ 缺失 | 加密核心组件 |
| **VaultEntryIcon** | ⚠️ 部分 | 缺少哈希字段 |
| **VaultFileCredentials** | ❌ 缺失 | 加密凭证管理 |
| **VaultFile 加密** | ❌ 缺失 | 仅支持明文 vault |
| **Cloner** | ✅ 无需 | ArkTS 使用其他深拷贝方式 |
| **SharedPreferences 复杂类型** | ✅ 已迁移 | 格式兼容 |
| **UI Serializable 模型** | ⚠️ 部分 | 鸿蒙导航机制不同 |
| **DatabaseImporter** | ❌ 缺失 | 导入器框架 |
| **IconPack** | ❌ 缺失 | 图标包功能 |

---

## 7. 技术债务

1. **加密模块**: 这是最大的技术债务。当前鸿蒙版本仅支持未加密 vault，需要实现：
   - AES-GCM 加密/解密
   - SCrypt 密钥派生
   - Slot 管理（密码、生物识别）

2. **导入器框架**: 需要设计鸿蒙版的导入器架构

3. **深拷贝策略**: 当前鸿蒙代码中缺少深拷贝工具，需要时手动实现

---

**报告生成时间**: 2026-03-07
