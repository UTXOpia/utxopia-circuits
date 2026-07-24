#!/bin/bash
# Idempotently add/update the Cloudflare Cache Rule used by the R2 circuit CDN.
#
# Required token permission: Zone > Cache Rules > Edit
# Usage:
#   export CLOUDFLARE_API_TOKEN=...
#   export CLOUDFLARE_ZONE_ID=...
#   bash scripts/configure-cache-rule.sh
set -euo pipefail

: "${CLOUDFLARE_API_TOKEN:?set CLOUDFLARE_API_TOKEN}"
: "${CLOUDFLARE_ZONE_ID:?set CLOUDFLARE_ZONE_ID}"

CDN_HOST="${CIRCUIT_CDN_HOST:-circuit.utxopia.com}"
API_ROOT="https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}"
RULE_REF="utxopia_circuit_artifacts"

command -v curl >/dev/null 2>&1 || { echo "curl is required"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq is required"; exit 1; }

api() {
  local method="$1"
  local path="$2"
  local body="${3:-}"
  local args=(
    --silent
    --show-error
    --request "$method"
    --header "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}"
    --header "Content-Type: application/json"
  )
  if [ -n "$body" ]; then
    args+=(--data "$body")
  fi
  curl "${args[@]}" "${API_ROOT}${path}"
}

assert_success() {
  local response="$1"
  if [ "$(jq -r '.success' <<<"$response")" != "true" ]; then
    jq -r '.errors[]? | "\(.code): \(.message)"' <<<"$response" >&2
    exit 1
  fi
}

rule_payload="$(jq -n \
  --arg host "$CDN_HOST" \
  --arg ref "$RULE_REF" \
  '{
    expression: ("(http.host eq \"" + $host + "\" and starts_with(http.request.uri.path, \"/circuits/\"))"),
    description: "Cache immutable UTXOpia circuit artifacts at the Cloudflare edge",
    ref: $ref,
    action: "set_cache_settings",
    action_parameters: {
      cache: true,
      edge_ttl: {
        mode: "override_origin",
        default: 31536000,
        status_code_ttl: [
          {status_code_range: {from: 200, to: 299}, value: 31536000},
          {status_code_range: {from: 300, to: 499}, value: 0},
          {status_code_range: {from: 500, to: 599}, value: -1}
        ]
      },
      browser_ttl: {mode: "respect_origin"}
    },
    enabled: true
  }')"

rulesets_response="$(api GET "/rulesets")"
assert_success "$rulesets_response"
ruleset_id="$(jq -r '
  first(.result[] | select(
    .kind == "zone" and .phase == "http_request_cache_settings"
  ) | .id) // empty
' <<<"$rulesets_response")"

if [ -z "$ruleset_id" ]; then
  create_payload="$(jq -n \
    --argjson rule "$rule_payload" \
    '{
      name: "Zone-level cache settings",
      description: "Zone-level cache settings",
      kind: "zone",
      phase: "http_request_cache_settings",
      rules: [$rule]
    }')"
  response="$(api POST "/rulesets" "$create_payload")"
  assert_success "$response"
  echo "Created circuit cache rule."
else
  ruleset_response="$(api GET "/rulesets/${ruleset_id}")"
  assert_success "$ruleset_response"
  rule_id="$(jq -r --arg ref "$RULE_REF" '
    first(.result.rules[]? | select(.ref == $ref) | .id) // empty
  ' <<<"$ruleset_response")"

  if [ -n "$rule_id" ]; then
    response="$(api PATCH "/rulesets/${ruleset_id}/rules/${rule_id}" "$rule_payload")"
    assert_success "$response"
    echo "Updated circuit cache rule."
  else
    response="$(api POST "/rulesets/${ruleset_id}/rules" "$rule_payload")"
    assert_success "$response"
    echo "Added circuit cache rule."
  fi
fi

VERIFY_PATH="${CIRCUIT_CDN_VERIFY_PATH:-/circuits/v2/groth16/joinsplit_1x1/joinsplit_1x1.vkey.json}"
VERIFY_URL="https://${CDN_HOST}${VERIFY_PATH}"
echo "Warming and checking ${VERIFY_URL}"
for attempt in 1 2; do
  cache_status="$(
    curl --silent --show-error --dump-header - --output /dev/null "$VERIFY_URL" |
      awk 'BEGIN { IGNORECASE=1 } /^cf-cache-status:/ { gsub("\r", "", $2); print $2 }'
  )"
  echo "Request ${attempt}: cf-cache-status=${cache_status:-missing}"
done
