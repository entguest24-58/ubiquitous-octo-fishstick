#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)$RANDOM"
EMAIL="cust3_${SUFFIX}@example.com"
PASSWORD="Str0ngPass_${SUFFIX}"
CODE="SKU3-${SUFFIX}"
register_and_login() {
  # $1 email, $2 password; sets TOKEN
  cv_http POST /api/auth/register "$(jq -nc --arg e "$1" --arg p "$2" '{email:$e,password:$p}')" 201
  cv_http POST /api/auth/login "$(jq -nc --arg e "$1" --arg p "$2" '{email:$e,password:$p}')" 200
  TOKEN=$(printf "%s" "$CV_HTTP_BODY" | jq -r ".token // empty")
  [ -n "$TOKEN" ] || cv_fail "expected a token from sign-in got none" $LINENO
}

# Given
cv_step Given "a product exists in the catalog" $LINENO
cv_prereq "register and sign in a seller to add a product" $LINENO
register_and_login "$EMAIL" "$PASSWORD"
cv_http POST /api/products "$(jq -nc --arg c "$CODE" '{name:"Browse lamp",description:"a lamp to browse",price:19.5,code:$c}')" 201 -H "Authorization: Bearer $TOKEN"
PRODUCT_ID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.id // empty')
[ -n "$PRODUCT_ID" ] || cv_fail "expected product id from create got none" $LINENO

# When
cv_step When "an anonymous visitor requests the catalog" $LINENO
cv_http GET /api/products
LIST_STATUS="$CV_HTTP_STATUS"; LIST_BODY="$CV_HTTP_BODY"

# Then
cv_step Then "the catalog is returned and includes the product" $LINENO
[ "$LIST_STATUS" = "200" ] || cv_fail "expected HTTP 200 for anonymous catalog browse got $LIST_STATUS" $LINENO
printf '%s' "$LIST_BODY" | jq -e 'type=="array"' >/dev/null || cv_fail "expected a JSON array of products got: $LIST_BODY" $LINENO
FOUND=$(printf '%s' "$LIST_BODY" | jq -r --arg id "$PRODUCT_ID" '[.[] | select(.id==$id and .name=="Browse lamp")] | length')
[ "$FOUND" = "1" ] || cv_fail "expected product $PRODUCT_ID in anonymous catalog got $FOUND matches" $LINENO
cv_http GET "/api/products/$PRODUCT_ID" 200
GOT_CODE=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.code // empty')
[ "$GOT_CODE" = "$CODE" ] || cv_fail "expected product code $CODE got '$GOT_CODE'" $LINENO

# Cleanup
cv_step Cleanup "nothing to remove: data is in memory and the API has no delete routes" $LINENO
echo "created account $EMAIL and product $PRODUCT_ID (in-memory, no delete endpoint)"

echo "CODEVALID_TEST_ASSERTION_OK:api_40124224_3"
