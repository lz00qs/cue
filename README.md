# Cue

English | [简体中文](README.zh.md)

[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
<!-- TODO: Add CI/CD status badges here -->

Cue is a single-user task management application. The client is built with Flutter, supporting Android, iOS, Web, and Desktop. The backend uses NestJS with PostgreSQL for data persistence. The mobile UI is aligned with the Cue Figma V2 design, offering four task projections: List, Kanban, Monthly Calendar, and Priority Quadrants.

## Screenshots

<!-- TODO: Replace with real screenshot URLs -->
<!-- <p align="center">
  <img src="docs/assets/screenshot-today.png" width="200" />
  <img src="docs/assets/screenshot-kanban.png" width="200" />
  <img src="docs/assets/screenshot-calendar.png" width="200" />
  <img src="docs/assets/screenshot-quadrants.png" width="200" />
</p> -->

## Features

- **Secure Authentication**: Initial setup requires a temporary `CUE_ALLOW_SETUP` toggle on localhost. Credentials are securely hashed with bcrypt and stored in PostgreSQL, never in `.env`.
- **CLI Password Reset**: Server-side CLI tool available for quick password resets.
- **Session Management**: 15-minute Access Tokens, 30-day single-use Refresh Tokens with automatic client-side refreshing. Remote logout revokes active device sessions.
- **Account Settings**: Update email and password across Web, Desktop, and Mobile clients (requires current password verification).
- **Database & Migrations**: Automated PostgreSQL migrations on startup. Clean databases do not write sample tasks by default.
- **Task Management**: Create, read, update status/priority, and soft-delete tasks. Only P0 tasks are considered "Important".
- **Optimistic Concurrency Control**: Each task includes a `version` field to handle concurrent edits safely.
- **Incremental Sync**: Global `revision` tracking and deletion tombstones.
- **Rich Views**: Today, Inbox, Upcoming, All Tasks, Kanban, Month Calendar, and Priority Quadrants.
- **Robust Client**: Flutter optimistic updates, failure rollbacks, and seamless session recovery.
- **Multi-device Sync**: Server-Sent Events (SSE) push notifications, auto-reconnect, 1-minute fallback polling, foreground sync, pull-to-refresh, and manual sync.
- **Conflict Resolution**: Concurrent sync request batching and automatic server-state recovery upon 409 version conflicts.
- **Figma V2 UI**: Mobile UI covers Today, Board, Calendar, Quadrants, Settings, and Task Detail interactions.
- **Localization**: English and Chinese interfaces, localized date formats, follows system language with in-app toggles.
- **Reverse Proxy & SPA**: Nginx reverse proxy for `/api`, secure response headers, and SPA routing.
- **Containerized Environment**: Docker Compose orchestrates Web, API, and PostgreSQL using named volumes.
- **OpenAPI Documentation**: Available at `/api/docs` (disabled in production).

## Configuration

Copy the environment template and modify the database password and JWT secrets:

```bash
cp .env.example .env
```

Configure the database password, two distinct random JWT secrets (at least 32 characters each), and the first-time setup toggle in `.env`. **Do not store admin accounts or passwords in `.env`**.

`CUE_ALLOW_SETUP` defaults to `false`. When initializing a fresh database, keep `CUE_BIND_ADDRESS=127.0.0.1` and temporarily set the setup toggle to `true` to create an admin account via the local web interface. Once done, revert it to `false`, recreate the API container, and then open the public HTTPS entry.

Passwords must be at least 8 characters and no more than 72 UTF-8 bytes to prevent bcrypt silent truncation.

### Forgot Admin Password

If you forget the admin password, reset it directly via the host CLI:

```bash
docker compose exec cue-api npm run reset-password -- <new-password>
# You can also change the email simultaneously:
# docker compose exec cue-api npm run reset-password -- <new-password> <new-email>
```

PostgreSQL uses `CUE_TIMEZONE=Asia/Shanghai` by default; modify this in `.env` for other regions.

## Docker Deployment

```bash
docker compose up --build -d
```

During the initial setup, ensure `CUE_BIND_ADDRESS=127.0.0.1` and `CUE_ALLOW_SETUP=true` are set in `.env`. Open `http://localhost:8080` on the server's local machine to create the admin account. Do not expose port 443 or bind the HTTP port to the public internet during this step. (Use SSH port forwarding if the server lacks a browser: `ssh -L 8080:127.0.0.1:8080 user@server`).

After successful creation, set `CUE_ALLOW_SETUP=false` in `.env` and execute:

```bash
docker compose up -d --no-deps --force-recreate cue-api
curl -fsS http://localhost:8080/api/auth/status
```

The status should include `"initialized":true` and `"setupAvailable":false`.

### HTTPS Configuration

Map `CUE_HTTPS_BIND_ADDRESS` and certificates in `.env`, then start the HTTPS profile:

```bash
docker compose --profile https up --build -d
```

### Quick Backend Updates

When only modifying backend code, use the included cross-platform script to rebuild and hot-swap containers without downtime:

```bash
./scripts/rebuild-backend.sh
# Windows: scripts\rebuild-backend.cmd
# Dart: dart run tool/rebuild_backend.dart
```

### Database Backup and Migration

Cue's `docker-compose.yml` includes a `db-backup` container that automatically performs frequent full logical backups of the PostgreSQL database. The compressed backups (`.sql.gz`) are stored in the host's `./backups` directory.

**Smart Backup Rotation Strategy:**
- **Hourly:** Retains the last 24 hours (configured via `BACKUP_KEEP_MINS=1440`).
- **Daily:** Retains the last 7 days.
- **Weekly:** Retains the last 4 weeks.
- **Monthly:** Retains the last 3 months.
*(Files spanning multiple periods are hardlinked to minimize disk usage.)*

**Migration and Restore Steps:**

1. Copy the code and `./backups` directory to the new server.
2. Start only the database service initially to avoid new data writes:
   ```bash
   docker compose up -d cue-db
   ```
3. Import the latest backup file (replace `cue-20260924.sql.gz` with the actual filename):
   ```bash
   gunzip -c ./backups/daily/cue-20260924.sql.gz | docker compose exec -T cue-db psql -U cue -d cue
   ```
4. Once restored, start all services:
   ```bash
   docker compose up -d
   ```

## Local Development

The Web client defaults to the same-origin `/api`. If the Flutter dev server and API are on different origins, specify the URL:

```bash
flutter run -d chrome --dart-define=CUE_API_URL=http://localhost:8080
```

Mobile and desktop apps will display a server connection screen on first launch. You can also preset it during the build:

```bash
flutter run -d android --dart-define=CUE_API_URL=http://10.0.2.2:8080
flutter run -d ios --dart-define=CUE_API_URL=http://127.0.0.1:8080
```

Set the initial theme:
```bash
flutter run -d macos --dart-define=CUE_THEME=dark
```

### Seeding Test Data

Generate traceable random tasks for UI testing (must run with `CUE_ALLOW_DEMO_DATA=true`):

```bash
docker compose exec -e CUE_ALLOW_DEMO_DATA=true cue-api \
  npm run demo:seed -- --batch ui-test-01 --count 50
```

Clear demo data:

```bash
docker compose exec -e CUE_ALLOW_DEMO_DATA=true cue-api \
  npm run demo:clear -- --batch ui-test-01
```

## Validation & Testing

```bash
flutter analyze
flutter test
flutter build web --release
```

End-to-end API tests:

```bash
CUE_TEST_URL=http://cue-web \
CUE_TEST_EMAIL=admin@cue.local \
CUE_TEST_PASSWORD='Cue-Local-2026!' \
docker run --rm --network cue_default \
  -v "$PWD/server:/app" -w /app node:22-alpine \
  node --test test/api.integration.test.mjs
```

## Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

## Security

Please report security issues privately. Do not open a public issue. See [SECURITY.md](SECURITY.md) for more details.

## License

[Apache License 2.0](LICENSE)
