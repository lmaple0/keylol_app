# 正式签名与发布

维护版使用固定的 RSA 4096 位自签名证书，PKCS12 密钥库，别名 `keylolf-m`。
Android APK 签名不需要向证书机构购买证书。后续升级必须使用同一把私钥，并递增版本号；不要为每次发布重新生成密钥。

公开证书为 [release-signing-certificate.pem](release-signing-certificate.pem)，SHA-256：

```text
790ae1a206481a5bc4c9204baf7952814a34828c10a2af4ace5e3625fd8e3a9b
```

本机仓库根目录 `.signing/` 内保存：

- `keylolf-m-release.p12`：加密的正式私钥库。
- `key.properties`：密钥库密码、别名和本地引用路径。
- `signing-certificate.pem`：公开证书。

请将整个 `.signing/` 备份到个人密码管理器附件或加密备份盘。该目录限制为当前 Windows 用户访问，且已被 Git 忽略；`android/key.properties` 同样不提交。仓库仅保存公开证书。GitHub Secrets 的值不能从网页读回，不能替代本地备份。

Actions 使用以下 repository secrets，已配置在 `lmaple0/keylol_app`：

- `KEYSTORE_BASE64`：PKCS12 文件的 Base64 内容（Base64 本身不是加密，按私钥保管）。
- `KEYSTORE_PASSWORD`：密钥库及私钥密码。

工作流在临时 runner 中还原密钥，通过 Gradle `signingConfigs.release` 签名，使用 `apksigner verify` 确认签名后上传 APK，并清理临时密钥文件。密码通过环境变量传入，不写入发布日志。

## 下次发布

1. 修改 `pubspec.yaml` 的版本，例如 `1.0.2+3`，确保 `+` 后构建号递增。
2. 新建对应 `.github/release-notes/v1.0.2.md`。
3. 提交并推送 main，然后推送对应标签：

```sh
git tag -a v1.0.2 -m "KeylolF M v1.0.2"
git push origin v1.0.2
```

`Release Android arm64` 自动构建并发布。无需重新设置签名。只想试构建时可手动触发该工作流，不会创建正式 Release。

本地已安装 Android SDK/JDK 时，将备份的 `key.properties` 复制到 `android/key.properties`，保持 `.signing/` 位于仓库根目录，再执行：

```sh
flutter pub get --enforce-lockfile
flutter build apk --release --no-pub --target-platform android-arm64
```

首次从之前的 debug 包切换到正式版，Android 会因签名不同拒绝覆盖安装。需要卸载旧维护版后安装正式版，卸载会清除旧维护版的本地数据；后续正式版本可正常覆盖更新。此限制不影响不同包名的上游原版。

参考：[Flutter Android 签名说明](https://docs.flutter.dev/deployment/android)、[GitHub Actions Secrets](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets)。
