#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)$RANDOM"
creds() { jq -nc --arg e "$1" --arg p "$2" '{email:$e,password:$p}'; }
EMAIL="reg3_${SUFFIX}@example.com"
ORIG_PASSWORD="Orig1nalPass_${SUFFIX}"
NEW_PASSWORD="Attack3rPass_${SUFFIX}"

# Given
cv_step Given "an existing account with its original password" $LINENO
cv_http POST /api/auth/register "$(creds "$EMAIL" "$ORIG_PASSWORD")"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected account setup HTTP 201 got $CV_HTTP_STATUS" $LINENO
ORIG_ID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.id // empty')
[ -n "$ORIG_ID" ] || cv_fail "expected an account id from setup got none" $LINENO

# When
cv_step When "a second registration with the same email is submitted" $LINENO
cv_http POST /api/auth/register "$(creds "$EMAIL" "$NEW_PASSWORD")"
DUP_STATUS="$CV_HTTP_STATUS"

# Then
cv_step Then "registration is refused and the account keeps its original password" $LINENO
[ "$DUP_STATUS" = "409" ] || cv_fail "expected HTTP 409 for duplicate email got $DUP_STATUS" $LINENO
cv_http POST /api/auth/login "$(creds "$EMAIL" "$NEW_PASSWORD")"
[ "$CV_HTTP_STATUS" = "401" ] || cv_fail "expected the new password to be rejected (401) got $CV_HTTP_STATUS: password was overwritten" $LINENO
cv_http POST /api/auth/login "$(creds "$EMAIL" "$ORIG_PASSWORD")"
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected the original password to still sign in (200) got $CV_HTTP_STATUS" $LINENO
GOT_ID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.user.id // empty')
[ "$GOT_ID" = "$ORIG_ID" ] || cv_fail "expected the original account $ORIG_ID got '$GOT_ID'" $LINENO

# Cleanup
cv_step Cleanup "nothing to remove: accounts are in memory and the API has no delete route" $LINENO
echo "created account $EMAIL (in-memory)"

echo "CODEVALID_TEST_ASSERTION_OK:api_62493967_3"
