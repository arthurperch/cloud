#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
set -a
# shellcheck disable=SC1091
source "$ROOT/env/localstack.env"
set +a
docker compose -f compose/localstack.yml up -d
echo "waiting for health..."
for i in $(seq 1 30); do
  if curl -sf http://localhost:4566/_localstack/health >/dev/null; then
    curl -s http://localhost:4566/_localstack/health | head -c 400; echo
    echo "LocalStack UP"
    exit 0
  fi
  sleep 2
done
echo "LocalStack health timeout" >&2
exit 1
