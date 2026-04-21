#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/home/ubuntu/almobarmg"
VENV_PATH="/home/ubuntu/venv/bin/activate"
WEB_ROOT="/var/www/almobarmg"

cd "$PROJECT_DIR"

echo "[1/11] Pulling latest code..."
git pull --ff-only

echo "[2/11] Activating virtual environment..."
source "$VENV_PATH"

echo "[3/11] Installing Python dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

echo "[4/11] Running database migrations..."
alembic upgrade head

echo "[5/11] Building Flutter web release..."
cd frontend
flutter pub get
flutter build web --release

echo "[6/11] Syncing Flutter web build to ${WEB_ROOT}..."
sudo mkdir -p "$WEB_ROOT"
sudo rsync -a --delete build/web/ "$WEB_ROOT"/

cd "$PROJECT_DIR"

echo "[7/11] Restarting API service..."
sudo systemctl restart almobarmg-api

echo "[8/11] Restarting worker service..."
sudo systemctl restart almobarmg-worker

echo "[9/11] Reloading Nginx..."
sudo nginx -t
sudo nginx -s reload

echo "[10/11] Checking services..."
sudo systemctl is-active --quiet almobarmg-api
sudo systemctl is-active --quiet almobarmg-worker
sudo systemctl is-active --quiet nginx

echo "[11/11] Deployment status summary"
echo "API:     $(systemctl is-active almobarmg-api)"
echo "Worker:  $(systemctl is-active almobarmg-worker)"
echo "Nginx:   $(systemctl is-active nginx)"
echo "Health:  $(curl -fsS http://127.0.0.1/api/health || echo 'unavailable')"

echo "Deployment completed successfully."
