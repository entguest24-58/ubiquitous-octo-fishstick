#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)$RANDOM"
EMAIL="cust9_${SUFFIX}@example.com"
PASSWORD="Str0ngPass_${SUFFIX}"
CODE="SKU9-${SUFFIX}"
register_and_login() {
  # $1 email, $2 password; sets TOKEN
  cv_http POST /api/auth/register "$(jq -nc --arg e "$1" --arg p "$2" '{email:$e,password:$p}')" 201
  cv_http POST /api/auth/login "$(jq -nc --arg e "$1" --arg p "$2" '{email:$e,password:$p}')" 200
  TOKEN=$(printf "%s" "$CV_HTTP_BODY" | jq -r ".token // empty")
  [ -n "$TOKEN" ] || cv_fail "expected a token from sign-in got none" $LINENO
}

# Given
cv_step Given "a real sign-in exists; build a forged token and a tampered copy of the real one" $LINENO
register_and_login "$EMAIL" "$PASSWORD"
FORGED="deadbeef${SUFFIX}"
LAST="${TOKEN: -1}"
if [ "$LAST" = "0" ]; then NEWLAST="1"; else NEWLAST="0"; fi
TAMPERED="${TOKEN%?}${NEWLAST}"
[ "$TAMPERED" != "$TOKEN" ] || cv_fail "expected tampered token to differ from the real one" $LINENO

# When
cv_step When "add a product with a made-up token and with a tampered token" $LINENO
cv_http POST /api/products "$(jq -nc --arg c "$CODE" '{name:"Forged item",description:"forged",price:1,code:$c}')" -H "Authorization: Bearer $FORGED"
FORGED_STATUS="$CV_HTTP_STATUS"
cv_http POST /api/products "$(jq -nc --arg c "$CODE" '{name:"Tampered item",description:"tampered",price:1,code:$c}')" -H "Authorization: Bearer $TAMPERED"
TAMPERED_STATUS="$CV_HTTP_STATUS"

# Then
cv_step Then "both requests are refused and the catalog is unchanged" $LINENO
[ "$FORGED_STATUS" != "201" ] || cv_fail "expected forged token to be refused got 201" $LINENO
[ "$TAMPERED_STATUS" != "201" ] || cv_fail "expected tampered token to be refused got 201" $LINENO
cv_http GET /api/products 200
N=$(printf '%s' "$CV_HTTP_BODY" | jq -r --arg c "$CODE" '[.[] | select(.code==$c)] | length')
[ "$N" = "0" ] || cv_fail "expected no product with code $CODE after forged attempts got $N" $LINENO

# Cleanup
cv_step Cleanup "nothing to remove: data is in memory and the API has no delete routes" $LINENO
echo "created account $EMAIL (in-memory, no delete endpoint)"

echo "CODEVALID_TEST_ASSERTION_OK:api_40124224_9"
