#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)$RANDOM"
creds() { jq -nc --arg e "$1" --arg p "$2" '{email:$e,password:$p}'; }
EMAIL="reg6_${SUFFIX}@example.com"
PASSWORD="Str0ngPass_${SUFFIX}"

# Given
cv_step Given "a customer registered while the service keeps running" $LINENO
cv_http POST /api/auth/register "$(creds "$EMAIL" "$PASSWORD")"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected account setup HTTP 201 got $CV_HTTP_STATUS" $LINENO
sleep 2

# When
cv_step When "a later registration with the same email is attempted" $LINENO
cv_http POST /api/auth/register "$(creds "$EMAIL" "Other_${PASSWORD}")"
DUP_STATUS="$CV_HTTP_STATUS"

# Then
cv_step Then "the attempt is refused and the account is still kept" $LINENO
[ "$DUP_STATUS" = "409" ] || cv_fail "expected HTTP 409 for the kept account got $DUP_STATUS" $LINENO
cv_http POST /api/auth/login "$(creds "$EMAIL" "$PASSWORD")"
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected the kept account to sign in (200) got $CV_HTTP_STATUS" $LINENO

# Cleanup
cv_step Cleanup "nothing to remove: accounts are in memory and the API has no delete route" $LINENO
echo "created account $EMAIL (in-memory)"

echo "CODEVALID_TEST_ASSERTION_OK:api_62493967_6"
