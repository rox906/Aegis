# Importers模块 Java 转 ArkTS 迁移指南

本文档详细说明了将Aegis Importers模块从Java转换为鸿蒙ArkTS时需要注意的语言特性和迁移方案。

## 1. 反射 - **最需要注意**

**位置**: `DatabaseImporter.java:92`, `SqlImporterHelper.java:106`

```java
// DatabaseImporter.java
return type.getConstructor(Context.class).newInstance(context);

// SqlImporterHelper.java
T entry = type.getDeclaredConstructor(Cursor.class).newInstance(cursor);
```

**问题**: ArkTS不支持Java的反射API

**解决方案**:
- 使用工厂模式或注册表模式替代
- 为每个Entry类型创建单独的解析方法
- 示例：
```typescript
// ArkTSTS 替代方案
class SqlImporterHelper {
  private entryParsers: Map<string, (cursor: Cursor) => Entry> = new Map();

  registerParser(type: string, parser: (cursor: Cursor) => Entry) {
    this.entryParsers.set(type, parser);
  }

  read<T extends Entry>(type: string, cursor: Cursor): T {
    const parser = this.entryParsers.get(type);
    if (!parser) throw new Error('No parser registered');
    return parser(cursor) as T;
  }
}
```

## 2. 静态初始化块

**位置**: `DatabaseImporter.java:30`, `BattleNetImporter.java:33`

```java
static {
    _importers = new ArrayList<>();
    _importers.add(new Definition("Aegis", AegisImporter.class, ...));
}
```

**问题**: ArkTS没有静态初始化块

**解决方案**:
- 使用静态属性和懒加载
- 或者在模块加载时初始化
```typescript
// ArkTS 替代方案
class DatabaseImporter {
  private static _importers: Definition[] | null = null;

  static getImporters(): Definition[] {
    if (!this._importers) {
      this._importers = [
        new Definition("Aegis", AegisImporter, ...),
        // ...
      ];
    }
    return this._importers;
  }
}
```

## 3. Java序列化接口

**位置**: `DatabaseImporter.java:107`

```java
public static class Definition implements Serializable {
```

**问题**: ArkTS没有`Serializable`接口

**解决方案**:
- 如果需要序列化，使用JSON序列化
- 如果只是标记接口，可以移除或创建一个空接口
```typescript
// ArkTS 替代方案
interface Serializable {} // 空接口用于类型标记

class Definition implements Serializable {
  // ...
}
```

## 4. Try-with-resources

**位置**: 多处使用

```java
try (InputStream stream = SuFileInputStream.open(file)) {
    // 使用stream
}
```

**问题**: ArkTS不支持try-with-resources语法

**解决方案**:
- 使用try-finally手动关闭资源
- 或使用ArkTS的`using`模式（如果支持）
```typescript
// ArkTS 替代方案
try {
  const stream = SuFileInputStream.open(file);
  try {
    // 使用stream
  } finally {
    stream.close();
  }
} catch (e) {
  // 处理异常
}
```

## 5. 字节数组操作

**位置**: 多处使用`Arrays.copyOfRange`, `new byte[]`

```java
byte[] nonce = Arrays Arrays.copyOfRange(_data, offset, offset + NONCE_SIZE);
byte[] IV = new byte[]{0x00, 0x00, ...};
```

**问题**: ArkTS的数组操作方式不同

**解决方案**:
- 使用`ArrayBuffer`和`Uint8Array`
- 使用`slice()`方法替代`copyOfRange`
```typescript
// ArkTS 替代方案
const nonce = data.slice(offset, offset + NONCE_SIZE);
const IV = new Uint8Array([0x00, 0x00, ...]);
```

## 6. Stream API

**位置**: `DatabaseImporter.java:101`

```java
return Collections.unmodifiableList(
    _importers.stream()
        .filter(Definition::supportsDirect)
        .collect(Collectors.toList())
);
```

**问题**: ArkTS没有Java Stream API

**解决方案**:
- 使用数组的`filter`和`map`方法
```typescript
// ArkTS 替代方案
return this._importers
  .filter(def => def.supportsDirect())
  .map(def => def); // 如果需要新数组
```

## 7. 泛型

**位置**: `SqlImporterHelper.java:76`, `DatabaseImporter.java:90`

```java
public <T extends Entry> List<T> read(Class<T> type, InputStream inStream, String table)
```

**问题**: ArkTS的泛型语法和约束不同

**解决方案**:
- ArkTS支持泛型，但语法略有不同
```typescript
// ArkTS 替代方案
read<T extends Entry>(type: new (cursor: Cursor) => T, inStream: InputStream, table: string): T[] {
  // ...
}
```

## 8. 异常处理

**位置**: 多处使用

```java
public class DatabaseImporterException extends Exception {
    public DatabaseImporterException(Throwable cause) {
        super(cause);
    }
}
```

**问题**: ArkTS使用`Error`而不是`Exception`

**解决方案**:
- 使用ArkTS的`Error`类
- 自定义错误类
```typescript
// ArkTS 替代方案
class DatabaseImporterException extends Error {
  constructor(cause?: Error) {
    super(cause?.message);
    this.name = 'DatabaseImporterException';
    this.cause = cause;
  }

  cause?: Error;
}
```

## 9. 内部类

**位置**: 多个importer中有静态内部类

```java
public static class State extends DatabaseImporter.State {
    // ...
}
```

**问题**: ArkTS支持嵌套类，但语法和行为可能不同

**解决方案**:
- ArkTS支持嵌套类，通常可以保留
- 如果访问外部类成员，需要使用闭包或传递引用

## 10. 注解

**位置**: `@SuppressLint`, `@NonNull`, `@Nullable`, `@StringRes`

```java
@SuppressLint("Range")
public static String getString(Cursor cursor, String columnName) {
```

**问题**: 这些是Android特有注解，ArkTS不需要

**解决方案**:
- 直接移除这些注解
- 或使用ArkTS对应的装饰器（如果存在）

## 11. Java IO流

**位置**: 广泛使用`InputStream`, `DataInputStream`, `BufferedReader`等

```java
InputStream stream = new FileInputStream(file);
BufferedReader reader = new BufferedReader(new InputStreamReader(stream));
```

**问题**: ArkTS的IO模型不同，使用`fs`模块或`@ohos.file.fs`

**解决方案**:
- 使用鸿蒙的文件系统API
```typescript
// ArkTS 替代方案
import fs from '@ohos.file.fs';

async readFile(path: string): Promise<Uint8Array> {
  const file = fs.openSync(path, fs.OpenMode.READ_ONLY);
  try {
    const stat = fs.statSync(path);
    const buffer = new ArrayBuffer(stat.size);
    fs.readSync(file.fd, buffer);
    return new Uint8Array(buffer);
  } finally {
    fs.closeSync(file);
  }
}

async readTextFile(path: string): Promise<string> {
  const bytes = await this.readFile(path);
  const decoder = new TextDecoder('utf-8');
  return decoder.decode(bytes);
}
```

## 12. SQLite

**位置**: `SqlImporterHelper.java:100`

```java
SQLiteDatabase db = SQLiteDatabase.openDatabase(file.getAbsolutePath(), null, OPEN_READONLY);
Cursor cursor = db.rawQuery("SELECT * FROM accounts", null);
```

**问题**: ArkTS不直接支持Android的SQLite API

**解决方案**:
- 使用鸿蒙的`relationalStore` (RDB)
```typescript
// ArkTS 替代方案
import relationalStore from '@ohos.data.relationalStore';

const config: relationalStore.StoreConfig = {
  name: 'Import.db',
  securityLevel: relationalStore.SecurityLevel.S1
};

async readFromDatabase(context: Context, dbPath: string, tableName: string): Promise<any[]> {
  const rdbStore = await relationalStore.getRdbStore(context, config);

  const predicates = new relationalStore.RdbPredicates(tableName);
  const resultSet = await rdbStore.query(predicates);

  const results: any[] = [];
  while (resultSet.goToNextRow()) {
    const row: any = {};
    const columnCount = resultSet.columnCount;
    for (let i = 0; i < columnCount; i++) {
      const columnName = resultSet.getColumnName(i);
      row[columnName] = resultSet.getString(i);
    }
    results.push(row);
  }

  return results;
}
```

## 13. 枚举

**位置**: `StratumImporter.java:54`

```java
private enum Algorithm {
    SHA1, SHA256, SHA512
}
```

**问题**: ArkTS的枚举语法略有不同

**解决方案**:
- ArkTS支持枚举，可以直接转换
```typescript
// ArkTS 替代方案
enum Algorithm {
  SHA1 = 0,
  SHA256 = 1,
  SHA512 = 2
}
```

## 14. 字符串编码

**位置**: 多处使用`StandardCharsets.UTF_8`

```java
String str = new String(bytes, StandardCharsets.UTF_8);
byte[] bytes = str.getBytes(StandardCharsets.UTF_8);
```

**问题**: ArkTS使用`TextEncoder`和`TextDecoder`

**解决方案**:
```typescript
// ArkTS 替代方案
const encoder = new TextEncoder();
const decoder = new TextDecoder('utf-8');

const bytes = encoder.encode(str);
const str = decoder.decode(bytes);
```

## 15. 集合类

**位置**: `Collections.unmodifiableList`, `ArrayList`, `HashMap`

```java
List<Definition> list = Collections.unmodifiableList(_importers);
Map<String, String> map = new HashMap<>();
```

**问题**: ArkTS使用原生数组类型

**解决方案**:
```typescript
// ArkTS 替代方案
// 使用readonly创建不可变数组
const list: readonly Definition[] = this._importers;

// 使用Map
const map = new Map<string, string>();
```

## 16. Base64/Hex编码

**位置**: 多处使用`Base64.decode`, `Hex.decode`

```java
byte[] bytes = Base64.decode(string);
byte[] bytes = Hex.decode(string);
```

**问题**: ArkTS使用不同的API

**解决方案**:
```typescript
// ArkTS 替代方案
import util from '@ohos.util';

// Base64
const base64 = new util.Base64();
const bytes = base64.decodeSync(string);

// Hex需要自己实现或使用第三方库
function hexToBytes(hex: string): Uint8Array {
  const bytes = new Uint8Array(hex.length / 2);
  for (let i = 0; i < hex.length; i += 2) {
    bytes[i / 2] = parseInt(hex.substr(i, 2), 16);
  }
  return bytes;
}
```

## 17. JSON处理

**位置**: 多处使用`JSONObject`, `JSONArray`

```java
JSONObject obj = new JSONObject(jsonString);
JSONArray array = obj.getJSONArray("items");
```

**问题**: ArkTS使用原生JSON

**解决方案**:
```typescript
// ArkTS 替代方案
const obj = JSON.parse(jsonString) as any;
const array = obj.items as any[];
```

## 18. XML解析

**位置**: `BattleNetImporter.java`, `FreeOtpImporter.java`, `AuthyImporter.java`

```java
XmlPullParser parser = Xml.newPullParser();
parser.setInput(stream, null);
parser.nextTag();
```

**问题**: ArkTS没有内置的XML解析器

**解决方案**:
- 使用第三方XML解析库
- 或使用正则表达式简单解析（不推荐用于复杂XML）
```typescript
// ArkTS 替代方案 - 使用第三方库如xml2js
import { parseXml } from 'xml2js';

async parseXmlFile(stream: InputStream): Promise<any> {
  const text = await this.readTextFromStream(stream);
  const result = await parseXml(text);
  return result;
}
```

## 迁移优先级

| 优先级 | 特性 | 难度 | 影响范围 | 文件 |
|--------|------|--------|----------|------|
| **高** | 反射 | 高 | DatabaseImporter, SqlImporterHelper | DatabaseImporter.java, SqlImporterHelper.java |
| **高** | 静态初始化块 | 中 | DatabaseImporter, BattleNetImporter | DatabaseImporter.java, BattleNetImporter.java |
| **高** | Java IO流 | 高 | 几乎所有importer | 所有importer文件 |
| **高** | SQLite | 高 | GoogleAuthImporter, MicrosoftAuthImporter | SqlImporterHelper.java |
| **中** | Try-with-resources | 低 | 代码风格 | 多处 |
| **中** | Stream API | 低 | 代码风格 | DatabaseImporter.java |
| **中** | 异常处理 | 中 | 自定义异常类 | DatabaseImporterException.java |
| **中** | XML解析 | 中 | BattleNet, FreeOTP, Authy | BattleNetImporter.java等 |
| **中** | 字节数组操作 | 低 | AndOTP, Stratum等 | 多处 |
| **低** | 注解 | 低 | 移除即可 | SqlImporterHelper.java等 |
| **低| 枚举 | 低 | Stratum | StratumImporter.java |
| **低** | 集合类 | 低 | 代码风格 | 多处 |

## 迁移建议

### 1. 分阶段迁移
1. **第一阶段**: 处理高优先级问题（反射、静态初始化、IO流）
2. **第二阶段**: 处理中优先级问题（SQLite、异常处理、XML解析）
3. **第三阶段**: 处理低优先级问题（注解、枚举、集合类）

### 2. 使用鸿蒙API替代
- `java.io.*` → `@ohos.file.fs`
- `android.database.sqlite.*` → `@ohos.data.relationalStore`
- `java.util.Base64` → `@ohos.util.Base64`

### 3. 保留业务逻辑
- 尽量保留原有的业务逻辑和算法
- 只替换底层的API调用

### 4. 测试策略
- 为每个importer编写单元测试
- 使用测试数据验证转换后的功能
- 特别测试加密/解密功能

## 相关资源

- [ArkTS语言规范](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/arkts-get-started-V5)
- [鸿蒙文件系统API](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/js-apis-file-fs-V5)
- [鸿蒙关系型数据库API](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/js-apis-data-relationalStore-V5)
