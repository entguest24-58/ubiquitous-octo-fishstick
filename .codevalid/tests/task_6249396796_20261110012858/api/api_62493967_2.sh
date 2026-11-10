#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)$RANDOM"
creds() { jq -nc --arg e "$1" --arg p "$2" '{email:$e,password:$p}'; }
EMAIL="reg2_${SUFFIX}@example.com"
PASSWORD="Str0ngPass_${SUFFIX}"

# Given
cv_step Given "registration payloads missing the email and missing the password" $LINENO
NO_EMAIL=$(jq -nc --arg p "$PASSWORD" '{password:$p}')
NO_PASSWORD=$(jq -nc --arg e "$EMAIL" '{email:$e}')

# When
cv_step When "the customer submits each incomplete registration" $LINENO
cv_http POST /api/auth/register "$NO_EMAIL"
S1="$CV_HTTP_STATUS"
cv_http POST /api/auth/register "$NO_PASSWORD"
S2="$CV_HTTP_STATUS"

# Then
cv_step Then "both are refused and no account is created" $LINENO
[ "$S1" = "400" ] || cv_fail "expected HTTP 400 for missing email got $S1" $LINENO
[ "$S2" = "400" ] || cv_fail "expected HTTP 400 for missing password got $S2" $LINENO
cv_http POST /api/auth/login "$(creds "$EMAIL" "$PASSWORD")"
[ "$CV_HTTP_STATUS" = "401" ] || cv_fail "expected no account for $EMAIL (login 401) got $CV_HTTP_STATUS" $LINENO
cv_http POST /api/auth/register "$(creds "$EMAIL" "$PASSWORD")"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected $EMAIL to be still free (register 201) got $CV_HTTP_STATUS" $LINENO

# Cleanup
cv_step Cleanup "nothing to remove: accounts are in memory and the API has no delete route" $LINENO
echo "created account $EMAIL while verifying (in-memory)"

echo "CODEVALID_TEST_ASSERTION_OK:api_62493967_2"
