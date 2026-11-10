#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)$RANDOM"
EMAIL="cust2_${SUFFIX}@example.com"
PASSWORD="Str0ngPass_${SUFFIX}"

# Given
cv_step Given "a registered customer account" $LINENO
cv_http POST /api/auth/register "$(jq -nc --arg e "$EMAIL" --arg p "$PASSWORD" '{email:$e,password:$p}')" 201

# When
cv_step When "sign-in requests leave out the password, then the email" $LINENO
cv_http POST /api/auth/login "$(jq -nc --arg e "$EMAIL" '{email:$e}')"
NO_PW_STATUS="$CV_HTTP_STATUS"; NO_PW_BODY="$CV_HTTP_BODY"
cv_http POST /api/auth/login "$(jq -nc --arg p "$PASSWORD" '{password:$p}')"
NO_EMAIL_STATUS="$CV_HTTP_STATUS"; NO_EMAIL_BODY="$CV_HTTP_BODY"

# Then
cv_step Then "both sign-ins are refused with 400 and no token is issued" $LINENO
[ "$NO_PW_STATUS" = "400" ] || cv_fail "expected HTTP 400 when password is missing got $NO_PW_STATUS" $LINENO
[ "$NO_EMAIL_STATUS" = "400" ] || cv_fail "expected HTTP 400 when email is missing got $NO_EMAIL_STATUS" $LINENO
T1=$(printf '%s' "$NO_PW_BODY" | jq -r '.token // empty' 2>/dev/null || true)
T2=$(printf '%s' "$NO_EMAIL_BODY" | jq -r '.token // empty' 2>/dev/null || true)
[ -z "$T1" ] || cv_fail "expected no token when password is missing got one" $LINENO
[ -z "$T2" ] || cv_fail "expected no token when email is missing got one" $LINENO

# Cleanup
cv_step Cleanup "nothing to remove: data is in memory and the API has no delete routes" $LINENO
echo "created account $EMAIL (in-memory, no delete endpoint)"

echo "CODEVALID_TEST_ASSERTION_OK:api_40124224_2"
