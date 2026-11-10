#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)$RANDOM"
creds() { jq -nc --arg e "$1" --arg p "$2" '{email:$e,password:$p}'; }
product_json() { jq -nc --arg n "$1" --arg d "$2" --argjson p "$3" --arg c "$4" '{name:$n,description:$d,price:$p,code:$c}'; }
EMAIL="cat2_${SUFFIX}@example.com"
PASSWORD="Str0ngPass_${SUFFIX}"
CODE_A="CAT2A-${SUFFIX}"
CODE_B="CAT2B-${SUFFIX}"

# Given
cv_step Given "a signed-in seller has added two products to the catalog" $LINENO
cv_prereq "register and sign in a seller" $LINENO
cv_http POST /api/auth/register "$(creds "$EMAIL" "$PASSWORD")" 201
cv_http POST /api/auth/login "$(creds "$EMAIL" "$PASSWORD")" 200
TOKEN=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.token // empty')
[ -n "$TOKEN" ] || cv_fail "expected a sign-in token got none" $LINENO
cv_prereq "create the target product and another product" $LINENO
cv_http POST /api/products "$(product_json "Lamp $SUFFIX" "Desk lamp" 29.99 "$CODE_A")" 201 -H "Authorization: Bearer $TOKEN"
ID_A=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.id // empty')
cv_http POST /api/products "$(product_json "Chair $SUFFIX" "Office chair" 99 "$CODE_B")" 201 -H "Authorization: Bearer $TOKEN"
ID_B=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.id // empty')
{ [ -n "$ID_A" ] && [ -n "$ID_B" ]; } || cv_fail "expected ids for both created products got '$ID_A' '$ID_B'" $LINENO

# When
cv_step When "an anonymous visitor opens the lamp by its identifier" $LINENO
cv_http GET "/api/products/$ID_A"
STATUS="$CV_HTTP_STATUS"; BODY="$CV_HTTP_BODY"

# Then
cv_step Then "only the lamp is returned with its name, description, price and code" $LINENO
[ "$STATUS" = "200" ] || cv_fail "expected HTTP 200 for anonymous product view got $STATUS" $LINENO
printf '%s' "$BODY" | jq -e 'type == "object"' >/dev/null || cv_fail "expected a single product object got $BODY" $LINENO
printf '%s' "$BODY" | jq -e --arg id "$ID_A" --arg n "Lamp $SUFFIX" --arg c "$CODE_A" \
  '.id == $id and .name == $n and .description == "Desk lamp" and .price == 29.99 and .code == $c' >/dev/null \
  || cv_fail "expected lamp $ID_A with name 'Lamp $SUFFIX', description 'Desk lamp', price 29.99, code $CODE_A got $BODY" $LINENO
if printf '%s' "$BODY" | grep -qF -e "$ID_B" -e "$CODE_B"; then
  cv_fail "expected no other product in the response, found chair $ID_B: $BODY" $LINENO
fi

# Cleanup
cv_step Cleanup "nothing to remove: products are in memory and the API has no delete route" $LINENO
echo "created products $CODE_A $CODE_B (in-memory)"

echo "CODEVALID_TEST_ASSERTION_OK:api_91946224_2"
