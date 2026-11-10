#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)$RANDOM"
creds() { jq -nc --arg e "$1" --arg p "$2" '{email:$e,password:$p}'; }
EMAIL="reg1_${SUFFIX}@example.com"
PASSWORD="Str0ngPass_${SUFFIX}"

# Given
cv_step Given "an email address not yet registered and a password" $LINENO
cv_http POST /api/auth/login "$(creds "$EMAIL" "$PASSWORD")"
[ "$CV_HTTP_STATUS" = "401" ] || cv_fail "expected no account for $EMAIL yet (login 401) got $CV_HTTP_STATUS" $LINENO

# When
cv_step When "the customer registers with the email and password" $LINENO
cv_http POST /api/auth/register "$(creds "$EMAIL" "$PASSWORD")"
REG_STATUS="$CV_HTTP_STATUS"; REG_BODY="$CV_HTTP_BODY"

# Then
cv_step Then "the account is created, identified by its email, and can sign in" $LINENO
[ "$REG_STATUS" = "201" ] || cv_fail "expected HTTP 201 from register got $REG_STATUS" $LINENO
GOT_EMAIL=$(printf '%s' "$REG_BODY" | jq -r '.email // empty')
[ "$GOT_EMAIL" = "$EMAIL" ] || cv_fail "expected response email $EMAIL got '$GOT_EMAIL'" $LINENO
GOT_ID=$(printf '%s' "$REG_BODY" | jq -r '.id // empty')
[ -n "$GOT_ID" ] || cv_fail "expected an account id in the response got none" $LINENO
cv_http POST /api/auth/login "$(creds "$EMAIL" "$PASSWORD")"
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected the new account to sign in (200) got $CV_HTTP_STATUS" $LINENO
[ "$(printf '%s' "$CV_HTTP_BODY" | jq -r '.user.id // empty')" = "$GOT_ID" ] || cv_fail "expected signed-in user id $GOT_ID" $LINENO

# Cleanup
cv_step Cleanup "nothing to remove: accounts are in memory and the API has no delete route" $LINENO
echo "created account $EMAIL (in-memory)"

echo "CODEVALID_TEST_ASSERTION_OK:api_62493967_1"
