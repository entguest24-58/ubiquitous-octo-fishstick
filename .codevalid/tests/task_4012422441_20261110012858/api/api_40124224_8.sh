#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)$RANDOM"
EMAIL="cust8_${SUFFIX}@example.com"
PASSWORD="Str0ngPass_${SUFFIX}"
CODE="SKU8-${SUFFIX}"
ANON_CODE="SKU8-ANON-${SUFFIX}"
register_and_login() {
  # $1 email, $2 password; sets TOKEN
  cv_http POST /api/auth/register "$(jq -nc --arg e "$1" --arg p "$2" '{email:$e,password:$p}')" 201
  cv_http POST /api/auth/login "$(jq -nc --arg e "$1" --arg p "$2" '{email:$e,password:$p}')" 200
  TOKEN=$(printf "%s" "$CV_HTTP_BODY" | jq -r ".token // empty")
  [ -n "$TOKEN" ] || cv_fail "expected a token from sign-in got none" $LINENO
}

# Given
cv_step Given "a signed-in owner adds a product; snapshot the catalog" $LINENO
register_and_login "$EMAIL" "$PASSWORD"
cv_http POST /api/products "$(jq -nc --arg c "$CODE" '{name:"Owner chair",description:"oak chair",price:80,code:$c}')" 201 -H "Authorization: Bearer $TOKEN"
PRODUCT_ID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.id // empty')
[ -n "$PRODUCT_ID" ] || cv_fail "expected product id from create got none" $LINENO
cv_http GET "/api/products/$PRODUCT_ID" 200
BEFORE=$(printf '%s' "$CV_HTTP_BODY" | jq -cS .)

# When
cv_step When "an anonymous visitor tries to add a product (no Authorization header)" $LINENO
cv_http POST /api/products "$(jq -nc --arg c "$ANON_CODE" '{name:"Anon item",description:"anonymous add",price:1,code:$c}')"
ADD_STATUS="$CV_HTTP_STATUS"

# Then
cv_step Then "the add is refused and the catalog is unchanged" $LINENO
[ "$ADD_STATUS" != "201" ] || cv_fail "expected anonymous add to be refused got 201" $LINENO
cv_http GET /api/products 200
N=$(printf '%s' "$CV_HTTP_BODY" | jq -r --arg c "$ANON_CODE" '[.[] | select(.code==$c)] | length')
[ "$N" = "0" ] || cv_fail "expected anonymous product $ANON_CODE absent from catalog got $N" $LINENO
cv_http GET "/api/products/$PRODUCT_ID" 200
AFTER=$(printf '%s' "$CV_HTTP_BODY" | jq -cS .)
[ "$BEFORE" = "$AFTER" ] || cv_fail "expected owner's product unchanged; before $BEFORE after $AFTER" $LINENO

# Cleanup
cv_step Cleanup "nothing to remove: data is in memory and the API has no delete routes" $LINENO
echo "created account $EMAIL and product $PRODUCT_ID (in-memory, no delete endpoint)"

echo "CODEVALID_TEST_ASSERTION_OK:api_40124224_8"
