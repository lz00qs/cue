# Cue

English | [简体中文](README.zh.md)

Cue is a personal task manager you host yourself. It consists of a Web app, an API, and a PostgreSQL database, with Android, iOS, macOS, and Windows clients. Every client connects to your own Cue server; this project does not provide hosted accounts or a shared server.

Cue includes Today, Inbox, Upcoming, board, calendar, and priority quadrant views, with English and Chinese interfaces. Tasks sync across your devices and remain in your PostgreSQL data volume.

## First-time setup

You need Docker Engine and Docker Compose. Run these commands from the project root.

### 1. Configure the environment

```bash
cp .env.example .env
```

Edit `.env` and set at least:

- `POSTGRES_PASSWORD`: a database password.
- `CUE_JWT_SECRET` and `CUE_REFRESH_SECRET`: **different** random values, each at least 32 characters. Run `openssl rand -hex 32` twice to generate them.
- `CUE_ALLOW_SETUP=true`: enable this temporarily to create the first administrator.
- `CUE_BIND_ADDRESS=127.0.0.1`: keep initial setup accessible only from the host.

Create the administrator's email and password in the Web app; **do not put them in `.env`**.

On Linux, prepare a directory writable by the backup container before starting:

```bash
mkdir -p backups
sudo chown 999:999 backups
sudo chmod 700 backups
```

Docker file-sharing permissions can differ on macOS; check the backup logs and files after startup.

### 2. Start Cue and create the administrator

```bash
docker compose up -d
docker compose ps
curl -fsS http://localhost:8080/api/health
```

Open `http://localhost:8080` on the server and follow the setup screen. If the server has no browser, establish an SSH tunnel from your own computer and open the same address locally:

```bash
ssh -L 8080:127.0.0.1:8080 user@server
```

After creating the administrator, change `CUE_ALLOW_SETUP` back to `false` in `.env`, recreate the API container, and check its status:

```bash
docker compose up -d --no-deps --force-recreate cue-api
curl -fsS http://localhost:8080/api/auth/status
```

The response should include `"initialized":true` and `"setupAvailable":false`. Do not expose the initial HTTP setup port to the public internet.

### 3. Connect other devices

Use HTTPS for access over the internet. Put a valid certificate and private key for your domain at the paths set by `CUE_TLS_CERT_FILE` and `CUE_TLS_KEY_FILE` in `.env`. The defaults are `./certs/fullchain.pem` and `./certs/privkey.pem`. Then start the HTTPS entry point:

```bash
docker compose --profile https up -d
curl -fsS https://your-domain.example/api/health
```

`CUE_HTTPS_BIND_ADDRESS` defaults to `0.0.0.0` and `CUE_HTTPS_PORT` to `443`. The HTTP entry point remains bound to `127.0.0.1:8080`. If you use your own reverse proxy, serve the Web app and `/api` on the same domain; do not expose the API container or setup port directly to the internet.

Open your HTTPS URL in a browser. On first launch, native clients ask for the **server base URL**, such as `https://your-domain.example`, followed by the administrator credentials. Include `http://` or `https://`; do not enter an API container address. For HTTP testing on a trusted LAN, bind `CUE_BIND_ADDRESS` to a LAN address and recreate `cue-web`, then restore the loopback binding afterward. Use HTTPS on the internet.

## Operations

### Check and maintain the service

```bash
docker compose ps
docker compose logs -f cue-api
curl -fsS http://localhost:8080/healthz
curl -fsS http://localhost:8080/api/health
```

`CUE_WEB_PORT` controls the local HTTP port and `CUE_TIMEZONE` controls the default time zone. After changing service settings in `.env`, run `docker compose up -d --force-recreate` so the containers read them. Add `--profile https` if you enabled the HTTPS profile.

If you forget the administrator password, reset it on the server. You can append a new email address to the same command to change both:

```bash
docker compose exec cue-api npm run reset-password -- 'a-new-strong-password'
```

Before changing code or updating a deployment, confirm that you have a restorable backup. Then run `docker compose up -d`, or `docker compose --profile https up -d` if you use the HTTPS profile. `docker compose down` stops and removes containers but retains the database volume.

### Backup and restore

The `db-backup` service creates a backup at startup and then every hour. Files are stored under `./backups`. Confirm that the service is running and has produced a file:

```bash
docker compose ps db-backup
docker compose logs --tail=30 db-backup
ls -lh backups/last/cue-latest.sql.gz
```

Verify a backup by restoring it into an isolated, disposable PostgreSQL 17 container. The script does not connect to or change your running database:

```bash
bash scripts/verify-backup-restore.sh backups/last/cue-latest.sql.gz
```

For larger databases, set `CUE_RESTORE_TMPFS_SIZE=2g` to increase the verification container's temporary storage. Backups include accounts and tasks. Regularly copy them to protected storage outside the server so a disk failure does not destroy both the database and its backups.

To restore on a new server, use a **new, empty PostgreSQL volume**. Start only the database, then import the backup. These commands write to the target database; never run them against a database in use:

```bash
docker compose up -d cue-db
set -o pipefail
gzip -dc backups/last/cue-latest.sql.gz |
  docker compose exec -T cue-db sh -c 'psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"'
docker compose up -d
```

Before restoring, securely copy the matching project configuration, `.env`, and backup file to the destination server. Keep the passwords and JWT secrets in `.env` protected as well.

## Local development

The Web client calls same-origin `/api`; preview it through the Compose deployment above. The server disables cross-origin requests, so a separate Flutter Web development server cannot directly call the API on another port. For local native client development, you can preconfigure the server URL; on macOS, for example:

```bash
flutter pub get
flutter run -d macos --dart-define=CUE_API_URL=http://localhost:8080
```

An Android emulator can usually reach the host at `http://10.0.2.2:8080`; an iOS simulator can use `http://127.0.0.1:8080`. Physical devices need a reachable LAN address or HTTPS domain.

Useful checks:

```bash
flutter analyze
flutter test
(cd server && npm ci && npm test)
```

To report a security issue, see the [security policy](SECURITY.md). Cue is licensed under the [Apache License 2.0](LICENSE).
