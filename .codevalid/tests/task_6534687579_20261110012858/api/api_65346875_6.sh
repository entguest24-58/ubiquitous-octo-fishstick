#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)$RANDOM"
UNKNOWN_ID="00000000-0000-4000-8000-$(printf '%06d%06d' "$RANDOM" "$RANDOM")"

# Given
cv_step Given "an identifier that belongs to no product" $LINENO
cv_http GET /api/products
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected catalog 200 got $CV_HTTP_STATUS" $LINENO
N=$(jq --arg id "$UNKNOWN_ID" '[.[] | select(.id == $id)] | length' <<<"$CV_HTTP_BODY")
[ "$N" = "0" ] || cv_fail "expected $UNKNOWN_ID to match no product got $N" $LINENO

# When
cv_step When "a visitor opens a product with the unknown identifier" $LINENO
cv_http GET "/api/products/$UNKNOWN_ID"
ST="$CV_HTTP_STATUS"; RB="$CV_HTTP_BODY"

# Then
cv_step Then "no product data is returned and the visitor is told it was not found" $LINENO
[ "$ST" = "404" ] || cv_fail "expected 404 got $ST" $LINENO
HAS=$(jq -r 'if type=="object" then (has("name") or has("code") or has("price")) else false end' <<<"$RB")
[ "$HAS" = "false" ] || cv_fail "expected no product data got $RB" $LINENO

# Cleanup
cv_step Cleanup "nothing to remove: nothing was created" $LINENO

echo "CODEVALID_TEST_ASSERTION_OK:api_65346875_6"
