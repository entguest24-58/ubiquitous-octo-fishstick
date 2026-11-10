#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)$RANDOM"
creds() { jq -nc --arg e "$1" --arg p "$2" '{email:$e,password:$p}'; }
product_json() { jq -nc --arg n "$1" --arg d "$2" --argjson p "$3" --arg c "$4" '{name:$n,description:$d,price:$p,code:$c}'; }
EMAIL="cat1_${SUFFIX}@example.com"
PASSWORD="Str0ngPass_${SUFFIX}"
CODE_A="CAT1A-${SUFFIX}"
CODE_B="CAT1B-${SUFFIX}"

# Given
cv_step Given "a signed-in seller has added two products to the catalog" $LINENO
cv_prereq "register and sign in a seller" $LINENO
cv_http POST /api/auth/register "$(creds "$EMAIL" "$PASSWORD")" 201
cv_http POST /api/auth/login "$(creds "$EMAIL" "$PASSWORD")" 200
TOKEN=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.token // empty')
[ -n "$TOKEN" ] || cv_fail "expected a sign-in token got none" $LINENO
cv_prereq "create two products" $LINENO
cv_http POST /api/products "$(product_json "Widget A $SUFFIX" "First widget" 12.5 "$CODE_A")" 201 -H "Authorization: Bearer $TOKEN"
ID_A=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.id // empty')
cv_http POST /api/products "$(product_json "Widget B $SUFFIX" "Second widget" 0 "$CODE_B")" 201 -H "Authorization: Bearer $TOKEN"
ID_B=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.id // empty')
{ [ -n "$ID_A" ] && [ -n "$ID_B" ]; } || cv_fail "expected ids for both created products got '$ID_A' '$ID_B'" $LINENO

# When
cv_step When "an anonymous visitor requests the full catalog" $LINENO
cv_http GET /api/products
STATUS="$CV_HTTP_STATUS"; BODY="$CV_HTTP_BODY"

# Then
cv_step Then "both products are listed with name, description, price and code" $LINENO
[ "$STATUS" = "200" ] || cv_fail "expected HTTP 200 for anonymous catalog got $STATUS" $LINENO
printf '%s' "$BODY" | jq -e 'type == "array"' >/dev/null || cv_fail "expected a JSON array of products got $BODY" $LINENO
check() {
  local id="$1" name="$2" desc="$3" price="$4" code="$5" item
  item=$(printf '%s' "$BODY" | jq -c --arg id "$id" '[.[] | select(.id == $id)]')
  [ "$(printf '%s' "$item" | jq 'length')" = "1" ] || cv_fail "expected product $id exactly once in catalog got $item" $LINENO
  printf '%s' "$item" | jq -e --arg n "$name" --arg d "$desc" --argjson p "$price" --arg c "$code" \
    '.[0] | .name == $n and .description == $d and .price == $p and .code == $c' >/dev/null \
    || cv_fail "expected product $id to have name '$name', description '$desc', price $price, code '$code' got $item" $LINENO
}
check "$ID_A" "Widget A $SUFFIX" "First widget" 12.5 "$CODE_A"
check "$ID_B" "Widget B $SUFFIX" "Second widget" 0 "$CODE_B"
printf '%s' "$BODY" | jq -e 'all(.[]; has("name") and has("description") and has("price") and has("code"))' >/dev/null \
  || cv_fail "expected every catalog product to carry name, description, price and code" $LINENO

# Cleanup
cv_step Cleanup "nothing to remove: products are in memory and the API has no delete route" $LINENO
echo "created products $CODE_A $CODE_B (in-memory)"

echo "CODEVALID_TEST_ASSERTION_OK:api_91946224_1"
