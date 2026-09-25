# Cue

[English](README.md) | 简体中文

Cue 是一个单用户任务管理应用。客户端使用 Flutter 支持 Android、iOS、Web 与桌面端，服务端使用 NestJS，数据持久化到 PostgreSQL；移动端 UI 对齐 Cue Figma V2 设计，提供列表、看板、月历和四象限四种任务投影。

## 给自行部署的用户

Cue 不提供公共账号或托管服务器。每位使用者先在自己的设备或服务器上部署本仓库的 Web、API 和 PostgreSQL，再让手机与桌面客户端连接到**自己的** Cue 服务；数据保存在自行部署的 PostgreSQL 数据卷中。建议让服务端和客户端使用同一个版本。

1. 从 [GitHub Releases](https://github.com/lz00qs/cue/releases) 选择版本，下载对应源码并在服务器上按下方的 [Docker 部署](#docker-部署) 完成初始化。也可以克隆仓库并检出该版本的 `vX.Y.Z` 标签。设置 `.env` 时务必替换示例密码和两个 JWT 密钥。
2. 只在服务器本机或经 SSH 转发的本机页面创建管理员，随后关闭 `CUE_ALLOW_SETUP`。需要从其他设备访问时，为自己的域名配置有效 TLS 证书并启用 HTTPS 入口；不要把初始化用的 HTTP 端口直接暴露到公网。
3. 浏览器访问自己的 HTTPS 地址。macOS DMG、Windows 安装程序和 Android APK 从同一版本的 GitHub Release 下载；iOS 客户端由开发者另行通过 App Store 发布，**GitHub Release 不提供可安装的 iOS `.app` ZIP**。原生客户端首次启动时，填写自己的服务基础地址，例如 `https://tasks.example.com`，再使用刚创建的管理员账号登录。
4. 检查 `docker compose ps` 中 `cue-db`、`cue-api`、`cue-web` 和 `db-backup` 的状态，并按[数据库备份与迁移](#数据库备份与迁移)验证备份。服务端升级前先留存可恢复的备份。

局域网内调试可以按下文配置可信的 HTTP 地址；跨公网访问应使用 HTTPS。iOS App Store 上架状态与 GitHub Release 分开，以 App Store 页面为准。
正式版本还会将 API 与 Web 的 Docker 镜像分别发布为 `ghcr.io/lz00qs/cue/cue-api:X.Y.Z` 和 `ghcr.io/lz00qs/cue/cue-web:X.Y.Z`；下文的 Compose 命令会从同版本源码自行构建，无需先拉取镜像。

## 已实现

- 首次建号需在本机临时开启 `CUE_ALLOW_SETUP`；凭证经 bcrypt 安全哈希后存储于 PostgreSQL，不再写入本地 `.env` 文件
- 提供服务端 CLI 密码重置工具，支持在忘记密码时快速重置
- 15 分钟 Access Token、30 天 Refresh Token 与客户端自动刷新；刷新令牌单次使用，退出登录撤销当前设备会话
- Web、桌面端与移动端均可在账户设置中修改登录邮箱和密码，修改时需验证当前密码
- PostgreSQL 持久化与启动时自动迁移，全新数据库默认不写入示例任务
- 任务新增、读取、状态/优先级更新、软删除；仅 P0 视为重要
- 乐观并发控制：每条任务包含 `version`
- 增量同步基础：全局 `revision` 与删除 tombstone
- Today、Inbox、Upcoming、All Tasks、Kanban、Month Calendar、Priority Quadrants
- Flutter 乐观更新、失败回滚和登录会话恢复
- 多端增量同步：SSE 更新通知、断线重连、每分钟轮询兜底、回到前台同步、下拉刷新和手动同步
- 并发同步请求合并，以及 409 版本冲突后的服务端状态恢复
- Figma V2 移动端 Today、Board、Calendar、Quadrants、Settings 和任务详情交互
- 中文与英文界面、本地化日期格式、跟随系统语言和应用内语言切换
- Nginx 同源 `/api` 反向代理、安全响应头和 SPA 路由
- Docker Compose 编排 Web、API、PostgreSQL，数据库使用命名卷
- OpenAPI 文档：仅在非生产环境的 `/api/docs` 提供

## 配置

复制环境变量模板并修改数据库密码与 JWT 密钥：

```bash
cp .env.example .env
```

`.env` 中配置数据库密码、两个不同的随机 JWT Secret（各至少 32 字符）和首次建号开关。**不要在 `.env` 中存放管理员账号和密码**；旧版环境变量自动建号功能已移除。
可分别运行两次 `openssl rand -hex 32`，将得到的不同随机值填入 `CUE_JWT_SECRET` 和 `CUE_REFRESH_SECRET`；数据库密码也应换成独立的强密码。

`CUE_ALLOW_SETUP` 默认为 `false`。全新数据库初始化时，先保持 `CUE_BIND_ADDRESS=127.0.0.1`，临时把它设为 `true`，通过本机 Web 页面创建管理员。完成后立即改回 `false` 并重建 API 容器，再开放公网 HTTPS 入口。未初始化且开关关闭时，Web 页面会说明需要在本机启用建号；有效的建号 API 请求会得到 403。凭证经 bcrypt 哈希后保存在 PostgreSQL 中。

新建或重置密码要求至少 8 个字符，且不得超过 72 个 UTF-8 字节，以避免 bcrypt 静默截断密码。

### 忘记管理员密码

若在使用过程中遗忘管理员密码，可通过宿主机直接运行 CLI 命令重置：

```bash
docker compose exec cue-api npm run reset-password -- <新密码>
# 也可以同时指定新邮箱：
# docker compose exec cue-api npm run reset-password -- <新密码> <新邮箱>
```

PostgreSQL 默认使用 `CUE_TIMEZONE=Asia/Shanghai`；部署到其他地区时可在 `.env` 修改。

## Docker 部署

Linux 首次启动前，先为备份容器准备目录（容器使用 UID/GID `999:999`）：

```bash
mkdir -p backups && sudo chown 999:999 backups && sudo chmod 700 backups
```

macOS 的 Docker 文件共享权限可能不同；启动后检查 `docker compose logs db-backup`，确认备份文件确实生成。

```bash
docker compose up --build -d
```

首次初始化时，确认 `.env` 中为 `CUE_BIND_ADDRESS=127.0.0.1` 和 `CUE_ALLOW_SETUP=true`，然后在服务器本机打开 [http://localhost:8080](http://localhost:8080) 创建管理员。不要在这一步开放 443 或将 HTTP 端口绑定到公网。

如果服务器没有桌面浏览器，可以从自己的电脑通过 SSH 转发本机端口：`ssh -L 8080:127.0.0.1:8080 user@server`，再打开本机的 `http://localhost:8080`。

创建成功后，将 `CUE_ALLOW_SETUP=false` 写回 `.env`，并执行：

```bash
docker compose up -d --no-deps --force-recreate cue-api
curl -fsS http://localhost:8080/api/auth/status
```

状态应包含 `"initialized":true` 和 `"setupAvailable":false`。即使数据库日后被清空，关闭的建号开关也不会自行重新开放。已有管理员的部署无需再次开启建号。

仅修改后端代码时，可使用项目自带的跨平台一键更新工具。它会重建
`cue-api` 镜像、替换后端容器、等待健康检查通过，并刷新正在运行的
Nginx 代理；PostgreSQL 容器和数据卷不会被删除：

macOS / Linux：

```bash
./scripts/rebuild-backend.sh
```

Windows CMD / PowerShell：

```bat
scripts\rebuild-backend.cmd
```

也可以在所有平台直接运行同一份 Dart 实现：

```bash
dart run tool/rebuild_backend.dart
```

需要忽略 Docker 构建缓存、从头重建时运行：

```bash
./scripts/rebuild-backend.sh --no-cache
# Windows：scripts\rebuild-backend.cmd --no-cache
```

Android Studio 会从 `.run/Rebuild Cue Backend.run.xml` 加载共享运行配置。
重新打开项目（或在运行配置列表中选择它）后，在顶部下拉框选择
`Rebuild Cue Backend`，点击运行按钮即可一键更新后端。该配置使用项目的
Dart SDK，不依赖 Bash，因此 Windows、macOS 和 Linux 使用方式相同。执行前
需确保 Docker Desktop、OrbStack 或其他 Docker 引擎已启动，且项目根目录
已有配置完成的 `.env`。

Web 镜像会在 Docker 构建阶段直接从当前 Flutter 源码编译，避免旧的
`build/web` 产物与新版 API 不兼容。宿主机无需预先运行 `flutter build web`。

浏览器打开 [http://localhost:8080](http://localhost:8080)。端口默认只绑定 `127.0.0.1`，不会直接暴露到局域网。

Compose 将宿主机的 `CUE_WEB_PORT`（默认 8080）映射到 Web 容器的 HTTP 80 端口。HTTPS 使用独立的 443 入口，可在 `.env` 修改绑定地址、端口和证书路径：

```dotenv
CUE_HTTPS_BIND_ADDRESS=0.0.0.0
CUE_HTTPS_PORT=443
CUE_TLS_CERT_FILE=./certs/fullchain.pem
CUE_TLS_KEY_FILE=./certs/privkey.pem
```

先将域名对应的有效证书和私钥放到上述路径（也可在 `.env` 填写宿主机上的绝对路径），再启动 HTTPS：

```bash
docker compose --profile https up --build -d
curl https://your-domain.example/api/health
```

HTTPS 代理会将 `/api` 和同步事件转发给 API，但始终拒绝 `/api/auth/setup`；其余请求转发给 Web 容器。客户端服务器地址填写 `https://your-domain.example`；使用非默认端口时在地址末尾加上端口号。`certs/` 已被 Git 忽略。没有证书时继续使用默认的 `docker compose up --build -d` 启动仅绑定本机的 HTTP 服务。

登录与首次建号接口按来源 IP 限制为平均每分钟 5 次、最多连续 5 次；刷新令牌及退出登录接口平均每分钟 30 次、最多连续 10 次。相同账户在 15 分钟内输错密码 5 次后会锁定 15 分钟，响应仍使用统一的“邮箱或密码错误”提示。忘记密码时可使用上文的服务器端 CLI 重置，重置也会解除锁定。刷新令牌使用后立即失效并签发新令牌；在线退出登录会撤销当前设备会话，离线退出登录只清除本机凭证。密码或邮箱变更后，所有旧会话立即失效；升级到此版本后，旧版本签发的令牌也需要重新登录。

如果使用自己的反向代理或 CDN，应在公网入口配置同等的认证接口限速，并正确识别真实客户端 IP；不要直接暴露 `cue-api` 容器或本机 HTTP 端口。生产模式不提供 `/api/docs`。

从旧版本升级时，本轮安全改动涉及 API、Web 客户端和两层 Nginx 配置，需要执行 `docker compose --profile https up --build -d` 完整重建；未启用 HTTPS profile 的本机部署使用 `docker compose up --build -d`。仅运行后端重建工具不会更新代理限速和客户端退出登录逻辑。API 启动时会自动执行认证表迁移，升级后需重新登录。

Android Studio 默认模拟器可通过宿主机回环别名 `http://10.0.2.2:8080` 访问，无需放宽监听。只有真机或其他可信局域网设备需要访问时，才在 `.env` 设置 `CUE_BIND_ADDRESS=0.0.0.0` 并重新创建 Web 容器；验证完成后应改回 `127.0.0.1`。

健康检查：

```bash
curl http://localhost:8080/healthz
curl http://localhost:8080/api/health
docker compose ps
```

查看日志或停止服务：

```bash
docker compose logs -f cue-api
docker compose down
```

`docker compose down` 不会删除数据库卷。只有明确需要清空全部 Cue 数据时才使用 `docker compose down -v`。

### 数据库备份与迁移

Cue 的 `docker-compose.yml` 中默认包含 `db-backup` 容器。`docker compose up --build -d` 会启动它；容器启动时立即备份一次，之后每小时备份。压缩后的 SQL 文件位于宿主机的 `./backups` 目录，该目录已被 Git 忽略。若只启动了部分服务，可运行 `docker compose up -d db-backup` 补上。

检查备份服务与最新备份，并在隔离的一次性 PostgreSQL 17 容器中演练恢复（需要 Bash 和 Docker）：

```bash
docker compose ps db-backup
ls -lh backups/last/cue-latest.sql.gz
bash scripts/verify-backup-restore.sh backups/last/cue-latest.sql.gz
```

验证脚本不连接现有 Cue 数据库，也不修改其数据卷。备份包含账号和任务数据；还应定期复制到独立、受保护的存储位置，避免服务器磁盘损坏时备份与数据库一起丢失。
数据库增大后若恢复验证所需的临时空间超过默认的 512 MiB，可在运行脚本时设置 `CUE_RESTORE_TMPFS_SIZE=2g`。

**智能轮转策略（GFS）：**
- **每小时**：保留过去 24 小时的记录（通过 `BACKUP_KEEP_MINS=1440` 实现）。
- **每天**：保留过去 7 天的记录。
- **每周**：保留过去 4 周的记录。
- **每月**：保留过去 3 个月的记录。
*（同一份文件在不同周期中通过硬链接存储，不会重复占用硬盘空间）*

**迁移与恢复步骤：**

1. 迁移环境时，将代码及 `./backups` 目录一起复制到新服务器。
2. 在**全新的空 PostgreSQL 数据卷**中仅拉起数据库服务，暂不启动 API，避免迁移或新写入：
   ```bash
   docker compose up -d cue-db
   ```
3. 选择最新的备份文件解压并导入。下面的命令只适用于空数据库，不要直接覆盖正在使用的 Cue 数据库：
   ```bash
   set -o pipefail
   gunzip -c ./backups/last/cue-latest.sql.gz | docker compose exec -T cue-db psql -v ON_ERROR_STOP=1 -U cue -d cue
   ```
4. 恢复完成后，启动所有服务：
   ```bash
   docker compose up -d
   ```

## 本地开发

Flutter 界面使用 Riverpod 管理应用会话、主题、语言及各页面的导航和筛选状态。`lib/state/app_state.dart` 定义应用级 Provider，`lib/state/page_state.dart` 定义页面状态。任务的乐观更新、冲突恢复和增量同步逻辑仍集中在 `TaskStore`，由 `taskRevisionProvider` 把任务变更送到 Riverpod 页面；组件内的文本控制器、悬停与拖拽反馈仍由 Flutter Widget 管理。

Web 默认请求同源 `/api`。如果 Flutter 开发服务器和 API 不同源，可在构建或运行时指定完整地址：

```bash
flutter run -d chrome --dart-define=CUE_API_URL=http://localhost:8080
```

原生移动端和桌面端首次启动会先显示服务器连接页。输入所有设备共用的 Cue 服务基础地址，必须明确以 `http://` 或 `https://` 开头。App 会通过 `/api/health` 验证后保存；`/api` 后缀可省略。移动端可在 `Settings → Import & sync → Change server` 修改地址，桌面端可在侧栏底部修改并手动同步。切换服务器时会清除旧服务器的登录令牌。

Android 模拟器访问宿主机使用 `10.0.2.2`，iOS 模拟器使用 `127.0.0.1`；真机使用电脑的局域网地址或可访问的 HTTPS 域名。`CUE_API_URL` 仍可作为预配置默认值：

```bash
flutter run -d android --dart-define=CUE_API_URL=http://10.0.2.2:8080
flutter run -d ios --dart-define=CUE_API_URL=http://127.0.0.1:8080
flutter build apk --release --dart-define=CUE_API_URL=https://cue.example.com
flutter build ipa --release --dart-define=CUE_API_URL=https://cue.example.com
```

### Android 正式版签名

正式 APK 必须使用长期保存的 Cue 签名密钥库；缺少签名材料时构建会失败，不会退回调试签名。密钥库和密码应保存在仓库外并分别做好安全备份，所有通过 GitHub 直接下载的后续 APK 都要沿用同一把密钥。已经安装的调试签名版本无法直接覆盖升级为正式签名版本。

本地构建时，将 `CUE_ANDROID_SIGNING_PROPERTIES` 指向私有的 Java properties 文件；也可使用已被 Git 忽略的 `android/key.properties`：

```properties
storeFile=/absolute/path/to/cue-release.p12
storePassword=<密钥库密码>
keyAlias=cue-release
keyPassword=<密钥密码>
```

```bash
CUE_ANDROID_SIGNING_PROPERTIES=/absolute/path/to/key.properties flutter build apk --release
```

GitHub Release 工作流仅在版本 tag 上使用 `android-release` 环境，需要在该环境配置两个 Secrets：`CUE_ANDROID_KEYSTORE_BASE64`（同一密钥库文件的单行 Base64 内容）和 `CUE_ANDROID_STORE_PASSWORD`（密钥库及密钥密码）。上传 APK 前，工作流会与 `android/release-cert.sha256` 中公开的证书指纹比较。本项目目前的 PKCS#12 密钥库使用相同的库密码和密钥密码。

### macOS Release DMG

推送与 `pubspec.yaml` 中 `version` 一致的 `vX.Y.Z` 标签后，Release 工作流会生成通用架构的 `Cue-vX.Y.Z-macos-universal.dmg`：导出 Developer ID 签名的 App、签名 DMG、提交 Apple 公证、附加公证票据并验证，然后作为 GitHub Release 附件发布。Xcode Archive 构建成功并不等于已经得到可分发的 DMG。

首次推送版本标签前，在 GitHub 创建 `macos-release` Environment，将可部署的标签限制为 `v*`。设置环境变量 `CUE_MACOS_TEAM_ID` 为 Apple Developer Team ID，并添加以下 Environment Secrets：

| Secret | 内容 |
| --- | --- |
| `CUE_MACOS_DEVELOPER_ID_P12_BASE64` | 含私钥的 **Developer ID Application** `.p12` 文件的单行 Base64 |
| `CUE_MACOS_DEVELOPER_ID_P12_PASSWORD` | 导出该 `.p12` 时设置的密码 |
| `CUE_MACOS_NOTARY_API_KEY_BASE64` | App Store Connect **团队 API 密钥** `.p8` 文件的单行 Base64 |
| `CUE_MACOS_NOTARY_KEY_ID` | App Store Connect 显示的 Key ID |
| `CUE_MACOS_NOTARY_ISSUER_ID` | App Store Connect 显示的 Issuer ID |

在 macOS 上可用 `base64 -i /文件的绝对路径 | tr -d '\n'` 得到单行内容。请独立安全备份 `.p12`、导出密码和只能下载一次的 `.p8`，不要提交到 Git。凭据准备可参考 [Apple Developer ID 证书](https://developer.apple.com/help/account/certificates/create-developer-id-certificates)、[App Store Connect 团队 API 密钥](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-api) 和 [GitHub 证书导入说明](https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/sign-xcode-applications)。个人 API 密钥不能用于 `notarytool`。

### iOS App Store 发布

iOS 源码在 CI 中执行未签名的编译检查，但未签名 `.app` ZIP 无法供普通用户安装，因此 GitHub Release 不再附带它。与 [Immich 的客户端分发方式](https://docs.immich.app/install/post-install/)类似，iOS 客户端应通过 App Store（测试时可用 TestFlight）交付，用户仍连接自己部署的 Cue 服务。

由开发者在 App Store Connect 创建 iOS 应用记录，使用本项目的 Bundle ID `top.hylcreative.cue`，在 Xcode 中配置 **Apple Distribution** 证书与 App Store 签名；这与 macOS DMG 使用的 Developer ID 证书不同。更新 `pubspec.yaml` 的版本和构建号后，在 Mac 上运行 `flutter pub get`、`flutter build ipa --release`，通过 Xcode Organizer 或 Transporter 上传签名 IPA，并在 App Store Connect 中完成 TestFlight 验证和审核提交。每次重新上传须使用新的构建号。具体步骤参见 [Flutter iOS 发布指南](https://docs.flutter.dev/deployment/ios)和 [Apple 上传构建说明](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds)。

提交审核前，还要在 App Store Connect 填写真实的应用说明、截图、支持联系方式、[隐私政策网址及数据收集声明](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy)。由于 Cue 需要登录自建服务，应为 [App Review](https://developer.apple.com/app-store/review/guidelines/) 准备可从公网访问的测试服务器和专用测试账号，并在审核备注写明服务器地址及登录方法；审核期间保持服务可用，不要提供个人生产数据库账号。

若首版需让 iOS 用户同时下载，先等 App Store 审核通过并安排上架时间，再发布 GitHub 的正式 `vX.Y.Z` 标签；仅通过 CI 的 iOS 编译检查不代表 App Store 已可下载。

### Windows Release 安装包

Release 工作流会将 Windows x64 构建目录中的 EXE、DLL、`data` 和 Visual C++ 运行库打包为 `Cue-vX.Y.Z-windows-x64-setup.exe`，并附加到 GitHub Release。安装包使用 Inno Setup，安装在当前用户的程序目录，提供开始菜单快捷方式、可选桌面快捷方式和卸载入口，无需管理员权限。原来的便携 ZIP 也会保留。

在 Windows 本机安装 Flutter、Visual Studio 2022 的 C++ 工具和 Inno Setup 6 后，可以运行：

```powershell
flutter pub get
flutter build windows --release
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/package-windows.ps1
```

当前 Windows 安装包未做代码签名；本次发布流程不配置 Windows 签名。

### 发布前手动演练

完整演练使用与 `pubspec.yaml` 一致的 `vX.Y.Z-dryrun` 标签。推送该标签**不会自动触发 Release 工作流**；手动运行会执行测试、签名 APK、签名并公证 DMG、Windows 安装包测试、iOS 编译检查，以及 API/Web Docker 镜像构建，但不会推送 GHCR 镜像，也不会创建 GitHub Release。演练产物仅保存在该次 Actions 运行的 Artifacts 中。`android-release` 和 `macos-release` 环境仍只需允许 `v*` 标签，不必开放 `main`。

```bash
git tag v1.0.0-dryrun
git push origin v1.0.0-dryrun
gh workflow run release.yml --ref v1.0.0-dryrun
```

上例适用于当前 `version: 1.0.0+1`；修改版本后同步修改演练标签。`gh workflow run --ref` 需要 [GitHub CLI](https://cli.github.com/manual/gh_workflow_run) 及仓库写入权限。此前的 Windows 单独验证仍可在 Actions 页面从 `main` 手动运行，并勾选 `windows_only`。确认演练产物和自行部署流程后，推送正式 `vX.Y.Z` 标签才会发布 GHCR 镜像与 GitHub Release；正式发布要求测试、Android、iOS 编译检查、macOS、Windows 和 Docker job 全部成功。iOS 上架由上节的 App Store Connect 流程单独完成。

明暗配色对应 Figma 文件中 `Cue Color` 的 Light 和 Dark 模式。桌面端在侧栏底部的“外观”菜单、移动端在“设置 → 外观”中可随时切换，选择会保存在本机。`CUE_THEME` 仅设置首次启动时的默认主题；不指定时默认浅色：

```bash
flutter run -d macos --dart-define=CUE_THEME=light
flutter run -d macos --dart-define=CUE_THEME=dark
flutter build web --release --dart-define=CUE_THEME=dark
```

修改 `CUE_THEME` 构建变量需要重新运行应用；已保存的外观选择优先于构建默认值。

macOS 版将登录令牌、服务器地址、语言和外观偏好保存在应用沙箱的 `Library/Application Support/Cue/` 中，不再访问 Keychain。令牌文件只允许当前用户读写，但内容不加密；请勿共享该用户账户或复制这些文件。首次使用此版本时，旧 Keychain 数据不会自动迁移，需要重新填写服务器地址并登录一次。

移动端允许连接可信局域网内的 HTTP 服务；公网部署应使用 HTTPS。只要移动端、Web 和桌面端使用同一 API 与数据库，任务提交后 PostgreSQL 会通知各 API 进程，再通过 SSE 唤醒客户端按全局 `revision` 增量同步；断线时客户端重连并每分钟轮询兜底。每条任务的 `version` 检测并发写入。

后端位于 `server/`。容器启动时会按文件名顺序执行 `server/migrations/` 下的 SQL，再启动 API。

### 批量测试数据

正式启动和数据库迁移不会自动创建演示任务。需要检查四象限、日历、排序或大数据量界面时，可以显式生成一批可追踪的随机任务：

```bash
docker compose exec -e CUE_ALLOW_DEMO_DATA=true cue-api \
  npm run demo:seed -- \
  --batch ui-test-01 --count 50 --seed 20260923 --days 30
```

- `--batch` 是必填的批次名，只能使用字母、数字、`_` 和 `-`；每次生成应使用新名称。
- `--count` 默认为 40，最多 500。
- `--seed` 控制可重复的随机分布；省略时由批次名确定。
- `--days` 默认为 30，到期时间会分布在当天前后该天数内，并混合 P0–P3、无日期和已完成任务。
- 需要固定截图或回归测试时，可加 `--reference-date 2026-09-23T12:00:00+08:00`。

按批次删除测试数据：

```bash
docker compose exec -e CUE_ALLOW_DEMO_DATA=true cue-api \
  npm run demo:clear -- --batch ui-test-01
```

删除所有由该工具生成且尚未删除的任务：

```bash
docker compose exec -e CUE_ALLOW_DEMO_DATA=true cue-api \
  npm run demo:clear -- --all
```

测试任务的 ID 带有 `demo:<batch>:` 标记，清理命令只按该标记匹配，不会根据标题或日期模糊删除。清理使用软删除并生成新的同步 `revision`，已连接的其他客户端也会收到变化。容器中 `NODE_ENV=production`，因此每次执行都必须仅为当前命令显式传入 `CUE_ALLOW_DEMO_DATA=true`。

界面翻译位于 `lib/l10n/app_en.arb` 与 `lib/l10n/app_zh.arb`。修改 ARB 后运行 `flutter gen-l10n` 重新生成本地化代码。

## 验证

CI 会在提交到 `main` 和针对 `main` 的 Pull Request 上运行 Flutter 静态分析、Flutter 测试以及服务端构建与单元测试。版本标签触发的 Release 工作流会先复用同一套测试；只有测试通过，才会开始各平台构建和 Docker 发布。下方需要已启动服务的端到端 API 测试仍需单独运行。

```bash
flutter analyze
flutter test
flutter build web --release
docker compose config
```

端到端 API 测试在服务启动后执行：

```bash
CUE_TEST_URL=http://cue-web \
CUE_TEST_EMAIL=admin@cue.local \
CUE_TEST_PASSWORD='Cue-Local-2026!' \
docker run --rm --network cue_default \
  -v "$PWD/server:/app" -w /app node:22-alpine \
  node --test test/api.integration.test.mjs
```
