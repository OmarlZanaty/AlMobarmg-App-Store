#!/usr/bin/env bash
set -euo pipefail

source /home/ubuntu/venv/bin/activate
cd /home/ubuntu/almobarmg

python -m backend.migrations.run

exec gunicorn backend.main:app \
  -w 4 \
  -k uvicorn.workers.UvicornWorker \
  --bind 0.0.0.0:8080 \
  --timeout 120 \
  --access-logfile - \
  --error-logfile -
