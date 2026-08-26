#!/usr/bin/env bash
# Run AFTER reboot onto linux-cachyos 7.2.x (matching /lib/modules).
# Brings up Docker + LocalStack + lab 01 S3.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "== kernel =="
uname -r
if [[ ! -d "/lib/modules/$(uname -r)" ]]; then
  echo "ERROR: no modules for $(uname -r)"
  echo "Boot linux-cachyos 7.2.x (or LTS 6.18) from the boot menu, then re-run."
  ls /lib/modules/
  exit 1
fi

echo "== docker =="
if ! docker info >/dev/null 2>&1; then
  echo "starting docker (may need sudo)..."
  sudo systemctl reset-failed docker.service docker.socket || true
  sudo systemctl restart containerd
  sudo systemctl start docker
  sleep 2
fi
docker info >/dev/null
docker run --rm hello-world | tail -5

echo "== localstack =="
set -a
# shellcheck disable=SC1091
source "$ROOT/env/localstack.env"
set +a
docker compose -f "$ROOT/compose/localstack.yml" up -d
echo "waiting health..."
for i in $(seq 1 40); do
  if curl -sf http://localhost:4566/_localstack/health >/dev/null; then
    curl -s http://localhost:4566/_localstack/health | head -c 300; echo
    break
  fi
  sleep 2
  if [[ $i -eq 40 ]]; then
    echo "LocalStack health timeout"; docker compose -f "$ROOT/compose/localstack.yml" logs --tail 40
    exit 1
  fi
done

echo "== lab 01 S3 =="
cd "$ROOT/labs/01-s3-static"
terraform init -input=false
terraform apply -input=false -auto-approve
bash ./verify.sh

echo
echo "PASS — LocalStack + S3 lab green"
echo "Next: cd $ROOT/labs/02-dynamodb-crud && terraform init && terraform apply -auto-approve && ./verify.sh"
echo "Or: cloud  (TUI)"
