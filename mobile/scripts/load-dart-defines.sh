#!/usr/bin/env bash
# Reads mobile/.env and prints Flutter --dart-define flags for release builds.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../.env"

if [ -f "$ENV_FILE" ]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

DART_DEFINES=""
if [ -n "${GOOGLE_WEB_CLIENT_ID:-}" ]; then
  DART_DEFINES="--dart-define=GOOGLE_WEB_CLIENT_ID=${GOOGLE_WEB_CLIENT_ID}"
fi

echo "$DART_DEFINES"
