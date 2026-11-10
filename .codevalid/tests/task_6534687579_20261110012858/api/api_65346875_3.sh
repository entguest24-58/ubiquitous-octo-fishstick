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
cv_step Given "a signed-in user and an existing product using the code" $LINENO
sign_in
cv_http POST /api/products "$(product_json "Original $SUFFIX" "Original item" 10 "$CODE")" -H "Authorization: Bearer $TOKEN"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected the first product to be created (201) got $CV_HTTP_STATUS" $LINENO
ORIG="$CV_HTTP_BODY"; PID=$(jq -r .id <<<"$ORIG")

# When
cv_step When "the signed-in user adds another product with the same code" $LINENO
cv_http POST /api/products "$(product_json "Copy $SUFFIX" "Copy item" 99 "$CODE")" -H "Authorization: Bearer $TOKEN"
ST="$CV_HTTP_STATUS"; RB="$CV_HTTP_BODY"

# Then
cv_step Then "the duplicate is refused, the original is unchanged, only one product has the code" $LINENO
case "$ST" in 4??) ;; *) cv_fail "expected a 4xx refusal for duplicate code got $ST: $RB" $LINENO ;; esac
cv_http GET "/api/products/$PID"
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected original product readable (200) got $CV_HTTP_STATUS" $LINENO
[ "$(jq -S . <<<"$CV_HTTP_BODY")" = "$(jq -S . <<<"$ORIG")" ] || cv_fail "expected original product unchanged got $CV_HTTP_BODY" $LINENO
cv_http GET /api/products
N=$(jq --arg c "$CODE" '[.[] | select(.code == $c)] | length' <<<"$CV_HTTP_BODY")
[ "$N" = "1" ] || cv_fail "expected exactly 1 product with code $CODE got $N" $LINENO

# Cleanup
cv_step Cleanup "nothing to remove: data is in memory and the API has no delete route" $LINENO

echo "CODEVALID_TEST_ASSERTION_OK:api_65346875_3"
