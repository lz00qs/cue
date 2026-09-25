#!/usr/bin/env bash
set -euo pipefail

backup_path="${1:-backups/last/cue-latest.sql.gz}"
if [[ ! -f "$backup_path" ]]; then
  echo "Backup file not found: $backup_path" >&2
  exit 1
fi
backup_path="$(realpath "$backup_path")"
gzip -t "$backup_path"

# Restore into a disconnected, disposable PostgreSQL 17 container. Never touch
# the running Cue database or its named volume during this check.
container="cue-restore-check-$$"
cleanup() {
  docker rm -f "$container" >/dev/null 2>&1 || true
}
trap cleanup EXIT

docker run --detach --rm --name "$container" --network none \
  --tmpfs "/var/lib/postgresql/data:rw,size=${CUE_RESTORE_TMPFS_SIZE:-512m}" \
  -e POSTGRES_HOST_AUTH_METHOD=trust \
  postgres:17-alpine >/dev/null

ready=false
for _ in {1..30}; do
  if docker exec "$container" pg_isready -U postgres -d postgres >/dev/null 2>&1; then
    ready=true
    break
  fi
  sleep 1
done
if [[ "$ready" != true ]]; then
  echo 'Disposable PostgreSQL did not become ready' >&2
  exit 1
fi

docker exec "$container" psql -v ON_ERROR_STOP=1 -U postgres -d postgres \
  -c 'CREATE ROLE cue LOGIN' >/dev/null
docker exec "$container" psql -v ON_ERROR_STOP=1 -U postgres -d postgres \
  -c 'CREATE DATABASE cue OWNER cue' >/dev/null

gzip -dc "$backup_path" | docker exec -i "$container" \
  psql -v ON_ERROR_STOP=1 -U postgres -d cue >/dev/null

tables_present="$(docker exec "$container" psql -v ON_ERROR_STOP=1 -U postgres -d cue -Atc \
  "SELECT to_regclass('public.tasks') IS NOT NULL AND to_regclass('public.users') IS NOT NULL AND to_regclass('public.auth_sessions') IS NOT NULL")"
if [[ "$tables_present" != t ]]; then
  echo 'Restored database is missing Cue tables' >&2
  exit 1
fi

task_count="$(docker exec "$container" psql -v ON_ERROR_STOP=1 -U postgres -d cue -Atc 'SELECT count(*) FROM tasks')"
user_count="$(docker exec "$container" psql -v ON_ERROR_STOP=1 -U postgres -d cue -Atc 'SELECT count(*) FROM users')"
echo "Restore verified in disposable PostgreSQL 17: $task_count tasks, $user_count users"
