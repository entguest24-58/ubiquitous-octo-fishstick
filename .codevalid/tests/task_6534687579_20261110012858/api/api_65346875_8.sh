#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)$RANDOM"
CODE="SKU-ANON-${SUFFIX}"
BODY=$(jq -nc --arg n "Anon $SUFFIX" --arg c "$CODE" '{name:$n,description:"Sneaky item",price:3.5,code:$c}')

# Given
cv_step Given "a visitor who is not signed in and the current catalog" $LINENO
cv_http GET /api/products
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected catalog 200 got $CV_HTTP_STATUS" $LINENO
N0=$(jq --arg c "$CODE" '[.[] | select(.code == $c)] | length' <<<"$CV_HTTP_BODY")
[ "$N0" = "0" ] || cv_fail "expected code $CODE unused got $N0" $LINENO

# When
cv_step When "the visitor tries to add a valid product without signing in" $LINENO
cv_http POST /api/products "$BODY"
ST="$CV_HTTP_STATUS"; RB="$CV_HTTP_BODY"

# Then
cv_step Then "the product is not created and the catalog stays unchanged" $LINENO
case "$ST" in 2??) cv_fail "expected refusal, anonymous POST returned $ST: $RB" $LINENO ;; esac
cv_http GET /api/products
N=$(jq --arg c "$CODE" '[.[] | select(.code == $c)] | length' <<<"$CV_HTTP_BODY")
[ "$N" = "0" ] || cv_fail "expected no product with code $CODE in catalog, anonymous add created $N" $LINENO

# Cleanup
cv_step Cleanup "nothing to remove: nothing was created" $LINENO

echo "CODEVALID_TEST_ASSERTION_OK:api_65346875_8"
