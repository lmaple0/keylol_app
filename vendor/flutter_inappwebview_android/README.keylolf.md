# Local AGP 9 compatibility patch

Source: flutter_inappwebview_android 1.1.3 from pub.dev, as pinned by the
original application lockfile. Upstream: https://github.com/pichillilorenzo/flutter_inappwebview

The original LICENSE is retained. Only the runtime lib/ and android/ sources
and package manifest are included; examples and upstream tests are omitted.

Changes in android/build.gradle:
- Use proguard-android-optimize.txt; AGP 9 rejects proguard-android.txt even
  when configuring a debug build with minification disabled.
- Set Java source and target compatibility to 17 instead of the Java 8 default.

MyCookieManager.java also converts Max-Age seconds to milliseconds when exporting
cookies. The original code added seconds directly to a millisecond timestamp,
shortening imported session lifetimes by roughly 1000 times.

No Dart API changes. Remove the root dependency override
when a stable upstream release includes these Android build changes.
