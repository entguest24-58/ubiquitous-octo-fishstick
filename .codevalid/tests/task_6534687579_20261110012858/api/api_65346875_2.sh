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
cv_step Given "a signed-in user and a product body missing its description" $LINENO
sign_in
BODY=$(jq -nc --arg n "Incomplete $SUFFIX" --arg c "$CODE" '{name:$n,price:5,code:$c}')

# When
cv_step When "the signed-in user tries to add the incomplete product" $LINENO
cv_http POST /api/products "$BODY" -H "Authorization: Bearer $TOKEN"
ST="$CV_HTTP_STATUS"; RB="$CV_HTTP_BODY"

# Then
cv_step Then "the product is refused and does not appear in the catalog" $LINENO
case "$ST" in 4??) ;; *) cv_fail "expected a 4xx refusal got $ST: $RB" $LINENO ;; esac
cv_http GET /api/products
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected catalog 200 got $CV_HTTP_STATUS" $LINENO
N=$(jq --arg c "$CODE" '[.[] | select(.code == $c)] | length' <<<"$CV_HTTP_BODY")
[ "$N" = "0" ] || cv_fail "expected no product with code $CODE in catalog got $N" $LINENO

# Cleanup
cv_step Cleanup "nothing to remove: nothing was created and data is in memory" $LINENO

echo "CODEVALID_TEST_ASSERTION_OK:api_65346875_2"
