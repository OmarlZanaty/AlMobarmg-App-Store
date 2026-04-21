#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/home/ubuntu/almobarmg"
VENV_PATH="/home/ubuntu/venv/bin/activate"

echo "Creating web root..."
sudo mkdir -p /var/www/almobarmg
sudo chown -R ubuntu:ubuntu /var/www/almobarmg

cd "$PROJECT_DIR"
source "$VENV_PATH"

echo "Running database migrations..."
alembic upgrade head

echo "Reloading systemd and enabling services..."
sudo systemctl daemon-reload
sudo systemctl enable --now almobarmg-api.service
sudo systemctl enable --now almobarmg-worker.service

echo "Verifying services..."
sudo systemctl --no-pager --full status almobarmg-api.service
sudo systemctl --no-pager --full status almobarmg-worker.service
sudo systemctl --no-pager --full status nginx.service

echo "Health check (/health)..."
curl -fsS http://127.0.0.1/api/health

echo "Initial setup completed successfully."
