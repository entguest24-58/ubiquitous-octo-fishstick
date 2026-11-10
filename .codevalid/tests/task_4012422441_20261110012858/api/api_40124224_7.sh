#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)$RANDOM"
GHOST_EMAIL="ghost7_${SUFFIX}@example.com"
CODE="SKU7-${SUFFIX}"

# Given
cv_step Given "an email that belongs to no account" $LINENO
cv_prereq "confirm $GHOST_EMAIL is unregistered by a unique suffix" $LINENO

# When
cv_step When "someone signs in with the unregistered email" $LINENO
cv_http POST /api/auth/login "$(jq -nc --arg e "$GHOST_EMAIL" '{email:$e,password:"SomePassword123"}')"
LOGIN_STATUS="$CV_HTTP_STATUS"; LOGIN_BODY="$CV_HTTP_BODY"

# Then
cv_step Then "sign-in is refused and no signed-in access is granted" $LINENO
[ "$LOGIN_STATUS" = "401" ] || cv_fail "expected HTTP 401 for unregistered email got $LOGIN_STATUS" $LINENO
LEAKED=$(printf '%s' "$LOGIN_BODY" | jq -r '.token // empty' 2>/dev/null || true)
[ -z "$LEAKED" ] || cv_fail "expected no token for unregistered email got one: $LEAKED" $LINENO
AUTH_ARGS=()
[ -n "$LEAKED" ] && AUTH_ARGS=(-H "Authorization: Bearer $LEAKED")
cv_http POST /api/products "$(jq -nc --arg c "$CODE" '{name:"Ghost item",description:"should not exist",price:1,code:$c}')" "${AUTH_ARGS[@]+"${AUTH_ARGS[@]}"}"
[ "$CV_HTTP_STATUS" != "201" ] || cv_fail "expected catalog change refused without sign-in got 201" $LINENO
cv_http GET /api/products 200
N=$(printf '%s' "$CV_HTTP_BODY" | jq -r --arg c "$CODE" '[.[] | select(.code==$c)] | length')
[ "$N" = "0" ] || cv_fail "expected no product with code $CODE got $N" $LINENO

# Cleanup
cv_step Cleanup "nothing created" $LINENO

echo "CODEVALID_TEST_ASSERTION_OK:api_40124224_7"
