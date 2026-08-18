#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "==> post-merge setup: installing dependencies"
if [[ -f pnpm-lock.yaml ]]; then
  pnpm install --frozen-lockfile
elif [[ -f package-lock.json ]]; then
  npm ci --no-audit --no-fund
elif [[ -f package.json ]]; then
  npm install --no-audit --no-fund
fi

if [[ -f smart-edu-project/package.json ]]; then
  if [[ -f smart-edu-project/pnpm-lock.yaml ]]; then
    pnpm --dir smart-edu-project install --frozen-lockfile
  elif [[ -f smart-edu-project/package-lock.json ]]; then
    npm --prefix smart-edu-project ci --no-audit --no-fund
  else
    npm --prefix smart-edu-project install --no-audit --no-fund
  fi
  echo "==> post-merge setup: building web app"
  npm --prefix smart-edu-project run build
fi

echo "==> post-merge setup complete"