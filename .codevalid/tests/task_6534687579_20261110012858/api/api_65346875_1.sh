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
cv_step Given "a signed-in user (token from POST /api/auth/login) and an unused product code" $LINENO
sign_in
BODY=$(product_json "Widget $SUFFIX" "A sturdy widget" 19.99 "$CODE")

# When
cv_step When "the signed-in user adds a product with name, description, price and code" $LINENO
cv_http POST /api/products "$BODY" -H "Authorization: Bearer $TOKEN"
ST="$CV_HTTP_STATUS"; RB="$CV_HTTP_BODY"

# Then
cv_step Then "the product is created and returned with its details and an identifier" $LINENO
[ "$ST" = "201" ] || cv_fail "expected 201 got $ST: $RB" $LINENO
[ "$(jq -r .name <<<"$RB")" = "Widget $SUFFIX" ] || cv_fail "expected name 'Widget $SUFFIX' got $(jq -r .name <<<"$RB")" $LINENO
[ "$(jq -r .description <<<"$RB")" = "A sturdy widget" ] || cv_fail "expected description got $(jq -r .description <<<"$RB")" $LINENO
[ "$(jq -r '.price == 19.99' <<<"$RB")" = "true" ] || cv_fail "expected price 19.99 got $(jq -r .price <<<"$RB")" $LINENO
[ "$(jq -r .code <<<"$RB")" = "$CODE" ] || cv_fail "expected code $CODE got $(jq -r .code <<<"$RB")" $LINENO
PID=$(jq -r '.id // empty' <<<"$RB")
[ -n "$PID" ] || cv_fail "expected an identifier in the response got none" $LINENO

# Cleanup
cv_step Cleanup "nothing to remove: data is in memory and the API has no delete route" $LINENO
echo "created product $PID (in-memory)"

echo "CODEVALID_TEST_ASSERTION_OK:api_65346875_1"
