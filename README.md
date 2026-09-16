# Cue

Cue 是一个单用户任务管理应用。客户端使用 Flutter 支持 Android、iOS、Web 与桌面端，服务端使用 NestJS，数据持久化到 PostgreSQL；移动端 UI 对齐 Cue Figma V2 设计，提供列表、看板、月历和四象限四种任务投影。

## 已实现

- 单管理员登录，无注册、邀请或多用户入口
- 15 分钟 Access Token、30 天 Refresh Token 与客户端自动刷新
- PostgreSQL 持久化、启动时自动迁移和首次示例数据
- 任务新增、读取、状态/重要性更新、软删除
- 乐观并发控制：每条任务包含 `version`
- 增量同步基础：全局 `revision` 与删除 tombstone
- Today、Inbox、Upcoming、All Tasks、Kanban、Month Calendar、Eisenhower Quadrants
- Flutter 乐观更新、失败回滚和登录会话恢复
- 多端增量同步：12 秒后台轮询、回到前台同步、下拉刷新和手动同步
- 并发同步请求合并，以及 409 版本冲突后的服务端状态恢复
- Figma V2 移动端 Today、Board、Calendar、Quadrants、Settings 和任务详情交互
- Nginx 同源 `/api` 反向代理、安全响应头和 SPA 路由
- Docker Compose 编排 Web、API、PostgreSQL，数据库使用命名卷
- OpenAPI 文档：登录后可在 `/api/docs` 查看接口结构

## 配置

复制环境变量模板并修改所有密码和密钥：

```bash
cp .env.example .env
```

本地部署已生成一份被 Git 忽略的 `.env`。默认测试账号：

```text
admin@cue.local
Cue-Local-2026!
```

不要将这组本地凭据用于公网部署。公网部署前请使用长随机密码和两个独立随机 JWT 密钥，并在外层反向代理启用 HTTPS。

任务种子数据和 PostgreSQL 默认使用 `CUE_TIMEZONE=Asia/Shanghai`；部署到其他地区时可在 `.env` 修改。

如果不希望保存明文登录密码，可生成 bcrypt 哈希写入 `CUE_ADMIN_PASSWORD_HASH`，并清空 `CUE_ADMIN_PASSWORD`。

## Docker 部署

```bash
flutter pub get
flutter build web --release
docker compose up --build -d
```

浏览器打开 [http://localhost:8080](http://localhost:8080)。端口默认只绑定 `127.0.0.1`，不会直接暴露到局域网。

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

## 本地开发

Web 默认请求同源 `/api`。如果 Flutter 开发服务器和 API 不同源，可在构建或运行时指定完整地址：

```bash
flutter run -d chrome --dart-define=CUE_API_URL=http://localhost:8080
```

原生移动端首次启动会先显示服务器连接页。输入所有设备共用的 Cue 服务基础地址，App 会通过 `/api/health` 验证后保存；`/api` 后缀可省略。之后可在 `Settings → Import & sync → Change server` 修改地址，切换服务器时会清除旧服务器的登录令牌。

Android 模拟器访问宿主机使用 `10.0.2.2`，iOS 模拟器使用 `127.0.0.1`；真机使用电脑的局域网地址或可访问的 HTTPS 域名。`CUE_API_URL` 仍可作为预配置默认值：

```bash
flutter run -d android --dart-define=CUE_API_URL=http://10.0.2.2:8080
flutter run -d ios --dart-define=CUE_API_URL=http://127.0.0.1:8080
flutter build apk --release --dart-define=CUE_API_URL=https://cue.example.com
flutter build ipa --release --dart-define=CUE_API_URL=https://cue.example.com
```

移动端允许连接可信局域网内的 HTTP 服务；公网部署应使用 HTTPS。只要移动端、Web 和桌面端使用同一 API 与数据库，任务修改会通过全局 `revision` 增量同步，并通过每条任务的 `version` 检测并发写入。

后端位于 `server/`。容器启动时先执行 `server/migrations/001_initial.sql`，再启动 API。

## 验证

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
