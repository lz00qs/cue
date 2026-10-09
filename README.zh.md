# Cue

[English](README.md) | 简体中文

Cue 是一个供个人自行部署的任务管理应用。它由 Web 页面、API 和 PostgreSQL 数据库组成，另有 Android、iOS、macOS 和 Windows 客户端。所有客户端连接到你自己的 Cue 服务；项目不提供公共账号或托管服务器。

应用提供 Today、Inbox、Upcoming、看板、月历和四象限等视图，支持中文与英文界面。多个设备可以同步任务；数据保存在你部署的 PostgreSQL 数据卷中。

## 正式版与 Dev 下载

[最新正式版](https://github.com/lz00qs/cue/releases/latest)用于日常使用；测试 bug 修复时，在 [Releases](https://github.com/lz00qs/cue/releases) 中选择最新的 **Cue vX.Y.Z-dev.N** 预发布。Dev 提供 Android APK、已签名并公证的 macOS DMG、Windows 安装包。安装后会替换正式客户端，并沿用其配置；“关于 Cue”中的 Dev 标识、构建编号和 commit 可用于反馈问题。iOS 仍单独通过 App Store 分发，本流程仅检查其编译。

发布格式统一如下，提交号放在发布说明的「构建信息」中。

| 渠道 | Tag | 标题 |
| --- | --- | --- |
| 正式版 | `v1.0.1` | `Cue v1.0.1` |
| Dev | `v1.0.1-dev.1010` | `Cue v1.0.1-dev.1010` |

两条渠道的说明使用相同的「本版内容、获取与部署、构建信息、English」结构。正式版更新内容来自 `.github/release-notes/vX.Y.Z.md`；Dev 默认列出相对上一份 Dev（首次则相对正式版）的提交，也可用 `.github/release-notes/dev.md` 编写中文更新内容。

Dev 和正式版使用同一签名及递增构建编号。Android 无法直接覆盖安装构建编号更低的旧包；从 Dev 切回稳定渠道时，可等待后续正式版，或卸载后重装旧版并重新登录。

每份 Release 的 `docker-compose.yml` 都固定到该次 API/Web 镜像摘要，`release.json` 记录源码与构建信息，`SHA256SUMS` 可核对下载内容。对下载的文件运行 `shasum -a 256 文件名`，将结果与 `SHA256SUMS` 中对应的行比较。GHCR 的 `:dev` 指向最近发布的 Dev 镜像，`:latest` 指向正式渠道。测试客户端仍连接你配置的 Cue 服务；如需验证服务端变更，可用该 Dev Release 的部署文件部署测试服务。

### 维护者：发布 Dev

1. 先将发布工作流改动合入 `main`，再从更新后的 `main` 创建或同步 `dev`。在仓库 Settings → Environments 中确认 `android-release` 和 `macos-release` 的 Deployment branches and tags 允许 **dev 分支**及现有正式/演练 tag。沿用已有签名 secrets 和变量；若环境配置了人工审批，每次构建仍需审批。
2. bug 修复合入 `dev` 后只运行 CI，不编译发布包。在 Actions → Release → Run workflow 中选择 `dev`。**内测**时勾选 `build_only`，再选择 `platform`：`all`、`android`、`macos`、`windows`、`ios` 或 `docker`。所选平台的 Android、已公证 macOS 和 Windows 安装包保存在本次运行的 **Artifacts** 中，保留 7 天；iOS 仅检查编译，Docker 默认仅检查 API/Web 镜像。选择 `all` 时，内测 Docker 与客户端并行构建。不创建 Git 标签或 GitHub Release；默认不推送 GHCR 镜像。下载对应的 Artifact ZIP 并解压取得安装包。需要公开的 Dev 预发布时，`build_only` 和 `windows_only` 都不勾选，保持 `platform=all`。已有 `windows_only` 仍可在 `main` 或 `dev` 上仅验证 Windows、不发布；使用它时保持 `platform=all`。同一模式、同一目标的连续运行会取消旧构建；不同内测平台与公开发布分别运行。发布前仍会检查构建提交与 `dev` 当前提交一致。
3. 全部客户端检查、签名、公证与 Docker 构建成功后，先上传并校验完整附件，再公开 Release。正式版 Latest 不受 Dev 影响。保留最近 10 个本流程管理的 Dev Release，Actions 临时产物保留 7 天。已公开版本的重跑会被拒绝；新的 Dev 构建请启动新的 workflow run。清理不删除 GHCR 历史镜像，旧镜像可按需另行管理。
4. 验证通过后合入 `main`，更新版本并推送对应 `vX.Y.Z` tag 发布正式版；随后同步回 `dev`。完整的正式版演练仍使用 `vX.Y.Z-dryrun` tag 手动运行；`main` 上的 `windows_only` 仍只验证安装器。

需要在服务器内测 Docker 时，选择 `dev`、勾选 `build_only`、设置 `platform=docker`（或 `all`），再勾选 `push_dev_images`。API/Web 镜像会推送到 GHCR，标签为 `dev-构建编号-12位commit`；不会创建 Release，也不会更新公开 Dev 的 `:dev` 或正式版的 `:latest`。本次运行的 Docker job Summary 列出镜像地址与摘要，**Artifacts → cue-dev-deployment** 提供固定摘要的 `docker-compose.yml`、`example.env`、`release.json` 和 `SHA256SUMS`，保留 7 天。服务器上解压部署附件，按首次部署说明配置 `.env`（已有服务保留现有 `.env`），然后运行 `docker compose pull cue-api cue-web` 和 `docker compose up -d`；启用 HTTPS 的部署加上 `--profile https`，并保留现有 TLS 配置。镜像沿用现有 GHCR 包的访问权限，内测推送并不增加下载权限隔离。

正式版和 Dev 共用 `.github/workflows/release.yml` 的 `run_number`，平台构建编号为 `1000 + run_number`，重跑保持原编号。不要重命名该入口或为两条渠道分别计算编号；Windows 的编号上限为 65535。平台版本继续使用 `pubspec.yaml` 的数字版本，Dev 后缀只用于发布名称、文件名和应用内标识。

Flutter SDK 缓存按系统、架构和 SDK 版本共用；Linux CI 预先准备 Android 引擎，Apple 构建预先准备 iOS/macOS 引擎，减少重复的完整 SDK 缓存。Pub 依赖按 lockfile 区分；Android 还缓存 Gradle 依赖与可复用的构建任务结果，Docker API/Web 使用各自的 BuildKit 缓存。首次运行填充缓存，后续兼容的构建复用缓存。macOS 先生成 Flutter 配置，再仅做一次通用架构 Xcode 归档。缓存保存构建工具和依赖，签名安装包仍保存为 Actions Artifacts。工作流不会调高仓库的缓存容量上限。

内测构建也沿用这套编号。当前仓库公开，登录 GitHub 且有仓库读取权限的用户可以下载 Actions Artifacts（见 [GitHub 说明](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/download-workflow-artifacts)）。如需将下载权限限定到指定内测人员，应使用私有仓库或有访问控制的独立分发服务。

如果旧构建完成前已有更高编号的版本公开，流程会拒绝发布旧编号。Dev 可手动启动新 run；尚未公开的正式版可在 Run workflow 中选择原 `vX.Y.Z` tag 并勾选 `publish_stable`，分配新编号，无需修改 tag。若附件已公开而 Docker 渠道别名更新失败，重跑失败的 release job 会核对原附件后继续更新别名，不改写公开版本。

GitHub 的默认 `GITHUB_TOKEN` 无法为相对默认分支含工作流改动的提交创建/更新 Release。因此修改 `.github/workflows/` 时，先合入 `main` 再同步到 `dev`；普通 bug 修复不需要额外 token。

## 首次部署

需要 Docker Engine 和 Docker Compose 插件（`docker compose`，v2 或更新版本）。不支持旧版 `docker-compose` 或 Swarm 部署。以下命令在项目根目录执行。

### 1. 配置环境变量

```bash
cp .env.example .env
```

编辑 `.env`，至少修改：

- `POSTGRES_PASSWORD`：数据库密码。
- `CUE_JWT_SECRET` 和 `CUE_REFRESH_SECRET`：两个**不同**的随机值，每个至少 32 个字符。可以分别运行两次 `openssl rand -hex 32` 生成。
- `CUE_ALLOW_SETUP=true`：仅在首次创建管理员时临时开启。
- `CUE_BIND_ADDRESS=127.0.0.1`：首次建号期间保持本机监听。

管理员邮箱和密码在网页中创建，**不要写进 `.env`**。

Linux 首次启动前，为备份容器准备一个**全新的空目录**。以下命令使用默认备份 UID/GID `999:999`：

```bash
mkdir -p backups
sudo chown 999:999 backups
sudo chmod 700 backups
```

自定义 UID/GID 或使用已有目录时，请参阅[备份目录权限](#备份目录权限)。macOS 的 Docker 文件共享权限可能不同；启动后需检查备份日志和实际文件。

### 2. 启动并创建管理员

```bash
docker compose up -d
docker compose ps
curl -fsS http://localhost:8080/api/health
```

在服务器本机打开 `http://localhost:8080`，按页面提示创建管理员。如果服务器没有浏览器，可先在自己的电脑建立 SSH 隧道，再访问本机的同一地址：

```bash
ssh -L 8080:127.0.0.1:8080 user@server
```

建号完成后，把 `.env` 中的 `CUE_ALLOW_SETUP` 改回 `false`，重新创建 API 容器并检查状态：

```bash
docker compose up -d --no-deps --force-recreate cue-api
curl -fsS http://localhost:8080/api/auth/status
```

响应应包含 `"initialized":true` 和 `"setupAvailable":false`。不要将用于首次建号的 HTTP 端口直接暴露到公网。

### 3. 让其他设备访问

跨公网访问应使用 HTTPS。将自己域名对应的有效证书和私钥放在 `.env` 指定的 `CUE_TLS_CERT_FILE`、`CUE_TLS_KEY_FILE` 路径；默认路径为 `./certs/fullchain.pem` 和 `./certs/privkey.pem`。然后启动 HTTPS 入口：

```bash
docker compose --profile https up -d
curl -fsS https://your-domain.example/api/health
```

`CUE_HTTPS_BIND_ADDRESS` 默认是 `0.0.0.0`，`CUE_HTTPS_PORT` 默认是 `443`。HTTP 入口仍只绑定 `127.0.0.1:8080`。如使用自己的反向代理，请让 Web 和 `/api` 经同一域名访问，并保持 API 与初始化端口不直接暴露公网。

浏览器访问自己的 HTTPS 地址。原生客户端首次打开时，填写**服务基础地址**，例如 `https://your-domain.example`，然后使用管理员账号登录。地址须包含 `http://` 或 `https://`；不要填单独的 API 容器地址。可信局域网调试如需使用 HTTP，可把 `CUE_BIND_ADDRESS` 设为局域网监听地址并重新创建 `cue-web`，用完后恢复本机监听；公网应使用 HTTPS。

## 日常维护

### 检查服务

```bash
docker compose ps
docker compose logs -f cue-api
curl -fsS http://localhost:8080/healthz
curl -fsS http://localhost:8080/api/health
```

默认 HTTP 端口由 `CUE_WEB_PORT` 控制，时区由 `CUE_TIMEZONE` 控制。修改 `.env` 中的服务配置后，使用 `docker compose up -d --force-recreate` 让容器读取新值；启用了 HTTPS profile 时，在命令中加上 `--profile https`。

忘记管理员密码时，可在服务器上重置；如需同时更换邮箱，在命令末尾再添加新邮箱：

```bash
docker compose exec cue-api npm run reset-password -- '新的强密码'
```

更改代码或更新部署前，先确认备份可恢复，再执行 `docker compose up -d`；启用了 HTTPS profile 的部署使用 `docker compose --profile https up -d`。`docker compose down` 会停止并删除容器，但保留数据库卷。

### 备份与恢复

Compose 中的 `db-backup` 服务启动后立即备份一次，此后每小时备份。文件存放在项目的 `./backups` 目录，保留策略仍为过去 24 小时的每小时备份、7 天的每日备份、4 周的每周备份和 3 个月的每月备份。先确认它确实在运行且已产生**近期**文件（修改过 `POSTGRES_DB` 时，将下面的 `cue` 替换为实际数据库名）：

```bash
docker compose ps -a
docker compose logs --tail=30 db-backup
ls -lh backups/last/cue-latest.sql.gz
gzip -t backups/last/cue-latest.sql.gz
```

可用隔离的一次性 PostgreSQL 17 容器验证备份能否还原；脚本不会连接或修改当前数据库：

```bash
bash scripts/verify-backup-restore.sh backups/last/cue-latest.sql.gz
```

数据库较大时，可通过 `CUE_RESTORE_TMPFS_SIZE=2g` 增加验证容器的临时空间。备份包含账号和任务，需定期复制到服务器之外的受保护存储，避免数据库与备份同时丢失。

需要在新服务器恢复时，使用**全新的空数据库卷**，先只启动数据库，再导入备份。下面的命令会把备份写入目标数据库；不要对正在使用的数据库执行：

```bash
docker compose up -d cue-db
set -o pipefail
gzip -dc backups/last/cue-latest.sql.gz |
  docker compose exec -T cue-db sh -c 'psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"'
docker compose up -d
```

执行恢复前，应将同一份项目配置、`.env` 和备份文件安全地复制到目标服务器。`.env` 中的密码和 JWT 密钥也需要妥善保存。

#### 备份目录权限

`CUE_UID`、`CUE_GID` 只作用于 `db-backup`，未设置或为空时均默认为 `999`，与 Debian 备份镜像的 PostgreSQL 用户一致。它们是 **Linux 数字用户 ID 和组 ID，不是用户名**；容器内无需存在对应账号。请使用非 root UID。设置变量**不会自动改变**宿主机目录的所有权、权限或 ACL，也不会改变 PostgreSQL 数据卷。

普通 Linux 环境中，先检查账号和目录：

```bash
id
id -u
id -g
ls -ldn ./backups
```

例如，准备使用的备份账号是 `1000:1000`，在 `.env` 中配置下面的值，并由该账号创建备份目录：

```ini
CUE_UID=1000
CUE_GID=1000
```

Synology DSM 环境中，通过 SSH 以准备使用的账号运行 `id`，在部署目录（例如 `/volume1/docker/cue`）运行 `ls -ldn ./backups`。如果实际 UID 为 `1026`、GID 为 `100`，配置为：

```ini
CUE_UID=1026
CUE_GID=100
```

上述数值仅为示例，请以自己的账号为准。还需检查 DSM 控制面板 / File Station 的共享文件夹权限和继承 ACL：即使 Unix 权限位看起来正确，DSM ACL 仍可能拒绝访问。Unraid 也应按实际账号和备份共享目录检查。备份目录必须支持 POSIX 硬链接与符号链接；SMB/CIFS、FAT、exFAT 等挂载可能不适用。建议先写入本地 Linux 文件系统，再将完成的备份复制到远端存储。

`db-backup` 每次启动时，都在备份容器内部使用其配置的 UID/GID 和 `./backups:/backups` 挂载执行权限检查。它检查目录能否进入、实际创建和删除文件、硬链接和符号链接，也检查已有的 `last`、`daily`、`weekly`、`monthly` 子目录。仅创建随机命名的临时测试目录和文件，在成功或可处理的失败退出时清理，不修改已有备份。检查成功后，同一容器继续运行镜像原有的备份调度器，正常部署不会产生独立预检容器完成后退出的事件，避免群晖 Container Manager 因该事件告警。API/Web 的依赖关系保持不变。

检查失败时，日志输出路径、容器实际 UID/GID 和原因；备份调度器不会启动，容器保持运行并显示 `unhealthy`，不会反复退出和重启。修复权限后，重新创建 `db-backup` 再次检查。`docker compose up -d` 此时仍可能返回成功，因此必须检查容器健康状态和日志。健康检查每 10 秒检查调度器；仅显示健康不能证明数据库备份成功。

单独运行权限检查（不会启动数据库或备份调度器），或查看启动检查失败原因：

```bash
docker compose run --rm --no-deps -e CUE_BACKUP_CHECK_ONLY=true db-backup
docker compose ps -a
docker compose logs --tail=50 db-backup
ls -ldn ./backups ./backups/last ./backups/daily ./backups/weekly ./backups/monthly
```

手动检查成功时退出码为 0，失败时非零退出；DSM 可能对此次手动诊断的正常停止发出通知。正常部署中的备份容器会继续运行。首次备份前，部分轮转子目录可能尚不存在。`Permission denied` 表示需要检查日志指出的目录；链接检查中的 `Operation not supported` 通常表示文件系统或挂载不适用。已有实例如处于重启循环，先执行 `docker compose stop db-backup`。优先配置已有目录所属且有访问权限的 UID/GID。如确实需要修改所有权，先保留备份并逐个核对受影响路径，再做定点修改，例如：

```bash
# 仅为示例：使用自己实际配置的 UID/GID。
sudo chown 1026:100 ./backups
sudo chmod u+rwx ./backups
```

只对预检报错的具体轮转目录按需重复定点修复；备份日志仍报错时，再检查已有文件权限。DSM 还需在系统界面修复相应 ACL。不要使用 `chmod -R 777`，不要未经核对递归修改所有权，也不要为了修复备份权限删除 PostgreSQL 数据卷。

升级已有实例时，保留原 `.env`、备份目录和数据库卷；更新部署文件，并按需补充 `CUE_UID` / `CUE_GID`。先确认已有备份可恢复，再执行：

```bash
docker compose stop db-backup
docker compose config --quiet
docker compose pull
docker compose run --rm --no-deps -e CUE_BACKUP_CHECK_ONLY=true db-backup
docker compose up -d --force-recreate db-backup
docker compose up -d --remove-orphans
docker compose ps -a
docker compose logs --tail=50 db-backup
ls -lh backups/last/cue-latest.sql.gz
gzip -t backups/last/cue-latest.sql.gz
```

任一步预检失败时，停止后续操作并先修复。从旧配置升级时，`--remove-orphans` 会清理本 Compose 项目中已移除的 `backup-permissions-check` 容器。启用了 HTTPS 的实例，在 `pull` 和最后的 `up` 命令中加上 `--profile https`。此次升级**绝对不要使用 `docker compose down -v`**，该命令会删除数据库卷。确认最新备份的时间戳持续更新，并执行上文的隔离恢复验证；仅调度器健康不能证明数据库备份成功。

保留 `db-backup` 原有的 `restart: always`，让调度器异常和宿主机重启后仍能自动恢复。每次容器启动，包括 `start`、`restart` 或 Docker daemon 自动重启，都先检查权限，再启动调度器。权限阻塞时，容器保持 `unhealthy`，需修复后重新启动；不会循环重试或反复输出相同错误。正常备份错误仍记录在日志中，需要同时监控最新文件时间。启动检查不会持续探测后续权限变化或 NAS 故障；清理过程中被强制终止或失去访问权限，可能遗留临时测试目录，应按诊断核对后只删除日志指出的临时测试路径。

## 本地开发

Web 客户端请求同源的 `/api`，可用上面的 Compose 部署预览。服务端关闭了跨域访问，因此单独启动的 Flutter Web 开发服务器不能直接访问另一端口上的 API。原生客户端本地运行时，可预先指定服务地址；例如在 macOS 上：

```bash
flutter pub get
flutter run -d macos --dart-define=CUE_API_URL=http://localhost:8080
```

Android 模拟器访问宿主机通常使用 `http://10.0.2.2:8080`；iOS 模拟器可使用 `http://127.0.0.1:8080`。真机需要能访问服务器的局域网地址或 HTTPS 域名。

常用检查：

```bash
flutter analyze
flutter test
(cd server && npm ci && npm test)
```

发现安全问题请参阅 [安全政策](SECURITY.zh.md)。项目采用 [Apache License 2.0](LICENSE)。
