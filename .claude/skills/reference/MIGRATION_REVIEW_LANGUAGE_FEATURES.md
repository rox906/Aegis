# Aegis 鸿蒙迁移审查报告 - Java 语言特性专项

> **审查日期**: 2026-03-06  
> **审查范围**: app/src/main/java 目录下的 Java 源码  
> **目标**: 识别与语言特性相关的迁移风险点（反射、序列化、闭包、Java 8+ 特性）

---

## 📋 执行摘要

| 类别 | 风险等级 | 文件数 | 关键问题 |
|------|---------|--------|----------|
| **反射** | 🔴 高 | 5 | 动态类创建、方法调用 |
| **依赖注入** | 🔴 高 | 8 | Hilt/Dagger 注解 |
| **Handler/Looper** | 🔴 高 | 11 | Android 线程消息机制 |
| **Room 数据库** | 🔴 高 | 2 | Room ORM 框架 |
| **Glide 图片加载** | 🔴 高 | 1 | Glide 库及注解 |
| **序列化** | 🟡 中 | 12 | Serializable 接口实现 |
| **Stream API** | 🟡 中 | 16 | Java 8 Stream 语法 |
| **SharedPreferences** | 🟡 中 | 3 | Android 偏好设置 |
| **Uri/FileProvider** | 🟡 中 | 29 | 文件 URI 和共享 |
| **ActivityResultLauncher** | 🟡 中 | 7 | Activity 结果 API |
| **MessageDigest** | 🟡 中 | 7 | 加密摘要算法 |
| **Comparator.comparing** | 🟡 中 | 3 | Java 8 Comparator |
| **@TargetApi/@RequiresApi** | 🟡 中 | 31 | Android 版本注解 |
| **Lambda/闭包** | 🟢 低 | 30+ | 语法兼容，需注意 this 捕获 |
| **方法引用** | 🟢 低 | 15 | 语法兼容 |
| **枚举** | 🟢 低 | 14 | 基本支持 |
| **泛型** | 🟢 低 | 132 | 基本支持 |
| **接口** | 🟢 低 | 37 | 基本支持 |
| **内部类** | 🟢 低 | 40 | 基本支持 |
| **UUID** | 🟢 低 | 9 | 基本支持 |
| **SecureRandom** | 🟢 低 | 5 | 基本支持 |
| **ByteBuffer** | 🟢 低 | 8 | 基本支持 |
| **Pattern/Matcher** | 🟢 低 | 5 | 基本支持 |
| **Cloneable** | 🟢 低 | 2 | 基本支持 |
| **WeakReference** | 🟢 低 | 4 | 基本支持 |
| **抽象类** | 🟢 低 | 14 | 基本支持 |

---

## 1. 反射相关代码（高风险）

### 1.1 动态类实例化

#### 📁 `DatabaseImporter.java:92`
```java
public static DatabaseImporter create(Context context, Class<? extends DatabaseImporter> type) {
    try {
        return type.getConstructor(Context.class).newInstance(context);
    } catch (IllegalAccessException | InstantiationException
            | NoSuchMethodException | InvocationTargetException e) {
        throw new RuntimeException(e);
    }
}
```
**问题**: 通过反射动态创建导入器实例  
**影响**: 鸿蒙 ArkTS 不支持运行时反射创建实例  
**建议**: 
- 改用工厂模式，使用 switch/when 替代反射
- 或维护一个 Class->Instance 的映射表

```java
// 建议的替代方案
public static DatabaseImporter create(Context context, Class<? extends DatabaseImporter> type) {
    if (type == AegisImporter.class) return new AegisImporter(context);
    if (type == GoogleAuthImporter.class) return new GoogleAuthImporter(context);
    // ... 其他导入器
    throw new IllegalArgumentException("Unknown importer type: " + type);
}
```

---

#### 📁 `IntroBaseActivity.java:212`
```java
// Fragment 创建
return type.newInstance();
```
**问题**: 使用反射创建 Fragment 实例  
**影响**: 鸿蒙需要显式创建  
**建议**: 使用 FragmentFactory 或显式创建

---

#### 📁 `PreferencesActivity.java:107`
```java
return fragmentType.newInstance();
```
**问题**: 同上，反射创建 Preference Fragment  
**建议**: 使用 Fragment 工厂模式

---

### 1.2 反射访问私有方法/字段

#### 📁 `AegisActivity.java:103-105`
```java
// 调用 Activity 的私有 finish 方法
Method method = Activity.class.getDeclaredMethod("finish", int.class);
method.setAccessible(true);
method.invoke(this, 2); // FINISH_TASK_WITH_ACTIVITY = 2
```
**问题**: 反射调用 Android 私有 API  
**影响**: 鸿蒙可能不存在此方法，且反射受限  
**建议**: 
- 检查鸿蒙是否有等效 API
- 若无，考虑替代方案（如使用 finishAndRemoveTask()）

---

#### 📁 `AegisActivity.java:193-196`
```java
// 访问 AppCompatDelegate 私有字段
_fadeAnimField = getDelegate().getClass().getDeclaredField("mFadeAnim");
_fadeAnimField.setAccessible(true);
_actionModeViewField = getDelegate().getClass().getDeclaredField("mActionModeView");
_actionModeViewField.setAccessible(true);
```
**问题**: 反射访问私有字段，用于修复 ActionMode 动画问题  
**影响**: 高度依赖 Android 内部实现，鸿蒙可能不适用  
**建议**: 
- 检查鸿蒙是否需要此 hack
- 考虑移除或使用鸿蒙提供的替代方案

---

#### 📁 `TrustedIntents.java:170-171`（第三方库）
```java
Constructor<? extends ApkSignaturePin> constructor = cls.getConstructor();
return pinList.add((ApkSignaturePin) constructor.newInstance((Object[]) null));
```
**问题**: Guardian Project 的受信任 Intent 库使用反射  
**影响**: 第三方库，可能需要替换  
**建议**: 
- 评估是否需要此功能（用于 Panic Trigger）
- 如需要，考虑重写或使用鸿蒙安全机制替代

---

## 2. 序列化相关代码（中风险）

### 2.1 Serializable 实现类列表

| 类 | 用途 | 迁移建议 |
|----|------|----------|
| `CryptParameters` | 加密参数传递 | 改用鸿蒙 Parcelable 或自定义序列化 |
| `SCryptParameters` | SCrypt 参数 | 同上 |
| `MasterKey` | 主密钥传递 | ⚠️ 敏感数据，考虑内存安全存储 |
| `OtpInfo` | OTP 配置 | 核心类，需要完整迁移 |
| `IconPack.Icon` | 图标定义 | 改为 JSON 序列化 |
| `DatabaseImporter.Definition` | 导入器定义 | Intent 传递时改用 Parcelable |
| `VaultEntryIcon` | 条目图标 | 改为 Base64 字符串传递 |
| `VaultFileCredentials` | 凭据传递 | ⚠️ 高度敏感，需特殊处理 |
| `UUIDMap.Value` | UUID 映射基类 | 抽象类，子类需要处理 |
| `AssignIconEntry` | UI 模型 | 改为 Parcelable |
| `VaultGroupModel` | UI 模型 | 改为 Parcelable |
| `ImportEntry` | UI 模型 | 改为 Parcelable |

### 2.2 JSON 序列化（需要检查）

大量使用自定义 `toJson()` / `fromJson()` 方法的类：

```
Vault.java          - Vault 整体序列化
VaultEntry.java     - 条目序列化
VaultGroup.java     - 分组序列化
VaultFile.java      - 文件格式序列化
Slot.java           - 密钥槽序列化
PasswordSlot.java   - 密码槽序列化
OtpInfo.java        - OTP 配置序列化
TotpInfo.java       - TOTP 序列化
HotpInfo.java       - HOTP 序列化
MotpInfo.java       - MOTP 序列化
YandexInfo.java     - Yandex 序列化
IconPack.java       - 图标包序列化
CryptParameters.java - 加密参数
```

**注意**: JSON 序列化逻辑本身与平台无关，但需要注意：
- `org.json` 包在鸿蒙可用，但建议使用鸿蒙原生 JSON API
- 检查 `JSONObject` 和 `JSONArray` 的使用兼容性

---

## 3. Lambda 表达式和闭包（低风险）

### 3.1 Lambda 使用统计

约 **30+ 个文件** 使用 Lambda 表达式，主要集中在：

- **点击监听器**: `setOnClickListener(v -> { ... })`
- **线程回调**: `runOnUiThread(() -> { ... })`
- **异步任务回调**: `task.execute(params, result -> { ... })`
- **集合遍历**: `list.forEach(item -> { ... })`

### 3.2 需要注意的闭包捕获

#### 📁 `MainActivity.java:254-256`
```java
actions.put(fabMenuLayout.findViewById(R.id.fab_menu_item_scan), this::startScanActivity);
actions.put(fabMenuLayout.findViewById(R.id.fab_menu_item_scan_image), this::startScanImageActivity);
actions.put(fabMenuLayout.findViewById(R.id.fab_menu_item_enter), this::startEditEntryActivity);
```
**问题**: 方法引用捕获 `this`  
**注意**: 鸿蒙 ArkTS 中需确保 `this` 绑定正确

#### 📁 `AuthActivity.java:267`
```java
_textPassword.postDelayed(popup::dismiss, 5000);
```
**问题**: 方法引用作为回调  
**建议**: 鸿蒙中改用显式 Runnable

---

## 4. Java 8 Stream API（中风险）

### 4.1 Stream 使用场景

约 **16 个文件** 使用 Stream API：

| 文件 | 使用场景 |
|------|----------|
| `DatabaseImporter.java:101` | `stream().filter().collect()` |
| `VaultRepository.java:212` | `stream().filter()` |
| `MainActivity.java` | 集合过滤和映射 |
| `AssignIconsActivity.java:97,191` | `sorted(Comparator.comparing())` |
| `SlotList.java:61` | `stream().filter()` |
| `ImportEntriesActivity.java:219` | `collect(Collectors.toMap())` |
| `IconPickerDialog.java:132` | `stream().map()` |
| `EntryAdapter.java` | 列表过滤 |

### 4.2 迁移建议

**选项 1**: 使用鸿蒙支持的 Java 8 子集（如果支持）  
**选项 2**: 改为传统 for-each 循环

```java
// 原始代码（Java 8 Stream）
List<String> names = importers.stream()
    .map(DatabaseImporter.Definition::getName)
    .collect(Collectors.toList());

// 建议替代（兼容写法）
List<String> names = new ArrayList<>();
for (Definition def : importers) {
    names.add(def.getName());
}
```

---

## 5. 方法引用（低风险）

### 5.1 方法引用统计

| 类型 | 示例 | 文件 |
|------|------|------|
| 静态方法引用 | `Date::compareTo` | Preferences.java |
| 实例方法引用 | `Definition::supportsDirect` | DatabaseImporter.java |
| 对象方法引用 | `this::startScanActivity` | MainActivity.java |
| 构造方法引用 | `VaultGroupModel::new` | ImportExportPreferencesFragment.java |

### 5.2 迁移建议

方法引用可替换为等效 Lambda：
```java
// 方法引用
.sort(Comparator.comparing(IconPack::getName))

// 等效 Lambda
.sort((a, b) -> a.getName().compareTo(b.getName()))
```

---

## 6. 依赖注入（高风险）

### 6.1 Hilt/Dagger 使用点

| 注解 | 使用位置 | 说明 |
|------|----------|------|
| `@HiltAndroidApp` | AegisApplication.java | 应用级注入 |
| `@AndroidEntryPoint` | 8 个 Activity/Fragment | 组件注入 |
| `@Inject` | 15+ 个字段 | 依赖注入 |
| `@Provides` | AegisModule.java | 依赖提供 |
| `@Singleton` | AegisModule.java | 单例管理 |

### 6.2 具体注入点

```java
// AegisActivity.java
@Inject VaultManager _vaultManager;
@Inject Preferences _prefs;
@Inject AuditLogRepository _auditLogRepository;

// VaultLockReceiver.java
@Inject VaultManager _vaultManager;

// PreferencesFragment 及其子类
@Inject IconPackManager _iconPackManager;
@Inject VaultManager _vaultManager;
```

### 6.3 迁移建议

**方案 1**: 使用鸿蒙提供的依赖注入框架（如果有）  
**方案 2**: 手动实现单例和服务定位器模式

```java
// 建议的手动实现
public class ServiceLocator {
    private static VaultManager vaultManager;
    private static Preferences preferences;
    
    public static VaultManager getVaultManager() {
        if (vaultManager == null) {
            vaultManager = new VaultManager(getContext(), getAuditLogRepository());
        }
        return vaultManager;
    }
    // ...
}
```

---

## 7. 其他 Java 特性

### 7.1 Optional 使用

```java
// Vault.java
Optional<VaultGroup> optGroup = getGroups().getValues()
    .stream()
    .filter(g -> g.getName().equals(entry.getOldGroup()))
    .findFirst();
```

**建议**: 鸿蒙可能不支持 Optional，改为显式 null 检查：
```java
VaultGroup foundGroup = null;
for (VaultGroup g : getGroups().getValues()) {
    if (g.getName().equals(entry.getOldGroup())) {
        foundGroup = g;
        break;
    }
}
```

### 7.2 枚举 (Enum) - 14 个文件

| 文件 | 枚举类 |
|------|--------|
| `ViewMode.java` | ViewMode (NORMAL, COMPACT, SMALL, TILE) |
| `Theme.java` | Theme (LIGHT, DARK, AMOLED) |
| `SortCategory.java` | SortCategory (多种排序方式) |
| `CopyBehavior.java` | CopyBehavior (MINIMIZE, NOTIFICATION, NONE) |
| `PassReminderFreq.java` | PassReminderFreq (频率枚举) |
| `EventType.java` | EventType (审计日志事件类型) |
| `IconType.java` | IconType (图标类型) |
| `GroupPlaceholderType.java` | GroupPlaceholderType |
| `BackupsVersioningStrategy.java` | 备份版本策略 |
| `AccountNamePosition.java` | 账户名位置 |

**风险**: 低。鸿蒙支持枚举，但需注意：
- 枚举的 `values()` 方法在鸿蒙中可能表现不同
- 枚举作为序列化对象时需特殊处理

### 7.3 泛型 (Generics) - 132 个文件

大量使用泛型，主要场景：

```java
// UUIDMap.java - 泛型映射类
public class UUIDMap<T extends UUIDMap.Value> {
    private final Map<UUID, T> _map;
}

// 集合泛型
List<VaultEntry> entries;
Map<String, String> params;
Set<UUID> groups;

// 通配符泛型
Class<? extends DatabaseImporter>
List<? extends VaultEntry>
```

**风险**: 低。鸿蒙支持泛型，但需注意：
- 通配符 `? extends` 和 `? super` 的兼容性
- 类型擦除相关的问题

### 7.4 接口 (Interface) - 37 个文件

关键接口：

| 接口 | 用途 |
|------|------|
| `UiRefresher.Listener` | UI 刷新回调 |
| `IntroActivityInterface` | 引导页接口 |
| `Transferable` | 条目传输接口 |
| `ItemTouchHelperAdapter` | 拖拽适配器接口 |
| `SimpleTextWatcher` | 文本监听器接口 |
| `SimpleAnimationEndListener` | 动画结束监听器 |
| `AuditLogDao` | Room DAO 接口 |

**风险**: 低。鸿蒙支持接口。

### 7.5 内部类 (Inner Classes) - 40 个文件

```java
// 匿名内部类示例
_handler.postDelayed(new Runnable() {
    @Override
    public void run() {
        _listener.onRefresh();
    }
}, delay);

// 静态内部类
public static class Definition {
    // ...
}
```

**风险**: 低。鸿蒙支持内部类，但需注意：
- 匿名内部类对外部变量的捕获
- 静态内部类与非静态内部类的区别

### 7.6 Handler/Looper (线程消息机制) - 11 个文件

| 文件 | 用途 |
|------|------|
| `UiRefresher.java` | UI 定时刷新 |
| `EntryListView.java` | 条目列表刷新 |
| `AuditLogHolder.java` | 审计日志视图 |
| `VibrationHelper.java` | 震动控制 |
| `AegisBackupAgent.java` | 备份代理 |

```java
// UiRefresher.java
private Handler _handler;
_handler = new Handler();
_handler.postDelayed(runnable, delay);
_handler.removeCallbacksAndMessages(null);
```

**风险**: 高。🔴
- Android Handler 依赖 Looper，鸿蒙可能需要使用 `postTask` 或 `setTimeout`
- 需要替换为鸿蒙的异步任务机制

**建议**:
```java
// 鸿蒙 ArkTS 替代方案
import taskpool from '@ohos.taskpool';

private timer: number = -1;

start() {
    this.timer = setTimeout(() => {
        this.listener.onRefresh();
        this.timer = setTimeout(() => {}, this.listener.getMillisTillNextRefresh());
    }, this.listener.getMillisTillNextRefresh());
}

stop() {
    if (this.timer !== -1) {
        clearTimeout(this.timer);
    }
}
```

### 7.7 SharedPreferences - 3 个文件

| 文件 | 用途 |
|------|------|
| `VaultRepository.java` | Vault 偏好设置 |
| `AuthActivity.java` | 认证设置 |
| `Preferences.java` | 应用偏好 |

```java
SharedPreferences prefs = PreferenceManager.getDefaultSharedPreferences(context);
Editor editor = prefs.edit();
editor.putString("key", "value");
editor.apply();
```

**风险**: 中。🟡
- Android SharedPreferences 需要替换为鸿蒙 `preferences` 模块

**建议**:
```typescript
// 鸿蒙替代方案
import preferences from '@ohos.data.preferences';

let options: preferences.Options = { name: 'aegis_prefs' };
let store = await preferences.getPreferences(context, options);
await store.put('key', 'value');
await store.flush();
```

### 7.8 Uri/FileProvider - 29 个文件

广泛使用于文件操作、相机扫描、导入导出等场景。

```java
Uri uri = Uri.parse("content://...");
FileProvider.getUriForFile(context, authority, file);
```

**风险**: 中。🟡
- Android Uri 需要替换为鸿蒙的文件 URI 机制
- FileProvider 需要替换为鸿蒙的文件共享机制

### 7.9 ActivityResultLauncher - 7 个文件

```java
private final ActivityResultLauncher<Intent> scanLauncher =
    registerForActivityResult(new ScanContract(), result -> {
        // 处理结果
    });
```

**风险**: 中。🟡
- Android 的 Activity Result API 需要替换为鸿蒙的 `startAbilityForResult`

### 7.10 Room 数据库注解 - 2 个文件

| 文件 | 注解 |
|------|------|
| `AuditLogEntry.java` | @Entity, @ColumnInfo, @PrimaryKey |
| `AppDatabase.java` | @Database, @Dao, @Query |

```java
@Entity(tableName = "audit_log")
public class AuditLogEntry {
    @PrimaryKey(autoGenerate = true)
    public int id;
}

@Database(entities = {AuditLogEntry.class}, version = 1)
public abstract class AppDatabase extends RoomDatabase {
    public abstract AuditLogDao auditLogDao();
}
```

**风险**: 高。🔴
- Room 是 Android 的 ORM 框架，鸿蒙不支持
- 需要替换为鸿蒙的 `relationalStore` (RDB) 或使用原生 SQL

**建议**:
```typescript
// 鸿蒙 RDB 替代方案
import relationalStore from '@ohos.data.relationalStore';

const STORE_CONFIG = {
    name: 'Aegis.db',
    securityLevel: relationalStore.SecurityLevel.S1
};

// 创建表
const CREATE_TABLE_SQL = `CREATE TABLE IF NOT EXISTS audit_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    event_type INTEGER,
    timestamp INTEGER
)`;
```

### 7.11 Glide 注解 - 1 个文件

```java
@GlideModule
public class AegisGlideModule extends AppGlideModule {
    @Override
    public void registerComponents(Context context, Glide glide, Registry registry) {
        registry.prepend(VaultEntryIcon.class, ByteBuffer.class, ...);
    }
}
```

**风险**: 高。🔴
- Glide 是 Android 的图片加载库，鸿蒙不支持
- 需要替换为鸿蒙的 `Image` 组件或第三方图片加载库

### 7.12 Comparator.comparing (Java 8) - 3 个文件

```java
// EntryAdapter.java
Collections.sort(list, Comparator.comparing(Entry::getIssuer)
    .thenComparing(Entry::getName));
```

**风险**: 中。🟡
- Java 8 的 Comparator API 可能不被鸿蒙完全支持
- 建议改为传统 Comparator 实现

### 7.13 UUID - 9 个文件

```java
UUID uuid = UUID.randomUUID();
UUID.fromString("uuid-string");
```

**风险**: 低。鸿蒙支持 UUID。

### 7.14 SecureRandom/Random - 5 个文件

```java
SecureRandom random = new SecureRandom();
byte[] bytes = new byte[32];
random.nextBytes(bytes);
```

**风险**: 低。鸿蒙支持，但建议使用鸿蒙的 `cryptoFramework` 获取随机数。

### 7.15 MessageDigest (摘要算法) - 7 个文件

```java
MessageDigest md = MessageDigest.getInstance("SHA-256");
byte[] hash = md.digest(data);
```

**风险**: 中。🟡
- Java 的 MessageDigest 需要替换为鸿蒙的 `cryptoFramework`

**建议**:
```typescript
// 鸿蒙替代方案
import cryptoFramework from '@ohos.cryptoFramework';

let md = cryptoFramework.createMd('SHA256');
md.update(data);
let hash = md.digest();
```

### 7.16 ByteBuffer (NIO) - 8 个文件

```java
ByteBuffer buffer = ByteBuffer.wrap(data);
byte[] bytes = buffer.array();
```

**风险**: 低。鸿蒙支持 ByteBuffer。

### 7.17 Pattern/Matcher (正则表达式) - 5 个文件

```java
Pattern pattern = Pattern.compile("regex");
Matcher matcher = pattern.matcher(input);
```

**风险**: 低。鸿蒙支持正则表达式。

### 7.18 Cloneable - 2 个文件

```java
public class VaultRepository implements Cloneable {
    @Override
    public Object clone() throws CloneNotSupportedException {
        // return deep copy
    }
}
```

**风险**: 低。鸿蒙支持 Cloneable。

### 7.19 @TargetApi/@RequiresApi/@SuppressLint - 31 个文件

```java
@TargetApi(Build.VERSION_CODES.M)
private void someMethod() {
    // Android M+ 特定代码
}

@RequiresApi(api = Build.VERSION_CODES.O)
public void anotherMethod() {
    // Android O+ 特定代码
}
```

**风险**: 中。🟡
- Android 版本检查注解需要替换为鸿蒙的版本检查
- 鸿蒙使用 API Level 而非 Android SDK 版本

**建议**:
```typescript
// 鸿蒙版本检查
if (deviceInfo.apiVersion >= 9) { // API 9+
    // 特定 API 代码
}
```

### 7.20 WeakReference - 4 个文件

```java
private WeakReference<Context> contextRef;
```

**风险**: 低。鸿蒙支持 WeakReference。

### 7.21 抽象类 (Abstract Class) - 14 个文件

| 文件 | 抽象类 |
|------|--------|
| `OtpInfo.java` | OTP 信息基类 |
| `Slot.java` | 密钥槽基类 |
| `UUIDMap.Value` | UUID 映射值基类 |
| `DatabaseImporter.java` | 导入器基类 |
| `AppDatabase.java` | Room 数据库基类 |

**风险**: 低。鸿蒙支持抽象类。

### 7.22 默认接口方法

检查是否有接口使用 `default` 方法（目前未发现）。

### 7.23 Try-with-resources

大量使用，鸿蒙 Java/Kotlin 支持此特性，无需修改。

### 7.24 switch 表达式 (Java 14+)

```java
// OtpInfo.java
switch (type) {
    case TotpInfo.ID:
        info = new TotpInfo(...);
        break;
    case SteamInfo.ID:
        info = new SteamInfo(...);
        break;
    default:
        throw new OtpInfoException(...);
}
```

**风险**: 低。这是传统的 switch 语句，不是 Java 14 的 switch 表达式，鸿蒙支持。

---

## 📊 风险汇总

| 优先级 | 问题 | 影响范围 | 工作量 |
|--------|------|----------|--------|
| P0 | 反射创建类实例 | 导入器、Fragment | 中 |
| P0 | Hilt 依赖注入 | 整个应用架构 | 大 |
| P0 | Handler/Looper 机制 | UI 刷新、定时任务 | 中 |
| P0 | Room 数据库 | 审计日志 | 中 |
| P0 | Glide 图片加载 | 图标显示 | 大 |
| P1 | 反射访问私有 API | Activity finish | 小 |
| P1 | Serializable 序列化 | 数据传递 | 中 |
| P1 | Stream API | 集合操作 | 中 |
| P1 | SharedPreferences | 偏好设置 | 中 |
| P1 | Uri/FileProvider | 文件操作 | 中 |
| P1 | ActivityResultLauncher | Activity 结果 | 中 |
| P1 | MessageDigest | 加密摘要 | 小 |
| P1 | Comparator.comparing | 排序 | 小 |
| P1 | @TargetApi/@RequiresApi | 版本检查 | 小 |
| P2 | Lambda/方法引用 | UI 回调 | 小 |
| P2 | Optional | Vault 迁移 | 小 |
| P2 | 枚举/泛型/接口 | 基础类型 | 小 |

---

## 🛠️ 迁移检查清单

### 反射相关
- [ ] 替换 `DatabaseImporter.create()` 反射逻辑
- [ ] 替换 `IntroBaseActivity` Fragment 反射创建
- [ ] 替换 `PreferencesActivity` Fragment 反射创建
- [ ] 检查 `AegisActivity` 反射调用 finish() 的鸿蒙兼容性
- [ ] 评估 `TrustedIntents` 库的必要性

### 序列化相关
- [ ] 将 `Serializable` 改为鸿蒙 `Parcelable` 或自定义
- [ ] 检查 `org.json` 在鸿蒙的可用性
- [ ] 验证 Vault JSON 格式兼容性

### 依赖注入
- [ ] 设计替代 Hilt 的方案（手动 DI 或鸿蒙框架）
- [ ] 重写 `AegisModule` 为服务定位器
- [ ] 替换所有 `@Inject` 字段为显式获取

### Java 8+ 特性
- [ ] 评估 Stream API 替换方案
- [ ] 替换 Optional 使用
- [ ] 验证 Lambda 表达式兼容性

### Android 平台 API 替换
- [ ] 替换 Handler/Looper 为鸿蒙异步任务机制
- [ ] 替换 SharedPreferences 为鸿蒙 preferences 模块
- [ ] 替换 Uri/FileProvider 为鸿蒙文件 API
- [ ] 替换 ActivityResultLauncher 为 startAbilityForResult
- [ ] 替换 Room 数据库为鸿蒙 relationalStore
- [ ] 替换 Glide 为鸿蒙图片加载方案
- [ ] 替换 MessageDigest 为鸿蒙 cryptoFramework
- [ ] 替换 @TargetApi/@RequiresApi 为鸿蒙版本检查

### 其他
- [ ] 验证枚举在鸿蒙中的兼容性
- [ ] 验证泛型通配符的兼容性
- [ ] 验证内部类和闭包的兼容性
- [ ] 验证 UUID、SecureRandom、ByteBuffer 等基础类的兼容性

---

**报告生成时间**: 2026-03-07
**更新内容**: 新增 14 个语言特性分类，包括 Handler/Looper、SharedPreferences、Room、Glide 等
**下一步**: 建议按 P0 -> P1 -> P2 的顺序逐个修复
