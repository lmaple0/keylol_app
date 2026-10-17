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
- Android：AGP 8.12.1、Kotlin 2.2.20、Gradle 8.14.4、Java 17 字节码，最低 Android API 24。首轮 CI 发现 Flutter 3.47 的最低 Gradle/Kotlin 要求高于 PackageInfo Plus 文档；已按 Flutter 官方 SDK 内 DependencyVersionChecker 统一修正。
- `dynamic_color` 保持兼容系列 1.9.0：2.x 改用 `material_ui.ColorScheme`，不能直接传入当前项目的 Flutter Material 组件。
- `html` 限制为 `>=0.15.6 <0.15.7`：`flutter_html 3.0.0` 调用的内部 `qs.matches` 已在 0.15.7 消失。先保留可编译组合，后续待渲染库升级再解除约束。
- API、组件仓库自身约束仍限制缓存、图片预览等部分依赖；未使用全局 overrides 强行跨主版本升级。
- 将动态 `IconData` 首字母头像改为文字首字母，避免新工具链的非 const 图标告警与图标裁剪问题。
- 不依赖签名密钥的 Actions 工作流按用户要求精简为：解析一次依赖、构建 arm64 debug APK、上传。已移除重复分析/测试与产物断言；旧签名发布工作流仅在上游仓库 push 时执行。CI 结果以对应 Actions 运行记录为准。
- Android 使用新包名 `io.github.lmaple0.keylol`，桌面名称 `KeylolF M`；Kotlin MainActivity 和 namespace 同步迁移，删除未使用的上游 Android Firebase 配置。iOS 标识未改动，本轮不构建 iOS。
- 第二轮 CI 在 JetifyTransform 处理 Flutter 引擎 JAR 时 Java heap space 耗尽。将 Gradle 堆由 1.5 GB 调整为 4 GB、并行 worker 限制为 2；已核对当前 Android 插件未引用旧版 Support Library，关闭 Jetifier，避免对大型引擎 JAR 做无用转换。随后按用户要求改为 arm64-v8a 单架构构建，并增加 Gradle 缓存。
- arm64 轮次的原生 APK 已成功构建；额外 ABI 断言阻止了上传。源码追踪发现 Flutter Gradle 插件会重新设置 abiFilters，现通过官方 `disable-abi-filtering` 属性保留项目内明确的 arm64-v8a 配置。额外产物断言已删除。
- 移除代码中未使用的 build_runner、bloc_test、mocktail，减少 38 项依赖，并将 package_config 升级到 3.0.0。仍有 14 项 newer 提示：SDK 固定 material_color_utilities/test_api；上游约束缓存、图片、边框、cross_file、图标及 equatable；vector_graphics_compiler 限制 xml 不高于 7.0.1；动态取色和 HTML 渲染的兼容约束如上。未使用 overrides 强行绕过这些约束。

实机验收：进入短信登录 → 输入绑定手机号 → 手指拖动滑块 → 收到验证码 → 提交登录 → APP 显示账户 → 关闭重开仍保持登录；另测取消、断网重试、错误短信码和退出后重新登录。

维护分支保留上游出处，不使用上游私有签名。独立 Android applicationId 支持和原版并存安装。

## 登录后仍是游客的修复（2026-10-17）

用户确认短信流程可用，但帖子、资料请求仍报告未登录。原实现仅用临时 Dio 验证网页 Cookie，再合并进 APP 的旧 CookieJar；同名 host-only/domain/path Cookie 可以共存，旧游客 saltkey 会随新 auth 一起发出。Android WebView 返回的 domain 元数据也不能直接当作服务器 Set-Cookie 的原始作用域。

修复将导入 Cookie 统一为其乐 host-only 作用域，先验证网页会话，清除主客户端其乐站点的旧 Cookie，再保存包含 API 续期结果的新会话。只有主客户端自身再次请求 profile 并得到有效 member_uid，登录页才报告成功。移除不区分会话的全局 HTTP 响应缓存，避免旧游客响应影响认证状态。

新增回归复现旧实现的“探测成功、后续 profile 返回 0”，并覆盖帖子请求及 PersistCookieJar 磁盘重载；另验证临时探测成功而主客户端返回游客时不会报告成功。修复后会话测试共 8 项通过，真实账号仍需手机确认。

构建配置升级到 Gradle 9.3.1、AGP 9.1.1、Kotlin 2.4.0；APP 移除旧 kotlin-android 应用和 kotlinOptions，启用内置 Kotlin。根据 Flutter 3.47 当前兼容要求保留 android.newDsl=false，参见 [Flutter 迁移文档](https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-app-developers) 与 [AGP 兼容表](https://developer.android.com/build/releases/agp-9-1-0-release-notes)。flutter_inappwebview_android 未指定 Java 编译级别，单独为它设置 Java 17，不通过 -Xlint:-options 屏蔽告警。上游插件 Java 源码的 deprecated/unchecked 提示与构建工具版本过低是不同问题，最终原生构建结果以 Actions 为准。

原生构建确认 WebView Android 1.1.3 的 proguard-android.txt 引用被 AGP 9 拒绝。将该稳定版运行时代码和原许可证保留在 vendor/flutter_inappwebview_android，仅修改 Java 17 编译配置与 ProGuard 默认文件为 proguard-android-optimize.txt；根 pubspec 使用明确的本地 override。未修改插件运行时 API，也未在 CI 中临时改写 pub-cache。

另修正 MyCookieManager 导出 Cookie 时的 Max-Age 单位错误：秒数必须乘以 1000 才能加入毫秒时间戳。否则网页中仍有效的长效 Cookie 被导入 APP 后有效期缩短约千倍，可能在后续重启时丢失会话。

## 冷启动恢复账户（2026-10-18，v1.0.2）

用户报告关闭后台重开后必须重新登录。代码确认 AuthenticationBloc 每次以未登录启动，AuthenticationRepository 的流也无条件先发送未登录；AuthenticationStatusFetched 只由密码登录表单触发。首页调用 index() 读取网页，不触发移动 API 认证拦截器，所以磁盘 Cookie 即使有效，账户 UI 仍一直显示未登录。

新增回归使用真实 PersistCookieJar 写入会话后，丢弃全部内存身份，再以新 CookieJar、Repository 和 AuthenticationBloc 模拟冷启动。旧代码因没有恢复请求而超时；修复后主动恢复 profile 并更新账户。启动过程中显示恢复状态，失败时显示重试入口并保留 Cookie；无会话直接进入游客状态，服务器明确拒绝已保存会话时才显示未登录。

启动恢复、断网重试、服务器拒绝和首次启动共 4 项新测试，与原 8 项会话导入测试一起通过。此前测试只验证重载 Cookie 后发送 API 请求，未覆盖实际启动的账户恢复流程。本版本沿用正式签名，可覆盖 v1.0.1 安装；手机端的真实会话及后台重开仍需用户确认。
