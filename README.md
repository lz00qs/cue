# Cue

English | [简体中文](README.zh.md)

[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
<!-- TODO: Add CI/CD status badges here -->

Cue is a single-user task management application. The client is built with Flutter, supporting Android, iOS, Web, and Desktop. The backend uses NestJS with PostgreSQL for data persistence. The mobile UI is aligned with the Cue Figma V2 design, offering four task projections: List, Kanban, Monthly Calendar, and Priority Quadrants.

## For self-hosted users

Cue does not provide hosted accounts or a shared server. Each user runs the Web app, API, and PostgreSQL from this repository on their own machine or server, then connects their mobile and desktop clients to that server. Data stays in the user's PostgreSQL volume. Keep the server and clients on the same release version.

1. Choose a version on [GitHub Releases](https://github.com/lz00qs/cue/releases). Download its source archive or clone this repository and check out the matching `vX.Y.Z` tag. Follow [Docker Deployment](#docker-deployment) on your server, replacing the example database password and both JWT secrets in `.env`.
2. Create the administrator account only from the server's local Web page or through an SSH tunnel, then turn `CUE_ALLOW_SETUP` off. For access from other devices, configure a valid TLS certificate and the HTTPS entry point. Do not expose the initial setup HTTP port to the public internet.
3. Open your own HTTPS URL in a browser. Download the macOS DMG, Windows installer, or Android APK from the matching GitHub Release. The developer distributes the iOS client separately through the App Store; **the GitHub Release does not contain an installable iOS `.app` ZIP**. On first launch, enter your own server's base URL, such as `https://tasks.example.com`, then sign in with the administrator account you created.
4. Check that `cue-db`, `cue-api`, `cue-web`, and `db-backup` are running with `docker compose ps`, and verify a backup as described in [Database Backup and Migration](#database-backup-and-migration). Save a restorable backup before upgrading the server.

Trusted LAN testing can use HTTP as described below; internet access should use HTTPS. Check the App Store listing separately for iOS availability.
Official releases also publish the API and Web Docker images as `ghcr.io/lz00qs/cue/cue-api:X.Y.Z` and `ghcr.io/lz00qs/cue/cue-web:X.Y.Z`. The Compose command below builds from the matching source version, so pulling those images is optional.

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
Run `openssl rand -hex 32` twice and use the two different values for `CUE_JWT_SECRET` and `CUE_REFRESH_SECRET`; choose a separate strong database password.

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

On Linux, prepare the backup directory before the first start (the backup container uses UID/GID `999:999`):

```bash
mkdir -p backups && sudo chown 999:999 backups && sudo chmod 700 backups
```

macOS Docker file-sharing permissions may differ; check `docker compose logs db-backup` after starting and confirm that a backup file exists.

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

Cue's `docker-compose.yml` includes a `db-backup` container. `docker compose up --build -d` starts it, creates one backup immediately, and then backs up the database every hour. The compressed SQL files are stored in the host's ignored `./backups` directory. If you started only selected services, run `docker compose up -d db-backup`.

Check the service and latest backup, then rehearse a restore in an isolated, disposable PostgreSQL 17 container (requires Bash and Docker):

```bash
docker compose ps db-backup
ls -lh backups/last/cue-latest.sql.gz
bash scripts/verify-backup-restore.sh backups/last/cue-latest.sql.gz
```

The verification script does not connect to the running Cue database or modify its volume. Backups contain accounts and tasks. Regularly copy them to independent, protected storage so a server disk failure does not destroy both the database and its backups.
If the database grows beyond the script's default 512 MiB temporary space, set `CUE_RESTORE_TMPFS_SIZE=2g` when running the restore check.

**Smart Backup Rotation Strategy:**
- **Hourly:** Retains the last 24 hours (configured via `BACKUP_KEEP_MINS=1440`).
- **Daily:** Retains the last 7 days.
- **Weekly:** Retains the last 4 weeks.
- **Monthly:** Retains the last 3 months.
*(Files spanning multiple periods are hardlinked to minimize disk usage.)*

**Migration and Restore Steps:**

1. Copy the code and `./backups` directory to the new server.
2. Start only the database service with a **new, empty PostgreSQL volume** to avoid migrations or new writes:
   ```bash
   docker compose up -d cue-db
   ```
3. Import the latest backup. The following command is only for an empty database; do not import over a running Cue database:
   ```bash
   set -o pipefail
   gunzip -c ./backups/last/cue-latest.sql.gz | docker compose exec -T cue-db psql -v ON_ERROR_STOP=1 -U cue -d cue
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

### Android Release Signing

Release APKs require the long-lived Cue signing keystore; the build fails instead of falling back to a debug key when it is missing. Keep the keystore and its password outside the repository, back up both securely, and reuse the same key for every direct-download APK update. A previously installed debug-signed build cannot be updated in place with the release-signed APK.

For a local build, point `CUE_ANDROID_SIGNING_PROPERTIES` at a private Java properties file (or place it at the ignored `android/key.properties` path):

```properties
storeFile=/absolute/path/to/cue-release.p12
storePassword=<keystore-password>
keyAlias=cue-release
keyPassword=<key-password>
```

```bash
CUE_ANDROID_SIGNING_PROPERTIES=/absolute/path/to/key.properties flutter build apk --release
```

The GitHub release workflow uses the `android-release` environment on version tags and expects two environment secrets: `CUE_ANDROID_KEYSTORE_BASE64` (the single-line Base64 encoding of the same keystore) and `CUE_ANDROID_STORE_PASSWORD` (the keystore and key password). It verifies the built APK against the public certificate fingerprint in `android/release-cert.sha256` before uploading it. The current PKCS#12 keystore uses the same password for the store and key.

### iOS App Store distribution

CI checks that the iOS source builds without signing. An unsigned `.app` ZIP is not an installable user release and is not attached to GitHub Releases. As with [Immich's mobile distribution](https://docs.immich.app/install/post-install/), users should obtain the iOS client through the App Store (or TestFlight while testing) and connect it to their own Cue server.

The developer creates an iOS app record in App Store Connect for bundle ID `top.hylcreative.cue`, configures an **Apple Distribution** certificate and App Store signing in Xcode, updates the version and build number in `pubspec.yaml`, and runs `flutter pub get` followed by `flutter build ipa --release` on a Mac. Upload the signed IPA with Xcode Organizer or Transporter, test it in TestFlight, and submit it for App Review. Use a new build number for each upload. See the [Flutter iOS release guide](https://docs.flutter.dev/deployment/ios) and [Apple's build upload guide](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds). The macOS DMG uses a different Developer ID certificate.

Before submission, add accurate app details, screenshots, support contact information, a [privacy policy URL and data collection disclosures](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy) in App Store Connect. Because Cue requires a self-hosted server and login, provide [App Review](https://developer.apple.com/app-store/review/guidelines/) with a public test server and dedicated demo account, including the server URL and sign-in steps in Review Notes. Keep that service available during review; do not share credentials for a personal production database.

If the first release must be available on iOS at the same time, wait for App Store approval and schedule its availability before pushing the official GitHub `vX.Y.Z` tag. A passing iOS CI build does not make the app downloadable from the App Store.

### macOS Release DMG

The Release workflow produces a universal `Cue-vX.Y.Z-macos-universal.dmg` from a `vX.Y.Z` tag matching the `version` in `pubspec.yaml`. It exports a Developer ID-signed app, signs the DMG, submits it to Apple for notarization, staples the ticket, and verifies the result before attaching it to the GitHub Release. An Xcode archive alone is not the downloadable release package.

Before pushing the first release tag, create the `macos-release` GitHub environment and restrict deployments to tags matching `v*`. Set its variable `CUE_MACOS_TEAM_ID` to the Apple Developer Team ID and add these environment secrets:

| Secret | Value |
| --- | --- |
| `CUE_MACOS_DEVELOPER_ID_P12_BASE64` | Single-line Base64 of a **Developer ID Application** `.p12` containing the private key |
| `CUE_MACOS_DEVELOPER_ID_P12_PASSWORD` | Password used when exporting that `.p12` |
| `CUE_MACOS_NOTARY_API_KEY_BASE64` | Single-line Base64 of an App Store Connect **Team** API key `.p8` |
| `CUE_MACOS_NOTARY_KEY_ID` | Key ID shown in App Store Connect |
| `CUE_MACOS_NOTARY_ISSUER_ID` | Issuer ID shown in App Store Connect |

On macOS, `base64 -i /absolute/path/to/file | tr -d '\n'` produces the single-line value. Keep the original `.p12`, its password, and the one-time-download `.p8` in secure independent backups; never commit them. The [Apple Developer ID guide](https://developer.apple.com/help/account/certificates/create-developer-id-certificates), [App Store Connect Team API key guide](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-api), and [GitHub certificate import guide](https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/sign-xcode-applications) cover credential creation. Individual App Store Connect API keys cannot be used with `notarytool`.

### Windows Release installer

The Release workflow produces `Cue-vX.Y.Z-windows-x64-setup.exe` with Inno Setup, plus a portable ZIP. The installer creates Start Menu and optional desktop shortcuts and includes an uninstaller. It installs for the current user without administrator privileges. Windows code signing is not configured for this release.

### Manual release rehearsal

Use a `vX.Y.Z-dryrun` tag matching the version in `pubspec.yaml`. Pushing this tag **does not trigger the Release workflow**. Manually dispatching it runs tests, builds and verifies the signed Android APK, signs and notarizes the macOS DMG, tests the Windows installer, checks the unsigned iOS build, and builds the API/Web Docker images. It does not push GHCR images or create a GitHub Release. Outputs remain as artifacts of that Actions run. The `android-release` and `macos-release` environments may remain restricted to `v*` tags; `main` does not need access.

```bash
git tag v1.0.0-dryrun
git push origin v1.0.0-dryrun
gh workflow run release.yml --ref v1.0.0-dryrun
```

This example matches the current `version: 1.0.0+1`; update the tag when the version changes. `gh workflow run --ref` requires the [GitHub CLI](https://cli.github.com/manual/gh_workflow_run) and repository write access. The existing Windows-only check can still be run from `main` in the Actions UI with `windows_only` selected. After checking the rehearsal artifacts and self-hosted setup, push the official `vX.Y.Z` tag to publish GHCR images and GitHub Release assets. Publication requires successful tests and Android, iOS build check, macOS, Windows, and Docker jobs. iOS App Store delivery follows the separate process above.

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

CI runs Flutter analysis and tests plus the server build and unit tests on pushes to `main` and pull requests targeting `main`. Tag-triggered releases run the same tests before any platform build or Docker publication. The end-to-end API tests below still require a running service and must be run separately.

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
