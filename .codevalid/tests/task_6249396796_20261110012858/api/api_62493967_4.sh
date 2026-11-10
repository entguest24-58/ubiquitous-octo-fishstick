#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)$RANDOM"
creds() { jq -nc --arg e "$1" --arg p "$2" '{email:$e,password:$p}'; }
EMAIL="reg4_${SUFFIX}@example.com"
PASSWORD="Pr1vatePass_${SUFFIX}"
leaks() {
  # password in plain form, a password/hash field, or a salt:key scrypt-style hash
  printf '%s' "$1" | grep -qF "$PASSWORD" && return 0
  printf '%s' "$1" | jq -e '[paths | .[-1] | strings | ascii_downcase | select(test("password|hash|salt"))] | length > 0' >/dev/null 2>&1 && return 0
  printf '%s' "$1" | grep -qE '[0-9a-fA-F]{32}:[0-9a-fA-F]{64,}' && return 0
  return 1
}

# Given
cv_step Given "a new customer email and password" $LINENO
cv_prereq "credentials $EMAIL prepared" $LINENO

# When
cv_step When "the customer registers" $LINENO
cv_http POST /api/auth/register "$(creds "$EMAIL" "$PASSWORD")"
REG_STATUS="$CV_HTTP_STATUS"; REG_BODY="$CV_HTTP_BODY"

# Then
cv_step Then "neither the registration response nor the sign-in account data contains the password" $LINENO
[ "$REG_STATUS" = "201" ] || cv_fail "expected HTTP 201 from register got $REG_STATUS" $LINENO
if leaks "$REG_BODY"; then cv_fail "expected no password or hash in register response got $REG_BODY" $LINENO; fi
cv_http POST /api/auth/login "$(creds "$EMAIL" "$PASSWORD")"
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected sign-in 200 got $CV_HTTP_STATUS" $LINENO
USER_JSON=$(printf '%s' "$CV_HTTP_BODY" | jq -c '.user')
if leaks "$USER_JSON"; then cv_fail "expected no password or hash in sign-in account data got $USER_JSON" $LINENO; fi
cv_http POST /api/auth/register "$(creds "$EMAIL" "$PASSWORD")"
if leaks "$CV_HTTP_BODY"; then cv_fail "expected no password or hash in duplicate-register response got $CV_HTTP_BODY" $LINENO; fi

# Cleanup
cv_step Cleanup "nothing to remove: accounts are in memory and the API has no delete route" $LINENO
echo "created account $EMAIL (in-memory)"

echo "CODEVALID_TEST_ASSERTION_OK:api_62493967_4"
