# 参考 Re:Source 的小规模改进建议

日期：2026-10-17。以下为建议，尚未纳入此次登录修复的实现范围。

公开资料：[README](https://github.com/kenischu/ReSource)、[更新日志](https://lv1.io/resource/changelog.html)、[Flutter 架构](https://docs.flutter.dev/resources/architectural-overview)、[Compose 模型](https://developer.android.com/develop/ui/compose/mental-model)。Re:Source 为闭源产品，其实现细节、性能和代码来源无法从介绍验证。

## 推荐顺序

1. **断点续读**：记录帖子 tid、最后可见 pid/楼层、页码和更新时间；再次进入定位原楼层，可显示上次看到这里。当前 HistoryRepository 只记访问过的帖子，数据库没有楼层或阅读位置字段。用楼层 ID 为主定位，避免图片加载导致像素偏移失效。先做本地，不引入同步账号。
2. **本地屏蔽**：按用户 ID 和标题关键词隐藏帖子，提供统一管理页与临时显示入口。默认不提交到论坛，避免修改用户站内设置。实现面比新增多论坛、AI 或讨论树小。
3. **稍后读与手动离线保存**：利用已有 SQLite/图片缓存基础；稍后读与站内收藏分开。离线保存必须明确是仅已加载页面还是整个帖子，并显示时间、范围和删除入口。不要一开始自动下载所有大图。

本轮先完成登录兼容、会话保持、依赖更新与验证。下一轮优先断点续读；其余功能可根据实际使用再选。

## 技术判断

- Flutter 使用自己的 UI/绘制引擎，Android/iOS 发布版编译为机器码；不依赖 WebView 显示日常界面。
- Compose 是 Android 的声明式 UI 工具。若只面向 Android，系统 API、平台行为和新功能接入通常更直接；Flutter 的优势是现有代码复用、跨平台和统一交互。
- 不能根据“原生”“零 WebView”判断两款 APP 的实际流畅度、耗电或内存。需要同设备、同帖子和图片缓存条件下测量长列表、加载和滚动。
- 当前项目普通阅读主要通过 Flutter 组件和 Discuz 内容解析实现；iframe、网页视图、发帖等位置已有 WebView。本轮只为论坛登录/验证增加 WebView，不改变普通阅读方式。
- Re:Source README 的“零 WebView”描述与其更新日志中关于系统网页组件、登录页和验证页的说明需要按场景理解。公开资料足以说明它也处理网页验证，不足以证明其内部使用哪种具体 API。
- 推荐保留 Flutter，修好现有项目。为了一个 Keylol 客户端完整重写为 Compose，投入远大于此次登录适配，收益没有实测依据。
