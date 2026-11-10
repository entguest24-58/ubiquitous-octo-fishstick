#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)$RANDOM"
EMAIL="cust10_${SUFFIX}@example.com"
PASSWORD="Secr3tPw_${SUFFIX}"
OTHER_EMAIL="other10_${SUFFIX}@example.com"
OTHER_PASSWORD="0therPw_${SUFFIX}"
CODE="SKU10-${SUFFIX}"
register_and_login() {
  # $1 email, $2 password; sets TOKEN
  cv_http POST /api/auth/register "$(jq -nc --arg e "$1" --arg p "$2" '{email:$e,password:$p}')" 201
  cv_http POST /api/auth/login "$(jq -nc --arg e "$1" --arg p "$2" '{email:$e,password:$p}')" 200
  TOKEN=$(printf "%s" "$CV_HTTP_BODY" | jq -r ".token // empty")
  [ -n "$TOKEN" ] || cv_fail "expected a token from sign-in got none" $LINENO
}

check_no_password() {
  # $1 label, $2 body
  if printf '%s' "$2" | jq -e '[.. | objects | keys[] | ascii_downcase | select(test("password|hash|salt"))] | length > 0' >/dev/null 2>&1; then
    cv_fail "expected no password/hash field in $1 got: $2" $LINENO
  fi
  case "$2" in *"$PASSWORD"*) cv_fail "expected customer's password absent from $1 got it in the body" $LINENO ;; esac
  case "$2" in *"$OTHER_PASSWORD"*) cv_fail "expected other customer's password absent from $1 got it in the body" $LINENO ;; esac
}

# Given
cv_step Given "two registered customers; the other one adds a product" $LINENO
cv_http POST /api/auth/register "$(jq -nc --arg e "$EMAIL" --arg p "$PASSWORD" '{email:$e,password:$p}')" 201
REGISTER_BODY="$CV_HTTP_BODY"
register_and_login "$OTHER_EMAIL" "$OTHER_PASSWORD"
cv_http POST /api/products "$(jq -nc --arg c "$CODE" '{name:"Other desk",description:"pine desk",price:120,code:$c}')" 201 -H "Authorization: Bearer $TOKEN"
PRODUCT_ID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.id // empty')
[ -n "$PRODUCT_ID" ] || cv_fail "expected product id from create got none" $LINENO

# When
cv_step When "the customer signs in, then account and catalog data are read" $LINENO
cv_http POST /api/auth/login "$(jq -nc --arg e "$EMAIL" --arg p "$PASSWORD" '{email:$e,password:$p}')"
LOGIN_STATUS="$CV_HTTP_STATUS"; LOGIN_BODY="$CV_HTTP_BODY"
cv_http GET /api/products
LIST_STATUS="$CV_HTTP_STATUS"; LIST_BODY="$CV_HTTP_BODY"
cv_http GET "/api/products/$PRODUCT_ID"
ONE_STATUS="$CV_HTTP_STATUS"; ONE_BODY="$CV_HTTP_BODY"

# Then
cv_step Then "no response contains a password or password hash" $LINENO
[ "$LOGIN_STATUS" = "200" ] || cv_fail "expected sign-in HTTP 200 got $LOGIN_STATUS" $LINENO
[ "$LIST_STATUS" = "200" ] || cv_fail "expected catalog HTTP 200 got $LIST_STATUS" $LINENO
[ "$ONE_STATUS" = "200" ] || cv_fail "expected product HTTP 200 got $ONE_STATUS" $LINENO
printf '%s' "$LOGIN_BODY" | jq -e '.user.email != null' >/dev/null || cv_fail "expected account info (user) in sign-in response got $LOGIN_BODY" $LINENO
check_no_password "register response" "$REGISTER_BODY"
check_no_password "sign-in response" "$LOGIN_BODY"
check_no_password "catalog list" "$LIST_BODY"
check_no_password "product detail" "$ONE_BODY"

# Cleanup
cv_step Cleanup "nothing to remove: data is in memory and the API has no delete routes" $LINENO
echo "created accounts $EMAIL, $OTHER_EMAIL and product $PRODUCT_ID (in-memory, no delete endpoint)"

echo "CODEVALID_TEST_ASSERTION_OK:api_40124224_10"
