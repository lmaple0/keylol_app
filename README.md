# KeylolF M

基于 [keylol-flutter/keylol_app](https://github.com/keylol-flutter/keylol_app) 的维护分支，Fork 位于 [lmaple0/keylol_app](https://github.com/lmaple0/keylol_app)。

短信登录改用 APP 内的其乐官方网页完成滑块与短信验证，论坛接口确认会话有效后返回 APP。日常阅读继续使用 Flutter 组件。

## 开发环境

- Flutter 3.47.7 / Dart 3.13.5（可用 `.fvmrc` 固定版本）。
- Android 原生构建另需 JDK 17 或 21、Android SDK 36 与对应 NDK；最低支持 Android API 24。
- Git 依赖固定在已核对提交，具体版本见 `pubspec.lock`。

```sh
flutter pub get --enforce-lockfile
flutter analyze
flutter test
flutter build apk --debug --target-platform android-arm64
```

Android 包名为 `io.github.lmaple0.keylol`，桌面名称为 `KeylolF M`，可与原版并存。debug 构建不需要上游签名密钥。未使用的上游 Android Firebase 配置已移除。

`Build and test Android` Actions 工作流在 main、fix/sms-web-login 推送以及 PR 时运行，APK 输出在对应运行的 `keylolf-m-arm64-debug-apk` Artifact 中。

## 研究与验证

- [短信故障、修复设计、依赖边界与验证结果](docs/sms-login-investigation.md)
- [参考 Re:Source 的功能建议与 Flutter/Compose 判断](docs/product-notes.md)

本机已完成 Dart Kernel 编译和自动化测试；Android 原生 APK 构建交由 GitHub Actions。真实手机号收码、手机 WebView 滑块、登录后重启保持等仍需实机验收。
