#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${PROJECT_DIR:-$SCRIPT_DIR}"
VENV_PATH="/home/ubuntu/venv/bin/activate"
SYSTEMD_DIR="/etc/systemd/system"
NGINX_AVAILABLE="/etc/nginx/sites-available/almobarmg"
NGINX_ENABLED="/etc/nginx/sites-enabled/almobarmg"
LEGACY_PATH="/home/ubuntu/almobarmg"
LOG_DIR="/var/log/almobarmg"
DISK_MONITOR_SCRIPT="/usr/local/bin/almobarmg-disk-monitor.sh"
CRON_FILE="/etc/cron.d/almobarmg-disk-monitor"
LOGROTATE_FILE="/etc/logrotate.d/almobarmg"

if [ ! -d "$PROJECT_DIR/backend" ] || [ ! -f "$PROJECT_DIR/backend/main.py" ]; then
  echo "Error: PROJECT_DIR '$PROJECT_DIR' does not look like the app repository root."
  echo "Expected to find backend/main.py. Clone/sync the repository first."
  exit 1
fi

echo "Creating web root..."
sudo mkdir -p /var/www/almobarmg
sudo chown -R ubuntu:ubuntu /var/www/almobarmg
sudo chmod -R 755 /var/www/almobarmg
if [ ! -f /var/www/almobarmg/index.html ]; then
  cat >/tmp/almobarmg-index.html <<'HTML'
<!doctype html>
<html>
  <head><meta charset="utf-8"><title>Al Mobarmg Store</title></head>
  <body style="font-family:Arial,sans-serif;padding:24px">
    <h2>Al Mobarmg Store</h2>
    <p>Web frontend is not built yet. Run deploy after installing Flutter SDK.</p>
  </body>
</html>
HTML
  sudo mv /tmp/almobarmg-index.html /var/www/almobarmg/index.html
fi

echo "Ensuring legacy service path exists (${LEGACY_PATH})..."
if [ "$PROJECT_DIR" != "$LEGACY_PATH" ]; then
  sudo ln -sfn "$PROJECT_DIR" "$LEGACY_PATH"
fi

cd "$PROJECT_DIR"
source "$VENV_PATH"

echo "Installing systemd services..."
sudo cp "$PROJECT_DIR/etc/systemd/system/almobarmg-api.service" "$SYSTEMD_DIR/almobarmg-api.service"
sudo cp "$PROJECT_DIR/etc/systemd/system/almobarmg-worker.service" "$SYSTEMD_DIR/almobarmg-worker.service"

echo "Installing Nginx site..."
sudo cp "$PROJECT_DIR/etc/nginx/sites-available/almobarmg" "$NGINX_AVAILABLE"
if [ -L "$NGINX_ENABLED" ] || [ -f "$NGINX_ENABLED" ]; then
  sudo rm -f "$NGINX_ENABLED"
fi
sudo ln -s "$NGINX_AVAILABLE" "$NGINX_ENABLED"
if [ -L /etc/nginx/sites-enabled/default ] || [ -f /etc/nginx/sites-enabled/default ]; then
  sudo rm -f /etc/nginx/sites-enabled/default
fi
sudo nginx -t
sudo systemctl reload nginx

echo "Reloading systemd and enabling services..."
sudo systemctl daemon-reload
sudo systemctl enable --now almobarmg-api.service
sudo systemctl enable --now almobarmg-worker.service

echo "Configuring application logs directory..."
sudo mkdir -p "$LOG_DIR"
sudo chown ubuntu:ubuntu "$LOG_DIR"
sudo chmod 750 "$LOG_DIR"

echo "Installing disk usage monitoring cron job..."
sudo tee "$DISK_MONITOR_SCRIPT" >/dev/null <<'BASH'
#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="/home/ubuntu/.env"
TARGET_PATH="/home/ubuntu"
THRESHOLD=85

if [ -f "$ENV_FILE" ]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

usage_pct=$(df -P "$TARGET_PATH" | awk 'NR==2 {gsub("%", "", $5); print $5}')
if [ -z "$usage_pct" ]; then
  exit 0
fi

if [ "$usage_pct" -gt "$THRESHOLD" ] && [ -n "${RESEND_API_KEY:-}" ] && [ -n "${EMAIL_FROM:-}" ]; then
  to_email="${ALERT_EMAIL_TO:-$EMAIL_FROM}"
  subject="[Al Mobarmg] Disk usage alert: ${usage_pct}%"
  body="Disk usage on $(hostname) at ${TARGET_PATH} is ${usage_pct}% (threshold: ${THRESHOLD}%)."

  curl -sS https://api.resend.com/emails \
    -H "Authorization: Bearer ${RESEND_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "{\"from\":\"${EMAIL_FROM}\",\"to\":[\"${to_email}\"],\"subject\":\"${subject}\",\"text\":\"${body}\"}" \
    >/dev/null
fi
BASH
sudo chmod 750 "$DISK_MONITOR_SCRIPT"

sudo tee "$CRON_FILE" >/dev/null <<CRON
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
0 * * * * ubuntu $DISK_MONITOR_SCRIPT >> $LOG_DIR/disk-monitor.log 2>&1
CRON
sudo chmod 644 "$CRON_FILE"

echo "Installing logrotate configuration for ${LOG_DIR}..."
sudo tee "$LOGROTATE_FILE" >/dev/null <<'ROTATE'
/var/log/almobarmg/*.log {
  daily
  rotate 14
  compress
  delaycompress
  missingok
  notifempty
  copytruncate
  create 0640 ubuntu ubuntu
}
ROTATE

sudo logrotate -f "$LOGROTATE_FILE"

echo "Running database migrations..."
python -m backend.migrations.run

echo "Verifying services..."
sudo systemctl --no-pager --full status almobarmg-api.service
sudo systemctl --no-pager --full status almobarmg-worker.service
sudo systemctl --no-pager --full status nginx.service

echo "Health check (/health)..."
health_ok=0
for _ in {1..15}; do
  if curl -fsS http://127.0.0.1:8080/health >/dev/null; then
    curl -fsS http://127.0.0.1:8080/health
    health_ok=1
    break
  fi
  sleep 2
done
if [ "$health_ok" -ne 1 ]; then
  echo "Health check failed after retries."
  exit 1
fi

echo "Initial setup completed successfully."
