# VaultEntry 反序列化对比报告

> 审查日期: 2026-03-08
> 原项目: Android Java (Aegis Authenticator v3.4.2)
> 迁移版本: 鸿蒙 ArkTS (Aegis-hmos_fixcompile)

---

## 执行摘要

对比 VaultEntry 及相关类的 `fromJson`（反序列化）实现，检查鸿蒙版本是否正确处理所有字段。

---

## 1. VaultEntry 反序列化对比

### 1.1 Android Java 实现

**文件**: `app/src/main/java/com/beemdevelopment/aegis/vault/VaultEntry.java:77-119`

```java
public static VaultEntry fromJson(JSONObject obj) throws VaultEntryException {
    try {
        // 1. UUID 处理
        UUID uuid;
        if (!obj.has("uuid")) {
            uuid = UUID.randomUUID();
        } else {
            uuid = UUID.fromString(obj.getString("uuid"));
        }

        // 2. OtpInfo 反序列化
        OtpInfo info = OtpInfo.fromJson(obj.getString("type"), obj.getJSONObject("info"));
        VaultEntry entry = new VaultEntry(uuid, info);

        // 3. 基本字段
        entry.setName(obj.getString("name"));
        entry.setIssuer(obj.getString("issuer"));
        entry.setNote(obj.optString("note", ""));
        entry.setIsFavorite(obj.optBoolean("favorite", false));

        // 4. Groups 处理
        if (obj.has("groups")) {
            JSONArray groups = obj.getJSONArray("groups");
            for (int i = 0; i < groups.length(); i++) {
                String groupUuid = groups.getString(i);
                entry.addGroup(UUID.fromString(groupUuid));
            }
        } else if (obj.has("group")) {
            // 向后兼容：旧版 group 字段
            entry.setOldGroup(JsonUtils.optString(obj, "group"));
        }

        // 5. Icon 反序列化（静默失败）
        try {
            VaultEntryIcon icon = VaultEntryIcon.fromJson(obj);
            entry.setIcon(icon);
        } catch (VaultEntryIconException ignored) {
        }

        return entry;
    } catch (OtpInfoException | JSONException e) {
        throw new VaultEntryException(e);
    }
}
```

### 1.2 鸿蒙 ArkTS 实现

**文件**: `Aegis-hmos_fixcompile/Aegis-hmos/entry/src/main/ets/service/VaultService.ets:193-288`

```typescript
private parseEntry(obj: Record<string, Object>): VaultEntry {
    const typeStr = obj['type'] as string;
    const infoObj = obj['info'] as Record<string, Object>;
    const secretStr = infoObj['secret'] as string;
    const secret = Base32.decode(secretStr);
    const algo = (infoObj['algo'] as string || 'SHA1') as OtpAlgorithm;
    const digits = infoObj['digits'] as number;

    // 1. OtpInfo 反序列化
    let info: AnyOtpInfo;
    switch (typeStr) {
        case 'totp': {
            const totpInfo: AnyOtpInfo = {
                type: OtpType.TOTP,
                secret: secret,
                algorithm: algo as OtpAlgorithm,
                digits: digits,
                period: infoObj['period'] as number
            };
            info = totpInfo;
            break;
        }
        case 'steam': {
            const steamInfo: AnyOtpInfo = {
                type: OtpType.STEAM,
                secret: secret,
                algorithm: algo as OtpAlgorithm,
                digits: digits,
                period: infoObj['period'] as number
            };
            info = steamInfo;
            break;
        }
        case 'hotp': {
            const hotpInfo: AnyOtpInfo = {
                type: OtpType.HOTP,
                secret: secret,
                algorithm: algo as OtpAlgorithm,
                digits: digits,
                counter: infoObj['counter'] as number
            };
            info = hotpInfo;
            break;
        }
        case 'motp': {
            const motpInfo: AnyOtpInfo = {
                type: OtpType.MOTP,
                secret: secret,
                algorithm: OtpAlgorithm.MD5,
                digits: digits,
                period: infoObj['period'] as number || 10,
                pin: infoObj['pin'] as string || ''
            };
            info = motpInfo;
            break;
        }
        case 'yandex': {
            const yandexInfo: AnyOtpInfo = {
                type: OtpType.YANDEX,
                secret: secret,
                algorithm: OtpAlgorithm.SHA256,
                digits: 8,
                period: 30,
                pin: infoObj['pin'] as string || ''
            };
            info = yandexInfo;
            break;
        }
        default:
            throw new Error(`Unsupported OTP type: ${typeStr}`);
    }

    // 2. Groups 处理
    const groupsSet = new Set<string>();
    const groupsArr = obj['groups'] as Array<string> | undefined;
    if (groupsArr !== undefined) {
        for (const g of groupsArr) {
            groupsSet.add(g);
        }
    }

    // 3. 构造 VaultEntry
    const entry: VaultEntry = {
        uuid: obj['uuid'] as string || generateUUID(),
        name: obj['name'] as string || '',
        issuer: obj['issuer'] as string || '',
        info: info,
        icon: this.parseIcon(obj),
        isFavorite: obj['favorite'] as boolean || false,
        usageCount: 0,                    // ⚠️ 硬编码为 0
        lastUsedTimestamp: 0,           // ⚠️ 硬编码为 0
        note: obj['note'] as string || '',
        groups: groupsSet
    };

    return entry;
}
```

### 1.3 字段对比表

| 字段 | Android fromJson | 鸿蒙 parseEntry | 状态 | 说明 |
|------|---------------|----------------|------|------|
| **uuid** | ✅ 读取或生成 | ✅ 读取或生成 | ✅ 正确 | |
| **type/info** | ✅ OtpInfo.fromJson | ✅ switch 分支 | ✅ 正确 | |
| **name** | ✅ getString | ✅ 读取或空 | ✅ 正确 | |
| **issuer** | ✅ getString | ✅ 读取或空 | ✅ 正确 | |
| **note** | ✅ optString("", "") | ✅ 读取或空 | ✅ 正确 | |
| **favorite** | ✅ optBoolean(false) | ✅ 读取或false | ✅ 正确 | |
| **groups** | ✅ JSONArray 遍历 | ✅ 数组遍历 | ✅ 正确 | |
| **oldGroup** | ✅ 向后兼容 | ❌ 缺失 | ⚠️ 旧版兼容缺失 |
| **icon** | ✅ 静默失败 | ✅ parseIcon | ✅ 正确 | |
| **usageCount** | ✅ 在 EntryAdapter 中读取 | ❌ 硬编码为 0 | ⚠️ 未从 JSON 读取 |
| **lastUsedTimestamp** | ✅ 在 EntryAdapter 中读取 | ❌ 硬编码为 0 | ⚠️ 未从 JSON 读取 |

---

## 2. VaultGroup 反序列化对比

### 2.1 Android Java 实现

**文件**: `app/src/main/java/com/beemdevelopment/aegis/vault/VaultGroup.java:36-45`

```java
public static VaultGroup fromJson(JSONObject obj) throws VaultEntryException {
    try {
        UUID uuid = UUID.fromString(obj.getString("uuid"));
        String groupName = obj.getString("name");
        return new VaultGroup(uuid, groupName);
    } catch (JSONException e) {
        throw new VaultEntryException(e);
    }
}
```

### 2.2 鸿蒙 ArkTS 实现

**文件**: `Aegis-hmos_fixcompile/Aegis-hmos/entry/src/main/ets/service/VaultService.ets:136-143`

```typescript
const groups: VaultGroup[] = [];
if (groupsArr !== undefined) {
    for (const g of groupsArr) {
        const group: VaultGroup = {
            uuid: g['uuid'] as string,
            name: g['name'] as string
        };
        groups.push(group);
    }
}
```

### 2.3 审查意见

| 字段 | Android fromJson | 鸿蒙 parseEntry | 状态 |
|------|---------------|----------------|------|
| **uuid** | ✅ UUID.fromString | ✅ 字符串 | ✅ 正确 |
| **name** | ✅ getString | ✅ 读取 | ✅ 正确 |

---

## 3. VaultEntryIcon 反序列化对比

### 3.1 Android Java 实现

**文件**: `app/src/main/java/com/beemdevelopment/aegis/vault/VaultEntryIcon.java:76-100`

```java
@Nullable
static VaultEntryIcon fromJson(@NonNull JSONObject obj) throws VaultEntryIconException {
    try {
        Object icon = obj.get("icon");
        if (icon == JSONObject.NULL) {
            return null;
        }

        String mime = JsonUtils.optString(obj, "icon_mime");
        IconType iconType = mime == null ? IconType.JPEG : IconType.fromMimeType(mime);
        if (iconType == IconType.INVALID) {
            throw new VaultEntryIconException(String.format("Bad icon MIME type: %s", mime));
        }

        byte[] iconBytes = Base64.decode((String) icon);
        String iconHashStr = JsonUtils.optString(obj, "icon_hash");
        if (iconHashStr != null) {
            byte[] iconHash = Hex.decode(iconHashStr);
            return new VaultEntryIcon(iconBytes, iconType, iconHash);
        }

        return new VaultEntryIcon(iconBytes, iconType);
    } catch (JSONException | EncodingException e) {
        throw new VaultEntryIconException(e);
    }
}
```

### 3.2 鸿蒙 ArkTS 实现

**文件**: `Aegis-hmos_fixcompile/Aegis-hmos/entry/src/main/ets/service/VaultService.ets:165-190`

```typescript
private parseIcon(obj: Record<string, Object>): VaultEntryIcon | undefined {
    const iconStr = obj['icon'] as string | undefined;
    if (iconStr === undefined || iconStr === null) {
        return undefined;
    }
    try {
        const iconData = Base64.decode(iconStr);
        if (iconData.length === 0) {
            return undefined;
        }
        // ⚠️ 从魔数字节检测类型，而非从 icon_mime 字段
        let iconType = IconType.JPEG;
        if (iconData.length > 3 && iconData[0] === 0x89 && iconData[1] === 0x50) {
            iconType = IconType.PNG;
        } else if (iconData.length > 4 && iconData[0] === 0x3C) {
            iconType = IconType.SVG;
        }
        const icon: VaultEntryIcon = {
            type: iconType,
            data: iconData
        };
        return icon;
    } catch (err) {
        return undefined;
    }
}
```

### 3.3 审查意见

| 字段 | Android fromJson | 鸿蒙 parseIcon | 状态 | 说明 |
|------|---------------|----------------|------|------|
| **icon** | ✅ Base64.decode | ✅ Base64.decode | ✅ 正确 | |
| **icon_mime** | ✅ 用于确定类型 | ❌ 未使用 | ⚠️ 改用魔数字检测 |
| **icon_hash** | ✅ 用于验证 | ❌ 未使用 | ⚠️ 缺失哈希验证 |
| **iconType** | ✅ fromMimeType | ✅ 魔数字检测 | ⚠️ 可能不准确 |

---

## 4. 问题汇总

### 4.1 P0 级别问题（严重）

| # | 问题 | 影响 | 建议 |
|---|------|------|------|
| 1 | **usageCount 未持久化** | 每次重启后归零 | 将 usageCount 存储到 vault JSON 或单独文件 |

### 4.2 P1 级别问题（重要）

| # | 问题 | 影响 | 建议 |
|---|------|------|------|
| 2. **lastUsedTimestamp 未持久化** | 重启后丢失时间信息 | 将 lastUsedTimestamp 存储到 vault JSON |
| 3. **oldGroup 向后兼容缺失** | 无法导入旧版 vault | 添加 oldGroup 字段处理逻辑 |

### 4.3 P2 级别问题（次要）

| # | 问题 | 影响 | 建议 |
|---|------|------|------|
| 4 | **icon_mime 未使用** | 依赖魔数字检测 | 考虑使用 icon_mime 字段 |
| 5 | **icon_hash 未使用** | 无法验证图标完整性 | 添加哈希验证逻辑 |

---

## 5. 迁移正确性总结

| 类 | fromJson | parseEntry | 状态 |
|----|---------|-----------|------|
| **VaultEntry** | ✅ 完整 | ⚠️ 部分缺失 | ⚠️ |
| **VaultGroup** | ✅ 完整 | ✅ 完整 | ✅ |
| **VaultEntryIcon** | ✅ 完整 | ⚠️ 简化 | ⚠️ |

---

**报告生成时间**: 2026-03-08
