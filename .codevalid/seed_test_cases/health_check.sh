#!/usr/bin/env bash
# CodeValid seed health check: the service answers GET /health with {"status":"ok"}.
set -euo pipefail
BASE_URL="${BASE_URL:-http://localhost:3000}"
body=$(curl -fsS "$BASE_URL/health")
echo "$body"
echo "$body" | grep -q '"status":"ok"'
echo "CODEVALID_SEED_OK"
