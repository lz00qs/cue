# Cue

[English](README.md) | 简体中文

Cue 是一个供个人自行部署的任务管理应用。它由 Web 页面、API 和 PostgreSQL 数据库组成，另有 Android、iOS、macOS 和 Windows 客户端。所有客户端连接到你自己的 Cue 服务；项目不提供公共账号或托管服务器。

应用提供 Today、Inbox、Upcoming、看板、月历和四象限等视图，支持中文与英文界面。多个设备可以同步任务；数据保存在你部署的 PostgreSQL 数据卷中。

## 首次部署

需要 Docker Engine 和 Docker Compose。以下命令在项目根目录执行。

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

Linux 首次启动前，为备份容器准备目录：

```bash
mkdir -p backups
sudo chown 999:999 backups
sudo chmod 700 backups
```

macOS 的 Docker 文件共享权限可能不同；启动后需检查备份日志和实际文件。

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

Compose 中的 `db-backup` 服务启动后立即备份一次，此后每小时备份。文件存放在项目的 `./backups` 目录。先确认它确实在运行且已产生文件：

```bash
docker compose ps db-backup
docker compose logs --tail=30 db-backup
ls -lh backups/last/cue-latest.sql.gz
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
