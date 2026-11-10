#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)$RANDOM"
creds() { jq -nc --arg e "$1" --arg p "$2" '{email:$e,password:$p}'; }
product_json() { jq -nc --arg n "$1" --arg d "$2" --argjson p "$3" --arg c "$4" '{name:$n,description:$d,price:$p,code:$c}'; }
EMAIL="cat3_${SUFFIX}@example.com"
PASSWORD="Str0ngPass_${SUFFIX}"
CODE="CAT3-${SUFFIX}"
UNKNOWN_ID="00000000-0000-4000-8000-$(printf '%012d' $(( ${SUFFIX:0:12} % 1000000000000 )))"

# Given
cv_step Given "the catalog holds a product and an identifier that matches no product" $LINENO
cv_prereq "register and sign in a seller, create one product" $LINENO
cv_http POST /api/auth/register "$(creds "$EMAIL" "$PASSWORD")" 201
cv_http POST /api/auth/login "$(creds "$EMAIL" "$PASSWORD")" 200
TOKEN=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.token // empty')
[ -n "$TOKEN" ] || cv_fail "expected a sign-in token got none" $LINENO
cv_http POST /api/products "$(product_json "Mug $SUFFIX" "Coffee mug" 8 "$CODE")" 201 -H "Authorization: Bearer $TOKEN"
EXISTING_ID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.id // empty')
[ -n "$EXISTING_ID" ] || cv_fail "expected an id for the created product got none" $LINENO
cv_prereq "confirm the unknown identifier is not in the catalog" $LINENO
cv_http GET /api/products 200
printf '%s' "$CV_HTTP_BODY" | jq -e --arg id "$UNKNOWN_ID" 'all(.[]; .id != $id)' >/dev/null \
  || cv_fail "expected $UNKNOWN_ID to belong to no product" $LINENO

# When
cv_step When "an anonymous visitor opens the unknown identifier" $LINENO
cv_http GET "/api/products/$UNKNOWN_ID"
STATUS="$CV_HTTP_STATUS"; BODY="$CV_HTTP_BODY"

# Then
cv_step Then "the request is refused as not found and no product data is returned" $LINENO
[ "$STATUS" = "404" ] || cv_fail "expected HTTP 404 for unknown product got $STATUS" $LINENO
if printf '%s' "$BODY" | jq -e 'type == "object" and (has("id") or has("name") or has("description") or has("price") or has("code"))' >/dev/null 2>&1; then
  cv_fail "expected no product fields in the not-found response got $BODY" $LINENO
fi
if printf '%s' "$BODY" | grep -qF -e "$EXISTING_ID" -e "$CODE"; then
  cv_fail "expected no product information in the response, found existing product: $BODY" $LINENO
fi

# Cleanup
cv_step Cleanup "nothing to remove: products are in memory and the API has no delete route" $LINENO
echo "created product $CODE (in-memory)"

echo "CODEVALID_TEST_ASSERTION_OK:api_91946224_3"
