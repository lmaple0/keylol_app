# 短信登录与依赖更新：本地研究记录

研究日期：2026-10-17（Asia/Shanghai）。本地研究后，经用户授权创建 [lmaple0/keylol_app](https://github.com/lmaple0/keylol_app) Fork，使用新包名并交由 Actions 构建。

## 基线

- APP：`keylol-flutter/keylol_app`，`8ba64dad10a411759095e72ac5f7f3891b48481d`。
- API：`keylol-flutter/keylol_api`，`7b30a23c8fddd27e2d58035de0d738aaa15fd67d`。
- 组件：`keylol-flutter/discuz_widgets`，`f8275640a31d19861e5f83452173e3b8fe7c1228`。
- 本地分支：`fix/sms-web-login`。

## 根因与证据

用户反馈：点击获取验证码后，没有图形验证码或提示失败。

读取 `https://keylol.com/member.php?mod=logging&action=login`，使用同一匿名会话、网页实际 formhash 和 loginhash，向旧客户端使用的 `plugin.php?id=duceapp_smsauth&ac=sendcode&handlekey=sendsmscode&smscodesubmit=login&inajax=1` 提交**空手机号**。未尝试发送真实短信、猜测手机号或登录用户账户。

服务器返回 HTTP 200 / XML CDATA，内容包括：

```html
<em>请拖动按扭进行安全验证</em>
<input type="hidden" name="seccodespeedtest">
<div class="speedtest_box">拖动滑块至右边放开</div>
<div class="speedtest_slider">...</div>
```

响应中没有旧客户端要求的 `.sec_button`。

旧调用链为 `LoginWithSmsBloc → getSmsLoginParam → LoginParam.fromDocument`。API 解析器使用 `getElementsByClassName('sec_button')[0]`，并依靠固定 substring 下标取得参数。当前滑块响应会导致越界错误；BLoC 的初始化事件未捕获异常，所以用户看不到可操作的验证码。

此外，旧发送按钮在请求成功前就启动 60 秒倒计时；`sendSms` 将所有非特定错误响应当成成功；登录异常处理又会清空服务端错误。它们会进一步掩盖故障。

## 本地修复方式

短信入口打开 APP 内嵌的其乐官方登录页，选择网站原有短信标签；滑块、短信发送、错误提示与提交继续由网站处理。不模拟滑块完成，不自行构造验证 token。

论坛当前桌面滑块的 touch 处理仍按鼠标事件读取坐标，页面适配脚本仅将用户在滑块上的真实手指移动转换成对应鼠标事件。需要 Android 实机确认这一兼容处理。

登录后通过 WebView CookieManager 取得会话，包括 HttpOnly Cookie；使用独立、无应用日志拦截器的 Dio 客户端调用论坛 profile API。仅当接口返回有效 `member_uid` 时，才把 Cookie 保存到 APP 原有持久化 CookieJar 并更新认证状态。匿名、过期、网络失败不覆盖 APP 会话。

网页登录只允许导航到 `https://keylol.com` 的默认 HTTPS 端口。页面包含重新加载与手动确认登录按钮，支持 AJAX 登录后自动检测，并避免对同一 Cookie 重复轮询接口。进入时清理该站点 WebView Cookie，以免意外导入上次网页账户。

旧短信 BLoC、状态、事件、表单模型已从 APP 删除；密码登录保留。API 与组件仓库保留未修改的本地克隆供后续研究。

## 验证边界

已使用官方 Flutter 3.47.7 / Dart 3.13.5 在本机验证。SDK 下载 SHA256：`c2c875da25a1a1448d18ee4e8f398b2f6fce888b4775d8f9130538e16d826cb4`，与官方发布清单一致。

- `flutter pub upgrade --major-versions` 完成依赖解析与锁文件更新；兼容性约束调整后再次执行 `flutter pub get`。
- `flutter analyze --no-pub`：无问题。
- `flutter test --no-pub`：7 项通过，包含 6 项会话/来源/取消测试与 1 项 HTML 内容及真实链接点击测试。
- `flutter assemble --output build/local-kernel -dTargetPlatform=android-arm64 -dBuildMode=debug kernel_snapshot_program`：完整 APP Dart Kernel 编译通过。
- `git diff --check`：通过。
- 完整 `flutter build bundle` 尝试受到缺失 Android SDK 的阻塞；未生成 APK，也未完成 Java/Kotlin/Gradle 原生构建、实机 WebView 和真实短信验收。

自动化测试不等同于真实短信投递、Android WebView 滑块交互或完整 APK 登录验证。

## 依赖升级与兼容边界

- Flutter 工具链固定为 3.47.7，Dart 最低 3.13，Flutter 最低 3.47；`.fvmrc` 和工作流同步。
- 已更新锁文件中的 Dio、SharedPreferences、图片选择/链接打开、数据库等依赖，并升级 Skeletonizer 3、Settings UI 4、PackageInfo Plus 10、Hydrated Bloc 11、Talker 5 等主版本。
- Android：AGP 8.12.1、Kotlin 2.2.0、Gradle 8.13、Java 17 字节码，最低 Android API 24。这符合已下载 PackageInfo Plus 文档的最低构建要求；原生构建仍需验证。
- `dynamic_color` 保持兼容系列 1.9.0：2.x 改用 `material_ui.ColorScheme`，不能直接传入当前项目的 Flutter Material 组件。
- `html` 限制为 `>=0.15.6 <0.15.7`：`flutter_html 3.0.0` 调用的内部 `qs.matches` 已在 0.15.7 消失。先保留可编译组合，后续待渲染库升级再解除约束。
- API、组件仓库自身约束仍限制缓存、图片预览等部分依赖；未使用全局 overrides 强行跨主版本升级。
- 将动态 `IconData` 首字母头像改为文字首字母，避免新工具链的非 const 图标告警与图标裁剪问题。
- 新增不依赖签名密钥的检查工作流，涵盖解析、分析、测试和 debug APK 构建；旧签名发布工作流仅在上游仓库 push 时执行。CI 结果以对应 Actions 运行记录为准。
- Android 使用新包名 `io.github.lmaple0.keylol`，桌面名称 `KeylolF Maple`；Kotlin MainActivity 和 namespace 同步迁移，删除未使用的上游 Android Firebase 配置。iOS 标识未改动，本轮不构建 iOS。

实机验收：进入短信登录 → 输入绑定手机号 → 手指拖动滑块 → 收到验证码 → 提交登录 → APP 显示账户 → 关闭重开仍保持登录；另测取消、断网重试、错误短信码和退出后重新登录。

维护分支保留上游出处，不使用上游私有签名。独立 Android applicationId 支持和原版并存安装。
