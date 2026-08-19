# 移动端编译验证清单（Android / iOS）

> 项目：merge_fleet / 显示名 **车水马龙**
> 应用包名（双端已统一）：`com.carlong.mergefleet`
> 显示名（Android `strings.xml` / iOS `Info.plist` 已改）：`车水马龙`
> Kotlin 主包路径已对齐到 `com.carlong.mergefleet`，无 `com.example` / `Merge Fleet` 残留。
>
> **当前状态**：移动端**静态配置已完成**（iOS 骨架 `flutter create --platforms=ios .`、`android/app` 工程、双端包名、显示名、Kotlin 包对齐）。但**当前 WorkBuddy 沙箱无法真正编译安装包**——缺 Android cmdline-tools / 未接受许可证、缺 CocoaPods，且代理对 `maven.google.com` 返回 502、GitHub 不可达。本清单用于在**本机或 CI（有完整工具链 + 正常网络）**上执行验证。

---

## 0. 通用前置

```bash
flutter --version          # 本项目用 Flutter 3.41.6 stable
flutter doctor             # 确认无红色报错（尤其 Android / iOS 工具链）
flutter pub get            # 拉取依赖
```

> `flutter pub get` 在沙箱内可用（依赖已能解析），但 Android/iOS 原生依赖（Gradle / CocoaPods）的下载需要正常外网。

---

## 1. Android —— 发布 APK / AAB

### 1.1 工具链
- 安装 **Android SDK Command-line Tools**（Android Studio → SDK Manager，或独立 `sdkmanager`）。
- 接受许可证：
  ```bash
  sdkmanager --licenses
  # 非交互式自动 yes：
  yes | sdkmanager --licenses
  ```
- 安装平台与构建工具（本项目 AGP 8 / `compileSdk 34`）：
  ```bash
  sdkmanager "platforms;android-34" "build-tools;34.0.0"
  ```
- **JDK**：AGP 8 需要 JDK 17，确认 `JAVA_HOME` 指向 JDK 17。

### 1.2 构建
```bash
flutter pub get
flutter build apk --release                 # 通用单包
# 或按 ABI 拆分（体积更小，推荐上架前）：
flutter build apk --release --split-per-abi
# 或 Play Store 上架格式（AAB）：
flutter build appbundle --release
```
产物位置：
- `build/app/outputs/flutter-apk/app-release.apk`
- `build/app/outputs/flutter-apk/app-<abi>-release.apk`
- `build/app/outputs/bundle/release/app-release.aab`

### 1.3 签名（上架必须）
生成上传密钥：
```bash
keytool -genkey -v -keystore ~/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```
新建 `android/key.properties`：
```
storePassword=<你的密码>
keyPassword=<你的密码>
keyAlias=upload
storeFile=<绝对路径>/upload-keystore.jks
```
在 `android/app/build.gradle.kts` 的 `android { ... }` 内增加 `signingConfigs`（参考 Flutter 官方文档 *Signing the app*）。**切勿把 keystore / 密码提交进 git**——确认 `.gitignore` 已忽略 `*.jks` 与 `key.properties`。

### 1.4 安装验证
```bash
flutter install                                   # 装到已连接设备 / 模拟器
# 或：
adb install build/app/outputs/flutter-apk/app-release.apk
```

---

## 2. iOS —— 验证构建（必须在 macOS 本机）

### 2.1 工具链
- macOS + **Xcode ≥ 15**（`xcode-select --install`；App Store 安装 Xcode）。
- **CocoaPods**：
  ```bash
  sudo gem install cocoapods
  # 或 brew install cocoapods
  ```
- 进入 iOS 目录安装原生依赖（需访问 CocoaPods trunk，正常网络即可）：
  ```bash
  cd ios && pod install && cd ..
  ```

### 2.2 构建
```bash
flutter pub get
# 不签名快速验证构建（CI / 本机校验，不产出 ipa）：
flutter build ios --no-codesign
# 真机 / 上架（需签名）：
flutter build ios --release
# 直接产出 IPA：
flutter build ipa --release
```
产物：`build/ios/iphoneos/Runner.app`；`flutter build ipa` 产出 `build/ios/ipa/Runner.ipa`。

### 2.3 签名
- 用 Xcode 打开 `ios/Runner.xcworkspace` → Signing & Capabilities 选择 Team（需 Apple Developer 账号）。
- 或命令行：在 `ios/Runner.xcodeproj/project.pbxproj` 设 `DEVELOPMENT_TEAM = <teamId>`（bundle id 已为 `com.carlong.mergefleet`，无需再改）。

---

## 3. 网络 / 代理阻塞（本沙箱实测，真实机器可忽略）

| 阻塞点 | 现象 | 解决 |
|---|---|---|
| GitHub 不可达 | `git push` 失败（直连 443 超时 / 全局代理 7897 本机不可达 / WorkBuddy 代理 502） | 本地终端开启 Clash(7897) 后 `git push origin main` |
| `maven.google.com` 经沙箱代理返回 502 | Android Gradle 依赖下载失败 | 在普通网络机器执行第 1 节 |
| CocoaPods trunk | pod install 拉不到 spec | 正常网络即可 |

---

## 4. CI 示例（GitHub Actions，iOS 必须在 macOS runner）

`.github/workflows/build.yml`：

```yaml
name: Build Mobile
on: [push, pull_request]

jobs:
  android:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.41.6'
          channel: stable
      - run: flutter pub get
      - run: flutter build apk --release

  ios:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.41.6'
          channel: stable
      - run: flutter pub get
      - run: cd ios && pod install && cd ..
      - run: flutter build ios --no-codesign
```

---

## 5. 完成判据（Checklist）

- [ ] `flutter build apk --release` 成功产出 apk
- [ ] `flutter build ios --no-codesign` 成功（macOS）
- [ ] 真机 / 模拟器安装运行，车模渲染与两模式（合成 / 停车）均可玩
- [ ] 设置中应用名 = **车水马龙**，包名 = `com.carlong.mergefleet`
- [ ] （上架）已配置签名并可产出 aab / ipa
