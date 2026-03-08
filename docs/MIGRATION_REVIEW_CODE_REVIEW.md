# Aegis 鸿蒙迁移代码审查报告

> 审查日期: 2026-03-07
> 原项目: Android Java (Aegis Authenticator v3.4.2)
> 迁移版本: 鸿蒙 ArkTS (Aegis-hmos_fixcompile)

---

## 执行摘要

鸿蒙版本是一个**完全重写**的版本，使用 ArkTS 语言而非 Java。这意味着不是简单的代码迁移，而是使用鸿蒙原生 API 重新实现功能。

---

## 1. 反射相关代码（高风险）

### 1.1 动态类实例化 - DatabaseImporter

**原始代码**
`app/src/main/java/com/beemdevelopment/aegis/importers/DatabaseImporter.java:90-97`
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

**迁移后代码**
❌ **未找到对应实现**

鸿蒙版本中**没有实现导入器功能**（DatabaseImporter）。原版本支持从17+个其他认证器应用导入数据，鸿蒙版本目前缺失此功能。

### 审查意见
- ❌ 迁移有问题 - 功能缺失

### 建议
如果需要导入功能，需要重新实现。由于ArkTS不支持反射，需要：
1. 创建一个工厂类，使用 switch/case/when 语句根据类型创建导入器实例
2. 或者为每个导入器类型创建独立的创建方法

---

### 1.2 反射访问私有 API - AegisActivity

**原始代码**
`app/src/main/java/com/beemdevelopment/aegis/ui/AegisActivity.java:103-105`
```java
// 调用 Activity 的私有 finish 方法
Method method = Activity.class.getDeclaredMethod("finish", int.class);
method.setAccessible(true);
method.invoke(this, 2); // FINISH_TASK_WITH_ACTIVITY = 2
```

**迁移后代码**
❌ **未找到对应实现**

鸿蒙版本没有实现类似的Activity finish hack。

### 审查意见
- ⚠️ 需要确认

### 建议
此hack用于Android特定的行为（防止应用从最近任务中消失）。鸿蒙可能有不同的生命周期管理方式，需要确认是否需要类似处理。

---

### 1.3 反射访问私有字段 - ActionModeStatusGuardHack

**原始代码**
`app/src/main/java/com/beemdevelopment/aegis/ui/AegisActivity.java:193-196`
```java
_fadeAnimField = getDelegate().getClass().getDeclaredField("mFadeAnim");
_fadeAnimField.setAccessible(true);
_actionModeViewField = getDelegate().getClass().getDeclaredField("mActionModeView");
_actionModeViewField.setAccessible(true);
```

**迁移后代码**
❌ **未找到对应实现**

### 审查意见
- ⚠️ 需要确认

### 建议
这是Android Material Design的UI hack。鸿蒙使用不同的UI框架，可能不需要此hack。

---

## 2. 依赖注入（高风险）

### 2.1 Hilt/Dagger 依赖注入

**原始代码**
`app/src/main/java/com/beemdevelopment/aegis/AegisApplication.java:1-8`
```java
package com.beemdevelopment.aegis;

import dagger.hilt.android.HiltAndroidApp;

@HiltAndroidApp
public class AegisApplication extends AegisApplicationBase {
}
```

**迁移后代码**
`Aegis-hmos_fixcompile/Aegis-hmos/entry/src/main/ets/service/VaultService.ets:23-39`
```typescript
export class VaultService {
  private static instance: VaultService | undefined = undefined;

  private constructor() {
  }

  static getInstance(): VaultService {
    if (VaultService.instance === undefined) {
      VaultService.instance = new VaultService();
    }
    return VaultService.instance;
  }
}
```

### 审查意见
- ✅ 迁移正确 - 使用了单例模式替代依赖注入

### 建议
鸿蒙版本使用单例模式（VaultService.getInstance()）替代Hilt依赖注入。这是正确的做法，因为鸿蒙没有Hilt支持。

---

## 3. Handler/Looper 线程消息机制（高风险）

### 3.1 UiRefresher 定时刷新

**原始代码**
`app/src/main/java/com/beemdevelopment/aegis/helpers/UiRefresher.java:10-43`
```java
private Handler _handler;

public UiRefresher(Listener listener) {
    _listener = listener;
    _handler = new Handler();
}

public void start() {
    _handler.postDelayed(new Runnable() {
        @Override
        public void run() {
            _listener.onRefresh();
            _handler.postDelayed(this, _listener.getMillisTillNextRefresh());
        }
    }, _listener.getMillisTillNextRefresh());
}
```

**迁移后代码**
`Aegis-hmos_fixcompile/Aegis-hmos/entry/src/main/ets/pages/Index.ets:70-73`
```typescript
this.timerId = setInterval(() => {
  this.refreshCodes();
}, 1000);
```

### 审查意见
- ✅ 迁移正确 - 使用了 setInterval 替代 Handler

### 建议
鸿蒙版本使用标准的 `setInterval` 进行定时刷新，每秒更新一次。这是正确的做法。

---

## 4. SharedPreferences（中风险）

### 4.1 偏好设置存储

**原始代码**
`app/src/main/java/com/beemdevelopment/aegis/Preferences.java:59-68`
```java
private SharedPreferences _prefs;

public Preferences(Context context) {
    _prefs = PreferenceManager.getDefaultSharedPreferences(context);
    // ...
}

public boolean isTapToRevealEnabled() {
    return _prefs.getBoolean("pref_tap_to_reveal", false);
}
```

**迁移后代码**
`Aegis-hmos_fixcompile/Aegis-hmos/entry/src/main/ets/service/PreferencesService.ets:1-25`
```typescript
import { preferences } from '@kit.ArkData';

export class PreferencesService {
  private static instance: PreferencesService | undefined = undefined;
  private store: preferences.Preferences | undefined = undefined;

  async init(context: common.Context): Promise<void> {
    this.store = await preferences.getPreferences(context, 'aegis_prefs');
  }

  async getTapToReveal(): Promise<boolean> {
    const store = this.ensureInitialized();
    return (await store.get('pref_tap_to_reveal', false)) as boolean;
  }
}
```

### 审查意见
- ✅ 迁移正确 - 使用了鸿蒙 @kit.ArkData.preferences

### 建议
鸿蒙版本正确使用了 `@kit.ArkData` 的 preferences 模块。注意API是异步的（Promise），这与Android同步API不同，已正确处理。

---

## 5. 加密相关（中风险）

### 5.1 加密工具类

**原始代码**
`app/src/main/java/com/beemdevelopment/aegis/crypto/CryptoUtils.java:117-122`
```java
public static byte[] generateRandomBytes(int length) {
    SecureRandom random = new SecureRandom();
    byte[] data = new byte[length];
    random.nextBytes(data);
    return data;
}
```

**迁移后代码**
`Aegis-hmos_fixcompile/Aegis-hmos/entry/src/main/ets/util/Encoding.ets:134-138`
```typescript
export function generateUUID(): string {
  const bytes = new Uint8Array(16);
  for (let i = 0; i < 16; i++) {
    bytes[i] = Math.floor(Math.random() * 256);
  }
  // ...
}
```

### 审查意见
- ⚠️ 需要确认

### 建议
鸿蒙版本使用 `Math.random()` 生成UUID，这不是密码学安全的随机数。建议使用鸿蒙的 `cryptoFramework` 获取安全随机数：

```typescript
import { cryptoFramework } from '@kit.CryptoArchitectureKit';

const randGenerator = cryptoFramework.createRandom();
const bytes = await randGenerator.generateRandom(16);
```

---

### 5.2 MessageDigest/HMAC

**原始代码**
Java使用 `javax.crypto.Mac` 和 `java.security.MessageDigest`

**迁移后代码**
`Aegis-hmos_fixcompile/Aegis-hmos/entry/src/main/ets/service/OtpService.ets:60-80`
```typescript
async function computeHmac(secret: Uint8Array, data: Uint8Array, algo: OtpAlgorithm): Promise<Uint8Array> {
  const algoName = getHmacAlgoName(algo);
  const mac = cryptoFramework.createMac(`HMAC|${algoName}`);
  const symKeyBlob: cryptoFramework.DataBlob = { data: secret };
  const symKeyGenerator = cryptoFramework.createSymKeyGenerator(`HMAC`);
  const symKey = await symKeyGenerator.convertKey(symKeyBlob);
  await mac.init(symKey);
  await mac.update({ data: data });
  const result = await mac.doFinal();
  return result.data;
}
```

### 审查意见
- ✅ 迁移正确 - 使用了鸿蒙 cryptoFramework

### 建议
正确使用了鸿蒙的 `@kit.CryptoArchitectureKit` 进行HMAC和摘要计算。

---

## 6. Room 数据库（高风险）

### 6.1 审计日志数据库

**原始代码**
Android版本使用 Room 数据库存储审计日志

**迁移后代码**
❌ **未找到对应实现**

### 审查意见
- ❌ 迁移有问题 - 功能缺失

### 建议
鸿蒙版本没有实现审计日志功能。如果需要此功能，可以使用鸿蒙的 `@kit.ArkData` 的 `relationalStore` 模块：

```typescript
import { relationalStore } from '@kit.ArkData';

const STORE_CONFIG = {
  name: 'Aegis.db',
  securityLevel: relationalStore.SecurityLevel.S1
};
```

---

## 7. Glide 图片加载（高风险）

### 7.1 图标显示

**原始代码**
Android版本使用 Glide 库加载和显示图标

**迁移后代码**
`Aegis-hmos_fixcompile/Aegis-hmos/entry/src/main/ets/pages/Index.ets:690-702`
```typescript
Column() {
  Text(this.getIssuerInitial(item.entry.issuer))
    .fontSize(20)
    .fontWeight(FontWeight.Bold)
    .fontColor('#FFFFFF')
}
.width(44)
.height(44)
.borderRadius(22)
.backgroundColor('#5B7CF7')
```

### 审查意见
- ⚠️ 需要确认

### 建议
鸿蒙版本目前只显示发行者首字母的圆形图标，没有实现自定义图标加载。原版本支持自定义图标（PNG/JPEG/SVG）。如果需要此功能，可以使用鸿蒙的 `Image` 组件：

```typescript
Image(item.iconData)
  .width(44)
  .height(44)
  .borderRadius(22)
```

---

## 8. Stream API（中风险）

### 8.1 集合操作

**原始代码**
`app/src/main/java/com/beemdevelopment/aegis/importers/DatabaseImporter.java:101`
```java
return Collections.unmodifiableList(_importers.stream()
    .filter(Definition::supportsDirect)
    .collect(Collectors.toList()));
```

**迁移后代码**
鸿蒙版本使用 ArkTS 的数组方法（filter, map, sort）

### 审查意见
- ✅ 迁移正确 - ArkTS 原生支持类似操作

### 建议
ArkTS 的数组方法与 Java Stream API 功能类似，迁移正确。

---

## 9. Serializable 序列化（中风险）

### 9.1 数据传递

**原始代码**
Android版本使用 `Serializable` 接口进行数据传递

**迁移后代码**
鸿蒙版本使用 ArkTS 的接口和类型定义

### 审查意见
- ✅ 迁移正确 - ArkTS 使用类型系统

### 建议
ArkTS 有自己的类型系统，不需要 Java 的 Serializable。数据序列化使用 JSON。

---

## 风险汇总

| 优先级 | 问题 | 状态 | 工作量 |
|--------|------|------|--------|
| P0 | 导入器功能（反射创建类） | ❌ 缺失 | 大 |
| P0 | Room 数据库（审计日志） | ❌ 缺失 | 中 |
| P1 | 加密随机数生成 | ⚠️ 需改进 | 小 |
| P1 | 自定义图标加载 | ⚠️ 需确认 | 中 |
| P2 | Hilt 依赖注入 | ✅ 已替换 | - |
| P2 | Handler/Looper | ✅ 已替换 | - |
| P2 | SharedPreferences | ✅ 已替换 | - |
| P2 | 加密 API | ✅ 已替换 | - |
| P2 | Stream API | ✅ 兼容 | - |

---

## 建议修复优先级

1. **P0 - 导入器功能**：这是重要功能，需要重新实现
2. **P0 - 审计日志数据库**：如果需要审计功能，需要实现
3. **P1 - 安全随机数**：将 `Math.random()` 替换为 `cryptoFramework.createRandom()`
4. **P1 - 自定义图标**：评估是否需要实现

---

**报告生成时间**: 2026-03-07
