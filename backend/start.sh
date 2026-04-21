#!/usr/bin/env bash
set -euo pipefail

cd /home/ubuntu/almobarmg
source /home/ubuntu/venv/bin/activate

python -m backend.migrations.run

exec gunicorn backend.main:app \
  -w 4 \
  -k uvicorn.workers.UvicornWorker \
  --bind 0.0.0.0:8080 \
  --timeout 120
