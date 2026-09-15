# Cue

Cue 是一个单用户任务管理应用。客户端使用 Flutter Web，服务端使用 NestJS，数据持久化到 PostgreSQL；UI 参考 Cue Figma 设计，提供列表、看板、月历和四象限四种任务投影。

## 已实现

- 单管理员登录，无注册、邀请或多用户入口
- 15 分钟 Access Token、30 天 Refresh Token 与客户端自动刷新
- PostgreSQL 持久化、启动时自动迁移和首次示例数据
- 任务新增、读取、状态/重要性更新、软删除
- 乐观并发控制：每条任务包含 `version`
- 增量同步基础：全局 `revision` 与删除 tombstone
- Today、Inbox、Upcoming、All Tasks、Kanban、Month Calendar、Eisenhower Quadrants
- Flutter 乐观更新、失败回滚和登录会话恢复
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
