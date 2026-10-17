# KeylolF M

基于 [keylol-flutter/keylol_app](https://github.com/keylol-flutter/keylol_app) 的维护分支，Fork 位于 [lmaple0/keylol_app](https://github.com/lmaple0/keylol_app)。

短信登录改用 APP 内的其乐官方网页完成滑块与短信验证，论坛接口确认会话有效后返回 APP。日常阅读继续使用 Flutter 组件。

## 开发环境

- Flutter 3.47.7 / Dart 3.13.5（可用 `.fvmrc` 固定版本）。
- Android 原生构建另需 JDK 17 或 21、Android SDK 36 与对应 NDK；最低支持 Android API 24。
- 构建工具：Gradle 9.3.1、AGP 9.1.1、Kotlin 2.4.0，启用内置 Kotlin；当前 Flutter 仍需 `android.newDsl=false`。
- Git 依赖固定在已核对提交，具体版本见 `pubspec.lock`。

```sh
flutter pub get --enforce-lockfile
flutter analyze
flutter test
flutter build apk --debug --target-platform android-arm64
```

Android 包名为 `io.github.lmaple0.keylol`，桌面名称为 `KeylolF M`，可与原版并存。正式版使用此维护仓库自己的固定签名密钥。未使用的上游 Android Firebase 配置已移除。

`Release Android arm64` 在推送 `v*` 标签时构建固定签名的 arm64 Release APK，并发布到 GitHub Releases；手动触发只上传 Artifact。debug 工作流保留为手动触发，避免重复构建。

签名备份、首次安装及后续发布步骤见 [正式签名与发布](docs/releasing.md)。从旧 debug 版切换到正式版需要卸载旧维护版，此后的正式版可覆盖升级。

## 研究与验证

- [短信故障、修复设计、依赖边界与验证结果](docs/sms-login-investigation.md)
- [参考 Re:Source 的功能建议与 Flutter/Compose 判断](docs/product-notes.md)

本机已完成 Dart Kernel 编译和会话回归测试，Android 原生构建交由 GitHub Actions。用户已实机确认短信流程及登录后帖子、个人资料访问正常；正式版使用 Release 构建和固定签名。
