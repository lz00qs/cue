#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

if ! command -v dart >/dev/null 2>&1; then
  printf 'Error: Dart is not available in PATH. Install Flutter/Dart and try again.\n' >&2
  exit 1
fi

cd "${PROJECT_DIR}"
exec dart run tool/rebuild_backend.dart "$@"
