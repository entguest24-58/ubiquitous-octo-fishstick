#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)$RANDOM"
EMAIL="cust6_${SUFFIX}@example.com"
PASSWORD="Str0ngPass_${SUFFIX}"
CODE="SKU6-${SUFFIX}"

# Given
cv_step Given "a registered customer (victim) account" $LINENO
cv_http POST /api/auth/register "$(jq -nc --arg e "$EMAIL" --arg p "$PASSWORD" '{email:$e,password:$p}')" 201

# When
cv_step When "an attacker signs in with the customer's email and a wrong password" $LINENO
cv_http POST /api/auth/login "$(jq -nc --arg e "$EMAIL" '{email:$e,password:"WrongPassword123"}')"
LOGIN_STATUS="$CV_HTTP_STATUS"; LOGIN_BODY="$CV_HTTP_BODY"

# Then
cv_step Then "sign-in is refused, no token is issued and catalog changes stay unavailable" $LINENO
[ "$LOGIN_STATUS" = "401" ] || cv_fail "expected HTTP 401 for wrong password got $LOGIN_STATUS" $LINENO
LEAKED=$(printf '%s' "$LOGIN_BODY" | jq -r '.token // empty' 2>/dev/null || true)
[ -z "$LEAKED" ] || cv_fail "expected no token for wrong password got one: $LEAKED" $LINENO
AUTH_ARGS=()
[ -n "$LEAKED" ] && AUTH_ARGS=(-H "Authorization: Bearer $LEAKED")
cv_http POST /api/products "$(jq -nc --arg c "$CODE" '{name:"Attacker item",description:"should not exist",price:1,code:$c}')" "${AUTH_ARGS[@]+"${AUTH_ARGS[@]}"}"
[ "$CV_HTTP_STATUS" != "201" ] || cv_fail "expected catalog change refused after failed sign-in got 201" $LINENO
cv_http GET /api/products 200
N=$(printf '%s' "$CV_HTTP_BODY" | jq -r --arg c "$CODE" '[.[] | select(.code==$c)] | length')
[ "$N" = "0" ] || cv_fail "expected no product with code $CODE in catalog got $N" $LINENO

# Cleanup
cv_step Cleanup "nothing to remove: data is in memory and the API has no delete routes" $LINENO
echo "created account $EMAIL (in-memory, no delete endpoint)"

echo "CODEVALID_TEST_ASSERTION_OK:api_40124224_6"
