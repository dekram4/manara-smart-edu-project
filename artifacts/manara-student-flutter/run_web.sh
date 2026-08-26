#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

# Keep this port aligned with the D-ID Allowed Domain.
web_port="${MANARA_FLUTTER_WEB_PORT:-50607}"

exec flutter run -d chrome --web-port "$web_port" "$@"