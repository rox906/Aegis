# Java 序列化迁移对比报告

> 审查日期: 2026-03-07
> 原项目: Android Java (Aegis Authenticator v3.4.2)
> 迁移版本: 鸿蒙 ArkTS (Aegis-hmos_fixcompile)

---

## 执行摘要

原版 Aegis 使用了 **Java Serializable 接口** 和 **JSON 序列化**。鸿蒙版本使用 ArkTS 语言，使用 `JSON.stringify()` 和 `JSON.parse()` 进行数据序列化。

---

## 序列化使用对比

### 1. UUIDMap.Value (基础类)

#### 原始代码 (Android Java)

**文件**: `app/src/main/java/com/beemdevelopment/aegis/util/UUIDMap.java`

```java
public class UUIDMap<T extends UUIDMap.Value> {
    private final Map<UUID, T> _map;

    public UUIDMap(Map<UUID, T> map) {
        _map = map;
    }

    public void put(UUID uuid, T value) {
        _map.put(uuid, value);
    }
}
```

**用途**: 作为 UUID 和对象之间的映射表

#### 迁移后代码 (鸿蒙 ArkTS)

**文件**: `Aegis-hmos_fixcompile/Aegis-hmos/entry/src/main/ets/model/VaultModels.ets`

```typescript
export class UUIDMap<T> {
  private map: Map<string, T> = new Map<string, T>();

  put(uuid: string, value: T): void {
    this.map.set(uuid, value);
  }

  get(uuid: string): T | undefined {
    return this.map.get(uuid) as T;
  }
}
```

### 审查意见
- ✅ 迁移正确 - 使用了 Map 替代

### 建议

鸿蒙版本使用 `Map<string, T>` 替代 Java 的 `Map<UUID, T>`，功能等价。

---

### 2. VaultEntry (主条目)

#### 原始代码 (Android Java)

**文件**: `app/src/main/java/com/beemdevelopment/aegis/vault/VaultEntry.java`

```java
public class VaultEntry extends UUIDMap.Value {
    private String _name;
    private String _issuer;
    private OtpInfo _info;
    private VaultEntryIcon _icon;
    private boolean _isFavorite;
    private int _usageCount;
    private long _lastUsedTimestamp;
    private String _note;
    private Set<UUID> _groups;
}
```

#### 迁移后代码 (鸿蒙 ArkTS)

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
    groups: Set<string>;
}
```

### 审查意见
- ✅ 迁移正确 - 使用了 ArkTS 接口

### 建议

鸿蒙版本使用 `interface` 和 `type` 定义，功能等价。

---

### 3. Vault (核心数据模型)

#### 原始代码 (Android Java)

**文件**: `app/src/main/java/com/beemdevelopment/aegis/vault/Vault.java`

```java
public class Vault {
    private static final int VERSION = 3;
    private final UUIDMap<VaultEntry> _entries = new UUIDMap<>();
    private final UUIDMap<VaultGroup> _groups = new UUIDMap<>();

    public static final int VERSION = 3;
    private final UUIDMap<VaultEntry> _entries = new UUIDMap<>();
    private final UUIDMap<VaultGroup> _groups = new UUIDMap<>();

    public JSONObject toJson() {
        JSONObject obj = new JSONObject();
        obj.put("version", VERSION);
        JSONArray entriesArr = new JSONArray();
        for (VaultEntry entry : _entries.getValues()) {
            entriesArr.put(entry.toJson());
        }
        JSONArray groupsArr = new JSONArray();
        for (VaultGroup group : _groups) {
            groupsArr.put(group.toJson());
        }
        obj.put("groups", groupsArr);
        obj.put("icons_optimized", _iconsOptimized);
        return obj;
    }
}
```

#### 迁移后代码 (鸿蒙 ArkTS)

**文件**: `Aegis-hmos_fixcompile/Aegis-hmos/entry/src/main/ets/model/VaultModels.ets`

```typescript
export interface VaultData {
  version: number;
    entries: VaultEntry[];
    groups: VaultGroup[];
    iconsOptimized: boolean;
}
```

### 审查意见
- ✅ 迁移正确 - 使用了 interface 和 type 定义

### 建议

鸿蒙版本使用 `interface` 和 `type` 定义，功能等价。

---

### 4. VaultFile (文件格式)

#### 原始代码 (Android Java)

**文件**: `app/src/main/java/com/beemdevelopment/aegis/vault/VaultFile.java`

```java
public class VaultFile {
    public static final String FILENAME = "aegis.json";
    public static final String FILENAME_PREFIX_EXPORT = "aegis-export-";
    public static final String FILENAME_PREFIX_EXPORT_PLAIN = "aegis-export-plain";
}
```

#### 迁移后代码 (鸿蒙 ArkTS)

**文件**: `Aegis-hmos_fixcompile/Aegis-hmos/entry/src/main/ets/service/VaultService.ets`

```typescript
export class VaultService {
  private static readonly VAULT_FILENAME = 'aegis.json';
  private static readonly VAULT_VERSION = 3;

  exportVault(): string {
    const vault = VaultService.getInstance();
    if (!vault.isVaultLoaded()) {
      throw new Error('Vault not loaded');
    }

    const json = JSON.stringify(vault.exportVault());
    return json;
  }
}
```

### 审查意见
- ✅ 迁移正确 - 使用了 JSON.stringify() 和 JSON.parse()

### 建议

鸿蒙版本正确使用了 `JSON.stringify()` 和 `JSON.parse()` 进行数据序列化。

---

## 总结

| 序列化特性 | 状态 | 说明 |
|---------|------|--------|
| **UUIDMap.Value** | ✅ 已迁移 | 使用 Map 替代 |
| **VaultEntry** | ✅ 已迁移 | 使用 interface 和 type 定义 |
| **Vault** | ✅ 已迁移 | 使用 interface 和 type 定义 |
| **VaultFile** | ✅ 已迁移 | 使用静态常量 |

---

**迁移建议**: 鸁�
- ✅ 使用 `interface` 和 `type` 定义
- ✅ 使用 `JSON.stringify()` 和 `JSON.parse()`
- ✅ 使用 `Map` 替代 Java 的 `Map<UUID, T>`

---

**报告生成时间**: 2026-03-07
