#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)$RANDOM"
EMAIL="cust4_${SUFFIX}@example.com"
PASSWORD="Str0ngPass_${SUFFIX}"
CODE="SKU4-${SUFFIX}"
register_and_login() {
  # $1 email, $2 password; sets TOKEN
  cv_http POST /api/auth/register "$(jq -nc --arg e "$1" --arg p "$2" '{email:$e,password:$p}')" 201
  cv_http POST /api/auth/login "$(jq -nc --arg e "$1" --arg p "$2" '{email:$e,password:$p}')" 200
  TOKEN=$(printf "%s" "$CV_HTTP_BODY" | jq -r ".token // empty")
  [ -n "$TOKEN" ] || cv_fail "expected a token from sign-in got none" $LINENO
}

# Given
cv_step Given "a registered customer signs in" $LINENO
register_and_login "$EMAIL" "$PASSWORD"

# When
cv_step When "the signed-in customer adds a product" $LINENO
cv_http POST /api/products "$(jq -nc --arg c "$CODE" '{name:"Tea kettle",description:"steel kettle",price:29.99,code:$c}')" -H "Authorization: Bearer $TOKEN"
ADD_STATUS="$CV_HTTP_STATUS"; ADD_BODY="$CV_HTTP_BODY"

# Then
cv_step Then "the product is stored and shows up when browsing" $LINENO
[ "$ADD_STATUS" = "201" ] || cv_fail "expected HTTP 201 for signed-in add got $ADD_STATUS" $LINENO
PRODUCT_ID=$(printf '%s' "$ADD_BODY" | jq -r '.id // empty')
[ -n "$PRODUCT_ID" ] || cv_fail "expected product id in create response got none" $LINENO
cv_http GET /api/products 200
MATCH=$(printf '%s' "$CV_HTTP_BODY" | jq -c --arg id "$PRODUCT_ID" '[.[] | select(.id==$id)][0] // empty')
[ -n "$MATCH" ] || cv_fail "expected product $PRODUCT_ID in catalog got none" $LINENO
printf '%s' "$MATCH" | jq -e --arg c "$CODE" '.name=="Tea kettle" and .description=="steel kettle" and .price==29.99 and .code==$c' >/dev/null   || cv_fail "expected stored product name/description/price/code to match got $MATCH" $LINENO
cv_http GET "/api/products/$PRODUCT_ID" 200

# Cleanup
cv_step Cleanup "nothing to remove: data is in memory and the API has no delete routes" $LINENO
echo "created account $EMAIL and product $PRODUCT_ID (in-memory, no delete endpoint)"

echo "CODEVALID_TEST_ASSERTION_OK:api_40124224_4"
