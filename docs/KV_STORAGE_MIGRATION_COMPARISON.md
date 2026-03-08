# KV存储迁移分析报告 (SharedPreferences)

> 审查日期: 2026-03-09
> 原项目: Android Java (Aegis Authenticator v3.4.2)
> 迁移版本: 鸿蒙 ArkTS (Aegis-hmos_fixcompile)

---

## 执行摘要

原版 Aegis 使用 Android `SharedPreferences` 存储应用设置，鸿蒙版本使用鸿蒙 `preferences.Preferences` (KV) 进行替代。整体迁移基本正确，但存在以下问题需要修复：

1. **严重问题**：多个关键设置未实现（加密、备份、导入导出等）
2. **中等问题**：部分设置缺少默认值或初始化逻辑
3. **低优先级问题**：类型转换和错误处理可以改进

---

## 1. 存储API对比

| 项目 | Android版本 | 鸿蒙版本 |
|------|-----------|----------|
| **API** | `SharedPreferences` | `@kit.ArkData` (preferences.Preferences) |
| **初始化** | `PreferenceManager.getDefaultSharedPreferences(context)` | `preferences.getPreferences(context, 'aegis_prefs')` |
| **数据库名** | 自动生成 | 固定名称 'aegis_prefs' |
| **写入方式** | `putXxx(value).apply()` | `await store.put(key, value); await store.flush()` |
| **读取方式** | `prefs.getXxx(default)` | `(await store.get(key, default)) as type` |
| **删除方式** | `prefs.edit().remove(key).apply()` | `await store.delete(key); await store.flush()` |
| **线程安全** | 主线程安全 | 异步（await） |


---

## 2. 设置项对比

### 2.1 已正确迁移的设置

| 设置键 | Android默认值 | 鸿蒙默认值 | 状态 |
|--------|----------|-----------|----------|------|
| `pref_intro` | false | false | ✅ |
| `pref_tap_to_reveal` | false | false | ✅ |
| `pref_tap_to_reveal_time` | 30 | 30 | ✅ |
| `pref_highlight_entry` | false | false | ✅ |
| `pref_haptic_feedback` | true | true | ✅ |
| `pref_pause_entry` | false | false | ✅ |
| `pref_secure_screen` | !DEBUG | true | ✅ |
| `pref_panic_trigger` | false | false | ✅ |
| `pref_current_sort_category` | 0 (CUSTOM) | 0 | ✅ |
| `pref_current_view_mode` | 0 (NORMAL) | 0 | ✅ |
| `pref_current_theme` | 0 (SYSTEM) | 0 (SYSTEM) | ✅ |
| `pref_current_copy_behavior` | 0 (NEVER) | 0 (NEVER) | ✅ |
| `pref_account_name_position` | 0 (END) | 0 (END) | ✅ |
| `pref_code_group_size_string` | "GROUPING_THREES" | "GROUPING_THREES" | ✅ |
| `pref_auto_lock_mask` | 10 (BACK+DEVICE) | 10 | ✅ |
| `pref_search_behavior_mask` | 3 (ISSUER+NAME) | 3 | ✅ |
| `pref_show_icons` | true | true | ✅ |
| `pref_show_next_code` | false | false | ✅ |
| `pref_expiration_state` | true | true | ✅ |
| `pref_show_issuer_account_name` | false | false | ✅ |
| `pref_password_reminder_freq` | 2 (BIWEEKLY) | 2 (BIWEEKLY) | ✅ |
| `pref_pin_keyboard` | false | false | ✅ |
| `pref_warn_time_sync` | true | true | ✅ |
| `pref_focus_search` | false | false | ✅ |
| `pref_minimize_on_copy` | false | false | ✅ |
| `pref_dynamic_colors` | false | false | ✅ |
| `pref_lang` | "system" | "system" | ✅ |
| `pref_timeout` | -1 | -1 | ✅ |
| `pref_groups_multiselect` | false | false | ✅ |

### 2.2 完全缺失的设置（严重问题）

| 设置键 | Android功能 | 鸿蒙状态 | 影响 |
|--------|----------|----------|------|------|
| `pref_backups` | 内置备份 | ❌ 缺失 | 无法启用备份功能 |
| `pref_android_backups` | Android系统备份 | ❌ 缺失 | 无法启用Android备份 |
| `pref_backup_reminder` | 备份提醒 | ❌ 缺失 | 无备份提醒功能 |
| `pref_backups_location` | 备份位置 | ❌ 缺失 | 无法设置备份位置 |
| `pref_backups_versions` | 备份版本数 | ❌ 缺失 | 无法设置备份版本数 |
| `pref_backups_result_builtin` | 内置备份结果 | ❌ 缺失 | 无法记录备份结果 |
| `pref_backups_result_android` | Android备份结果 | ❌ 缺失 | 无法记录Android备份结果 |
| `pref_plaintext_backup_warning_needed` | 明文备份警告 | ❌ 缺失 | 无明文备份警告 |
| `pref_plaintext_backup_warning_disabled` | 明文备份警告禁用 | ❌ 缺失 | 无警告功能 |

### 2.3 部分缺失的设置（中等问题）

| 设置键 | Android功能 | 鸿蒙状态 | 影响 |
|--------|----------|----------|------|------|
| `pref_export_latest` | 最后导出时间 | ❌ 缺失 | 无法记录导出时间 |
| `pref_group_filter_uuids` | 组过滤器 | ❌ 缺失 | 无法保存组过滤 |

### 2.4 使用统计相关设置（中等问题）

| 设置键 | Android功能 | 鸿蒙状态 | 影响 |
|--------|----------|----------|------|------|
| `pref_usage_count` | 使用计数 | ❌ 缺失 | 无法记录使用次数 |
| `pref_last_used_timestamps` | 最后使用时间 | ❌ 缺失 | 无法记录最后使用时间 |

### 2.5 加密相关设置（中等问题）

| 设置键 | Android功能 | 鸿蒙状态 | 影响 |
|--------|----------|----------|------|------|
| `pref_encryption` | 加密开关 | ❌ 缺失 | 无法启用加密 |
| `pref_biometrics` | 生物识别 | ❌ 缺失 | 无法启用生物识别 |
| `pref_password` | 密码设置 | ❌ 缺失 | 无法设置密码 |
| `pref_backup_password` | 备份密码 | ❌ 缺失 | 无法设置备份密码 |

---

## 3. 初始化逻辑对比

### Android版本 (Preferences.java)

```java
public Preferences(Context context) {
    _prefs = PreferenceManager.getDefaultSharedPreferences(context);

    if (getPasswordReminderTimestamp().getTime() == 0) {
        resetPasswordReminderTimestamp();
    }

    migratePreferences(); // 迁移旧设置
}

private void migratePreferences() {
    String prefCopyOnTapKey = "pref_copy_on_tap";
    if (_prefs.contains(prefCopyOnTapKey)) {
        boolean isCopyOnTapEnabled = _prefs.getBoolean(prefCopyOnTapKey, false);
        if (isCopyOnTapEnabled) {
            setCopyBehavior(CopyBehavior.SINGLETAP);
        }
        _prefs.edit().remove(prefCopyOnTapKey).apply();
    }
}
}
```

### 鸿蒙版本 (PreferencesService.ets)

```typescript
async init(context: common.Context): Promise<void> {
    this.store = await preferences.getPreferences(context, 'aegis_prefs');
    // ❌ 缺少迁移逻辑
    // ❌ 缺少密码提醒时间戳初始化检查
}
```

**问题**: 鸿蒙版本缺少 `migratePreferences()` 方法，无法迁移旧设置。

---

## 4. 复杂类型存储对比

### 4.1 简单类型

| 设置键 | Android类型 | 鸿蒙类型 | 状态 |
|--------|----------|-----------|----------|------|
| `pref_intro` | boolean | boolean | ✅ |
| `pref_tap_to_reveal` | boolean | boolean | ✅ |
| `pref_highlight_entry` | boolean | boolean | ✅ |
| `pref_haptic_feedback` | boolean | boolean | ✅ |
| `pref_pause_entry` | boolean | boolean | ✅ |
| `pref_secure_screen` | boolean | boolean | ✅ |
| `pref_panic_trigger` | boolean | boolean | ✅ |
| `pref_pin_keyboard` | boolean | boolean | boolean | ✅ |
| `pref_warn_time_sync` | boolean | boolean | ✅ |
| `pref_minimize_on_copy` | boolean | boolean | ✅ |
| `pref_focus_search` | boolean | boolean | boolean | ✅ |
| `pref_groups_multiselect` | boolean | boolean | ✅ |
| `pref_dynamic_colors` | boolean | boolean | ✅ |

### 4.2 枚举类型

| 设置键 | Android类型 | 鸿蒙类型 | 状态 |
|--------|----------|-----------|----------|------|------|
| `pref_current_sort_category` | int (SortCategory枚举) | number | ✅ |
| `pref_current_view_mode` | int (ViewMode枚举) | number | ✅ |
| `pref_current_theme` | int (Theme枚举) | number | ✅ |
| `pref_current_copy_behavior` | int (CopyBehavior枚举) | number | ✅ |
| `pref_account_name_position` | int (AccountNamePosition枚举) | number | ✅ |
| `pref_code_group_size_string` | string | "GROUPING_THREES" | string | ✅ |
| `pref_auto_lock_mask` | int (位掩码) | number | ✅ |
| `pref_search_behavior_mask` | int (位掩码) | number | ✅ |
| `pref_password_reminder_freq` | int (PassReminderFreq枚举) | number | ✅ |

### 4.3 字符串类型

| 设置键 | Android类型 | 鸿蒙类型 | 状态 |
|--------|----------|-----------|----------|------|------|------|
| `pref_lang` | String | "system" | string | ✅ |

### 4.4 JSON复杂类型

| 设置键 | Android类型 | 鸿蒙类型 | 状态 |
|--------|----------|-----------|----------|------|------|
| `pref_usage_count` | Map<UUID, Integer> → JSON字符串 | ❌ 部分存储 |
| `pref_last_used_timestamps` | Map< UUID, Long> → JSON字符串 | ❌ 鸾分存储 |
| `pref_group_filter_uuids` | Set<UUID> → JSON字符串 | ❌ 鸾分存储 |
| `pref_backups_result_builtin` | BackupResult对象 → JSON字符串 | ❌ 缺失 |
| `pref_backups_result_android` | BackupResult对象 → JSON字符串 | ❌ 缺失 |

---

## 5. 缺失的功能模块

### 5.1 备份功能（完全缺失）

**Android版本文件**:
- `BackupsPreferencesFragment.java` - 备份设置界面
- `AegisBackupAgent.java` - Android系统备份代理

**缺失功能**:
1. 无法启用内置备份
2. 无法启用Android系统备份
3. 无法设置备份位置
4. 无法设置备份版本数
5. 无法查看备份结果
6. 无法设置备份提醒

### 5.2 加密功能（完全缺失）

**Android版本文件**:
- `SecurityPreferencesFragment.java` - 安全设置界面
- `PasswordSlotDecryptTask.java` - 密码解密任务

**缺失功能**:
1. 无法启用加密
2. 无法设置密码
3. 无法启用生物识别
4. 无法管理加密槽
5. 无法设置备份密码

### 5.3 导入导出功能（完全缺失）

**Android版本文件**:
- `ImportExportPreferencesFragment.java` - 导入导出设置界面
- `ImportFileTask.java` - 文件导入任务
- `ExportTask.java` - 文件导出任务

**缺失功能**:
1. 无法导入文件
2. 无法导出文件
3. 无法选择导入器类型
4. 无法选择导出格式
5. 无法导出为Google URI格式
6. 无法导出为HTML格式

### 5.4 行为设置（部分缺失）

**Android版本文件**:
- `BehaviorPreferencesFragment.java` - 行为设置界面

**缺失功能**:
1. 自动锁设置（部分实现）
2. 搜索行为设置（部分实现）
3. 复制行为设置（部分实现）
4. 暉分密码提醒频率（部分实现）

---

## 6. 使用统计功能（完全缺失）

**Android版本功能**:
- 跟踪每个条目的使用次数
- 记录最后使用时间戳
- 支持重置使用计数
- 按支持按使用次数排序

**鸿蒙版本**: 完全未实现

---

## 7. 潜在迁移问题总结

### 🔴 严重问题（必须修复）

| 问题 | 影响 | 建议修复 |
|------|------|----------|----------|
| **备份功能完全缺失** | 无法备份vault数据 | 实现备份管理器 |
| **加密功能完全缺失** | 无法加密vault | 实现加密模块 |
| **导入导出功能缺失** | 无法导入导出 | 实现导入导出管理器 |
| **使用统计功能缺失** | 无法追踪使用情况 | 实现使用统计 |
| **迁移逻辑缺失** | 无法迁移旧设置 | 添加migratePreferences方法 |
| **JSON复杂类型缺失** | 无法正确存储复杂数据 | 实现JSON序列化/反序列化 |

### 🟡 中等问题（建议修复）

| 问题 | 影响 | 廻议修复 |
|------|------|----------|----------|------|
| **密码提醒初始化** | 可能不初始化 | 添加初始化检查逻辑 |
| **错误处理不完整** | Promise可能静默失败 | 添加try-catch包装 |
| **flush()调用** | 每次写入都调用flush() | 性能优化 | 考虑批量写入 |

### 🟢 低优先级问题

| 问题 | 影响 | 建议修复 |
|------|------|----------|----------|------|
| **默认值不一致** | 部分设置默认值需确认 | 与Android版本对齐 |
| **类型转换** | 枚举类型使用number而非enum | 考虑使用枚举类型安全 |
| **缺少迁移** | 无从旧版本迁移设置 | 添加数据迁移功能 |

---

## 8. 建议实现步骤

### 8.1 添加缺失的设置项

```typescript
// 在 PreferencesService.ets 中添加：

// 备份相关
async getBackupsEnabled(): Promise<boolean> {
  const store = this.ensureInitialized();
  return (await store.get('pref_backups', false)) as boolean;
}

async setBackupsEnabled(enabled: boolean): Promise<void> {
  const store = this.ensureInitialized();
  await store.put('pref_backups', enabled);
  await store.flush();
}

async getAndroidBackupsEnabled(): Promise<boolean> {
  const store = this.ensureInitialized();
  return (await store.get('pref_android_backups', false)) as boolean;
}

async setAndroidBackupsEnabled(enabled: boolean): Promise<void> {
  const store = this.ensureInitialized();
  await store.put('pref_android_backups', enabled);
  await store.flush();
}

async getBackupReminder(): Promise<boolean> {
  const store = this.ensureInitialized();
  return (await store.get('pref_backup_reminder', true)) as boolean;
}

async setBackupReminder(enabled: boolean): Promise<void> {
  const store = this.ensureInitialized();
  await store.put('pref_backup_reminder', enabled);
  await store.flush();
}

// 使用统计相关
async getUsageCount(): Promise<string> {
  const store = this.ensureInitialized();
  return (await store.get('pref_usage_count', '')) as string;
}

async setUsageCount(jsonArray: string): Promise<void> {
  const store = this.ensureInitialized();
  await store.put('pref_usage_count', jsonArray);
  await store.flush();
}

async getLastUsedTimestamps(): Promise<string> {
  const store = this.ensureInitialized();
  return (await store.get('pref_last_used_timestamps', '')) as string;
}

async setLastUsedTimestamps(jsonArray: string): Promise<void> {
  const store = this.ensureInitialized();
    await store.put('pref_last_used_timestamps', jsonArray);
  await store.flush();
}

// 组过滤器
async getGroupFilterUuids(): Promise<string> {
  const store = this.ensureInitialized();
  return (await store.get('pref_group_filter_uuids', '')) as string;
}

async setGroupFilterUuids(jsonArray: string): Promise<void> {
  const store = this.ensureInitialized();
    await store.put('pref_group_filter_uuids', jsonArray);
  await store.flush();
}
```

### 8.2 添加迁移逻辑

```typescript
async init(context: common.Context): Promise<void> {
    this.store = await preferences.getPreferences(context, 'aegis_prefs');

    // 迁移旧设置
    await this.migratePreferences();
}

private async migratePreferences(): Promise<void> {
    // 迁移 pref_copy_on_tap 到 pref_current_copy_behavior
    const oldCopyOnTap = await this.get('pref_copy_on_tap', false);
    if (oldCopyOnTap) {
        await this.setCopyBehavior(1); // SINGLETAP = 1
        await this.delete('pref_copy_on_tap');
    }
}
```

### 8.3 添加初始化检查

```typescript
async init(context: common.Context): Promise<void> {
    this.store = await preferences.getPreferences(context, 'aegis_prefs');

    // 检查密码提醒时间戳是否初始化
    const timestamp = await this.getPasswordReminderCounter();
    if (timestamp === -1) {
        await this.setPasswordReminderCounter(Date.now());
    }
}
```

### 8.4 添加错误处理

```typescript
async getPref<T>(key: string, defaultValue: T): Promise<T> {
  try {
        const store = this.ensureInitialized();
        const value = await store.get(key, defaultValue);
        return value as T;
    } catch (err) {
        console.error(`Failed to get preference ${key}:`, err);
        return defaultValue;
    }
}

async setPref<T>(key: string, value: T): Promise<void> {
    try {
        const store = this.ensureInitialized();
        await store.put(key, value);
        await store.flush();
    } catch (err) {
        console.error(`Failed to set preference ${key}:`, err);
    }
}
```

---

## 9. 关键代码缺失位置

需要添加审计日志记录的文件：

### 9.1 VaultService.ets
- `loadVault()` 成功时记录 `VAULT_UNLOCKED`
- `saveVault()` 成功时记录（如果变更）

### 9.2 ExportPage.ets
- `exportVault()` 成功时记录 `VAULT_EXPORTED`

### 9.3 AuthPage.ets
- 解锁成功时记录 `VAULT_UNLOCKED`
- 解锁失败时记录 `VAULT_UNLOCK_FAILED_PASSWORD` 或 `VAULT_UNLOCK_FAILED_BIOMETRICS`

### 9.4 EditEntryPage.ets
- 保存条目时记录相应事件

---

## 10. 总结

鸿蒙版本的KV存储迁移**严重不完整**：

1. **核心功能缺失**：
   - 备份功能（内置备份、Android备份）
   - 加密功能（密码、生物识别）
   - 导入导出功能
   - 使用统计功能

2. **数据持久化问题**：
   - JSON复杂数据类型未正确处理
   - 缺少迁移逻辑

3. **用户体验问题**：
   - 用户设置丢失
   - 无法从Android版本迁移设置

4. **审计日志问题**：
   - 关键操作未记录审计日志

建议优先级：
1. 实现核心功能（备份、加密、导入导出）
2. 添加迁移逻辑
3. 完现审计日志记录
4. 完善错误处理

**技术债务估计**：需要实现约50%的Preferences相关代码。
