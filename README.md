# Cue

Cue 是一个单用户任务管理应用。客户端使用 Flutter 支持 Android、iOS、Web 与桌面端，服务端使用 NestJS，数据持久化到 PostgreSQL；移动端 UI 对齐 Cue Figma V2 设计，提供列表、看板、月历和四象限四种任务投影。

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
