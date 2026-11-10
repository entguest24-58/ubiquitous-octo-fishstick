#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)$RANDOM"
EMAIL="prod_${SUFFIX}@example.com"
PASSWORD="Str0ngPass_${SUFFIX}"
CODE="SKU-${SUFFIX}"
creds() { jq -nc --arg e "$1" --arg p "$2" '{email:$e,password:$p}'; }
product_json() { jq -nc --arg n "$1" --arg d "$2" --argjson p "$3" --arg c "$4" '{name:$n,description:$d,price:$p,code:$c}'; }
sign_in() {
  cv_prereq "register and sign in $EMAIL" $LINENO
  cv_http POST /api/auth/register "$(creds "$EMAIL" "$PASSWORD")"
  [ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected register 201 got $CV_HTTP_STATUS" $LINENO
  cv_http POST /api/auth/login "$(creds "$EMAIL" "$PASSWORD")"
  [ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected login 200 got $CV_HTTP_STATUS" $LINENO
  TOKEN=$(printf "%s" "$CV_HTTP_BODY" | jq -r ".token // empty")
  [ -n "$TOKEN" ] || cv_fail "expected a token from POST /api/auth/login got none" $LINENO
}

# Given
cv_step Given "a signed-in user has added a product and got its identifier" $LINENO
sign_in
cv_http POST /api/products "$(product_json "Mug $SUFFIX" "Ceramic mug" 7.25 "$CODE")" -H "Authorization: Bearer $TOKEN"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected product created (201) got $CV_HTTP_STATUS" $LINENO
PID=$(jq -r '.id // empty' <<<"$CV_HTTP_BODY")
[ -n "$PID" ] || cv_fail "expected an identifier from create got none" $LINENO

# When
cv_step When "a visitor who is not signed in opens the product by its identifier" $LINENO
cv_http GET "/api/products/$PID"
ST="$CV_HTTP_STATUS"; RB="$CV_HTTP_BODY"

# Then
cv_step Then "the product's name, description, price and code are returned" $LINENO
[ "$ST" = "200" ] || cv_fail "expected 200 got $ST" $LINENO
[ "$(jq -r .id <<<"$RB")" = "$PID" ] || cv_fail "expected id $PID got $RB" $LINENO
[ "$(jq -r .name <<<"$RB")" = "Mug $SUFFIX" ] || cv_fail "expected name got $RB" $LINENO
[ "$(jq -r .description <<<"$RB")" = "Ceramic mug" ] || cv_fail "expected description got $RB" $LINENO
[ "$(jq -r '.price == 7.25' <<<"$RB")" = "true" ] || cv_fail "expected price 7.25 got $RB" $LINENO
[ "$(jq -r .code <<<"$RB")" = "$CODE" ] || cv_fail "expected code $CODE got $RB" $LINENO

# Cleanup
cv_step Cleanup "nothing to remove: data is in memory and the API has no delete route" $LINENO

echo "CODEVALID_TEST_ASSERTION_OK:api_65346875_5"
