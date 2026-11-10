#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)$RANDOM"
EMAIL="cust1_${SUFFIX}@example.com"
PASSWORD="Str0ngPass_${SUFFIX}"
CODE="SKU1-${SUFFIX}"

# Given
cv_step Given "a registered customer account" $LINENO
cv_http POST /api/auth/register "$(jq -nc --arg e "$EMAIL" --arg p "$PASSWORD" '{email:$e,password:$p}')" 201

# When
cv_step When "the customer signs in with the registration email and password" $LINENO
cv_http POST /api/auth/login "$(jq -nc --arg e "$EMAIL" --arg p "$PASSWORD" '{email:$e,password:$p}')"
LOGIN_STATUS="$CV_HTTP_STATUS"
LOGIN_BODY="$CV_HTTP_BODY"

# Then
cv_step Then "sign-in succeeds and the token is accepted as a signed-in user" $LINENO
[ "$LOGIN_STATUS" = "200" ] || cv_fail "expected sign-in HTTP 200 got $LOGIN_STATUS" $LINENO
TOKEN=$(printf '%s' "$LOGIN_BODY" | jq -r '.token // empty')
[ -n "$TOKEN" ] || cv_fail "expected a token in the sign-in response got none" $LINENO
GOT_EMAIL=$(printf '%s' "$LOGIN_BODY" | jq -r '.user.email // empty')
[ "$GOT_EMAIL" = "$EMAIL" ] || cv_fail "expected user.email $EMAIL got '$GOT_EMAIL'" $LINENO
cv_http POST /api/products "$(jq -nc --arg c "$CODE" '{name:"Signed-in check",description:"made with the sign-in token",price:5,code:$c}')" -H "Authorization: Bearer $TOKEN"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected the signed-in token to allow a catalog change (201) got $CV_HTTP_STATUS" $LINENO

# Cleanup
cv_step Cleanup "nothing to remove: data is in memory and the API has no delete routes" $LINENO
echo "created account $EMAIL and product $CODE (in-memory, no delete endpoint)"

echo "CODEVALID_TEST_ASSERTION_OK:api_40124224_1"
