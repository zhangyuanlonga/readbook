# 宿主运行时加解密 API v2

更新时间：2026-04-23
适用范围：`flutterreadbook`

## 1. 说明

`ctx.crypto` 用于：

- 摘要
- HMAC
- 对称加解密
- 非对称加解密
- 签名验签
- 随机数与时间戳

这份文档优先给出“方法名、用途、常见调用方式”，用于查表。

## 2. 摘要方法

支持：

- `ctx.crypto.md5(value, options?)`
- `ctx.crypto.sha1(value, options?)`
- `ctx.crypto.sha256(value, options?)`
- `ctx.crypto.sha512(value, options?)`
- `ctx.crypto.sm3(value, options?)`

### 方法：`ctx.crypto.sha256(value, options?)`

#### 功能

对输入值做 SHA-256 摘要。

#### 签名

```js
ctx.crypto.sha256(value, options?)
```

#### 参数

- `value`：待摘要的数据
- `options`：输出编码等附加选项

#### 返回值

- 返回摘要字符串

#### 示例

```js
const digest = ctx.crypto.sha256('hello');
```

#### 注意事项

- 其他摘要方法写法与它类似
- 只是在算法不同

## 3. HMAC 方法

支持：

- `ctx.crypto.hmacSha1(value, key, options?)`
- `ctx.crypto.hmacSha256(value, key, options?)`
- `ctx.crypto.hmacSha512(value, key, options?)`

### 方法：`ctx.crypto.hmacSha256(value, key, options?)`

#### 功能

使用 HMAC-SHA256 对输入值签名。

#### 签名

```js
ctx.crypto.hmacSha256(value, key, options?)
```

#### 参数

- `value`：待签名数据
- `key`：密钥
- `options`：附加选项

#### 返回值

- 返回签名字符串

#### 示例

```js
const sign = ctx.crypto.hmacSha256('hello', 'secret');
```

#### 注意事项

- 其他 HMAC 方法写法类似，只是算法不同

## 4. 对称加解密

支持：

- `ctx.crypto.aesEncrypt(options)`
- `ctx.crypto.aesDecrypt(options)`
- `ctx.crypto.desEncrypt(options)`
- `ctx.crypto.desDecrypt(options)`
- `ctx.crypto.tripleDesEncrypt(options)`
- `ctx.crypto.tripleDesDecrypt(options)`
- `ctx.crypto.rc4Encrypt(options)`
- `ctx.crypto.rc4Decrypt(options)`
- `ctx.crypto.symmetricEncrypt(options)`
- `ctx.crypto.symmetricDecrypt(options)`
- `ctx.crypto.symmetricCrypto(key, iv, algorithm, data)`

### 方法：`ctx.crypto.aesEncrypt(options)`

#### 功能

使用 AES 加密数据。

#### 签名

```js
ctx.crypto.aesEncrypt(options)
```

#### 参数

- `options.data`
- `options.key`
- `options.iv`
- `options.mode`
- `options.padding`
- `options.outputEncoding`

#### 返回值

- 返回加密后的字符串

#### 示例

```js
const encrypted = ctx.crypto.aesEncrypt({
  data: 'hello',
  key: '1234567890123456',
  iv: '1234567890123456',
});
```

#### 注意事项

- 其他对称算法方法写法类似
- 如果站点算法是运行时动态选择，可优先考虑 `symmetricEncrypt / symmetricDecrypt`

## 5. 非对称加解密与签名

支持：

- `ctx.crypto.rsaEncrypt(options)`
- `ctx.crypto.rsaDecrypt(options)`
- `ctx.crypto.rsaSign(options)`
- `ctx.crypto.rsaVerify(options)`
- `ctx.crypto.asymmetricEncrypt(options)`
- `ctx.crypto.asymmetricDecrypt(options)`
- `ctx.crypto.asymmetricCrypto(algorithm, data)`

### 方法：`ctx.crypto.rsaSign(options)`

#### 功能

使用 RSA 私钥对数据签名。

#### 签名

```js
ctx.crypto.rsaSign(options)
```

#### 参数

- `options.data`
- `options.privateKey`
- `options.hash`
- `options.outputEncoding`

#### 返回值

- 返回签名字符串

#### 示例

```js
const signature = ctx.crypto.rsaSign({
  data: 'hello',
  privateKey: '-----BEGIN PRIVATE KEY-----...',
});
```

#### 注意事项

- 验签请用 `rsaVerify(options)`
- 如果算法不是固定 RSA，可看 `asymmetricEncrypt / asymmetricDecrypt`

## 6. 随机数与时间

支持：

- `ctx.crypto.randomBytes(length, options?)`
- `ctx.crypto.randomString(length, options?)`
- `ctx.crypto.timestamp(options?)`

### 方法：`ctx.crypto.timestamp(options?)`

#### 功能

返回当前时间戳。

#### 签名

```js
ctx.crypto.timestamp(options?)
```

#### 参数

- `options.unit`：`ms` 或 `s`

#### 返回值

- 返回时间戳数字

#### 示例

```js
const ms = ctx.crypto.timestamp();
const s = ctx.crypto.timestamp({ unit: 's' });
```

#### 注意事项

- 签名参数中经常会用到它

## 7. 使用建议

- 编码转换优先放在 `ctx.utils`
- 真正的摘要、签名、加解密放在 `ctx.crypto`
- 如果站点只是简单 `md5/sha256/hmac`，优先用直接方法
- 如果站点算法是可配置或动态切换，再考虑通用方法
