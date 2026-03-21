# Android 发布说明（2026-03-21）

本文记录项目当前 Android 发布口径，重点说明：

- 为什么 APK 会突然从二十多 MB 变成 80MB 左右
- 当前脚本默认会产出什么包
- 直接发给用户安装时应该用哪种 APK

## 1. 体积变大的原因

本项目之前出现的 `80MB+` APK，主因不是业务代码突然膨胀，而是打出了 `universal APK`。

`universal APK` 会把多个 ABI 一起打进同一个安装包，当前主要包含：

- `arm64-v8a`
- `armeabi-v7a`
- `x86_64`

Flutter Android 包体积的大头通常在 `lib/*.so`，不是 `classes.dex`。  
本项目这次排查里，APK 体积的大头也是多架构 native so 叠加。

## 2. 当前关于 R8 的结论

当前 release 构建并不是“完全没走 R8”。

排查时 release 产物里已经生成了：

- `build/app/outputs/mapping/release/mapping.txt`
- `build/app/outputs/mapping/release/usage.txt`

其中 `mapping.txt` 里可以看到 `# compiler: R8`，说明 release 构建实际经过了 R8。

补充说明：

- 当前 `android/app/build.gradle.kts` 没有显式写 `minifyEnabled` / `shrinkResources`
- 但这次 APK 变成 80MB 的主因仍然是 `universal APK`
- 如果后续还要继续压缩体积，再单独评估显式资源压缩配置即可

## 3. 当前默认发布策略

为了适合“直接发 APK 给用户安装”，项目脚本默认值已调整为：

- `ANDROID_TARGET=apk`
- `ANDROID_APK_PROFILE=arm64`

也就是默认只产出一个 `arm64` 的 Android APK。

这样做的原因：

- 现在大多数 Android 真机都是 `arm64`
- 单文件 APK 适合直接分享给用户
- 体积明显比 universal APK 小

## 4. 推荐用法

### 4.1 默认直接发布给用户

```bash
./scripts/build_unified_artifacts.sh android release
```

默认产出：

- 一个 `arm64-v8a.apk`

适合：

- 微信/QQ/网盘/群文件直接发用户安装
- 大多数主流 Android 手机

### 4.2 需要多个小 APK

```bash
ANDROID_APK_PROFILE=split ./scripts/build_unified_artifacts.sh android release
```

会按 ABI 分别产出多个 APK，例如：

- `arm64-v8a.apk`
- `armeabi-v7a.apk`
- `x86_64.apk`

适合：

- 你知道用户设备架构
- 想尽量减小每个 APK 的体积

### 4.3 需要一个兼容最全的大 APK

```bash
ANDROID_APK_PROFILE=universal ./scripts/build_unified_artifacts.sh android release
```

适合：

- 只想发一个 APK
- 又希望兼容更多架构

代价：

- APK 会明显更大

### 4.4 需要同时产出 APK 和 AAB

```bash
ANDROID_TARGET=both ANDROID_APK_PROFILE=universal ./scripts/build_unified_artifacts.sh android release
```

适合：

- 同时准备手动分发包和上架包

说明：

- `AAB` 适合商店分发
- `APK` 适合直接发用户安装

## 5. 体积参考

以下是本次排查时的实测参考值，后续版本会有浮动：

- universal APK：约 `80.6MB`
- AAB：约 `59.3MB`
- `arm64-v8a` APK：约 `30.2MB`
- `armeabi-v7a` APK：约 `28.1MB`
- `x86_64` APK：约 `32.0MB`

所以如果看到 APK 突然接近 `80MB`，第一优先检查是否打成了 `universal APK`。

## 6. 产物位置

统一打包脚本默认把产物放到：

```text
build/unified_artifacts/<timestamp>-<mode>/
```

同目录下会有：

- `manifest.txt`

用来查看本次构建实际产出了哪些文件。

## 7. 一句话口径

如果目标是“直接发 APK 给用户安装”，默认用：

```bash
./scripts/build_unified_artifacts.sh android release
```

如果目标是“上架商店”，优先使用：

```bash
ANDROID_TARGET=appbundle ./scripts/build_unified_artifacts.sh android release
```
