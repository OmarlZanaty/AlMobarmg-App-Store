#!/usr/bin/env bash
# Run this after deployment to verify everything works end-to-end
BASE="http://127.0.0.1:8080"
PASS=0
FAIL=0

check() {
  local name="$1"
  local result="$2"
  if [ "$result" = "true" ]; then
    echo "✅ $name"
    PASS=$((PASS+1))
  else
    echo "❌ $name"
    FAIL=$((FAIL+1))
  fi
}

# 1. Health check
HEALTH=$(curl -sf "$BASE/health" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['status']=='ok')" 2>/dev/null || echo false)
check "Health endpoint responds" "$HEALTH"

# 2. Database reachable
DB=$(curl -sf "$BASE/health" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['database']=='ok')" 2>/dev/null || echo false)
check "Database connection" "$DB"

# 3. Redis reachable
REDIS=$(curl -sf "$BASE/health" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['redis']=='ok')" 2>/dev/null || echo false)
check "Redis connection" "$REDIS"

# 4. MobSF reachable
MOBSF=$(curl -sf http://localhost:8000 >/dev/null 2>&1 && echo true || echo false)
check "MobSF running on port 8000" "$MOBSF"

# 5. Register endpoint exists
REG=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE/api/auth/register" -H "Content-Type: application/json" -d '{"email":"smoketest@test.invalid","password":"test12345","name":"Smoke Test"}')
check "POST /api/auth/register returns 4xx or 2xx (not 404)" "$([ "$REG" != "404" ] && echo true || echo false)"

# 6. Apps list endpoint exists
APPS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/api/apps")
check "GET /api/apps returns 200" "$([ "$APPS" = "200" ] && echo true || echo false)"

# 7. Admin queue endpoint exists and requires auth
QUEUE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/api/admin/queue")
check "GET /api/admin/queue returns 401 (not 404)" "$([ "$QUEUE" = "401" ] && echo true || echo false)"

# 8. Celery worker running
CELERY=$(systemctl is-active --quiet almobarmg-worker && echo true || echo false)
check "Celery worker service active" "$CELERY"

# 9. Nginx serving Flutter web
WEB=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:80/)
check "Nginx serving Flutter web (port 80)" "$([ "$WEB" = "200" ] && echo true || echo false)"

# 10. Swagger docs accessible
DOCS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/docs")
check "FastAPI Swagger docs at /docs" "$([ "$DOCS" = "200" ] && echo true || echo false)"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && echo "🎉 All checks passed — production ready!" && exit 0 || echo "⚠️  Fix failing checks before launch" && exit 1
