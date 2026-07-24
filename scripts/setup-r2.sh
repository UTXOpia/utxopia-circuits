#!/bin/bash
# One-command upload of staged circuit artifacts to Cloudflare R2.
#
# Credentials come from YOUR environment (never committed, never shared):
#   export R2_ACCOUNT_ID=<your-cloudflare-account-id>
#   export R2_ACCESS_KEY_ID=...        # R2 → Manage R2 API Tokens (Object Read & Write)
#   export R2_SECRET_ACCESS_KEY=...
#   export R2_BUCKET=utxopia-circuits  # optional, defaults below
#
# Prereqs: rclone  (macOS: `brew install rclone`)
# Run:     cd circuits && bash scripts/stage-cdn.sh && bash scripts/setup-r2.sh
set -euo pipefail

BUCKET="${R2_BUCKET:-utxopia-circuits}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${UTXOPIA_CDN_STAGE_DIR:-$ROOT/cdn-upload}"

command -v rclone >/dev/null 2>&1 || { echo "Install rclone first:  brew install rclone"; exit 1; }
: "${R2_ACCOUNT_ID:?set R2_ACCOUNT_ID}"
: "${R2_ACCESS_KEY_ID:?set R2_ACCESS_KEY_ID}"
: "${R2_SECRET_ACCESS_KEY:?set R2_SECRET_ACCESS_KEY}"
[ -d "$SRC" ] || { echo "Run scripts/stage-cdn.sh first ($SRC missing)"; exit 1; }

ENDPOINT="https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com"
RC=(--s3-provider Cloudflare --s3-access-key-id "$R2_ACCESS_KEY_ID"
    --s3-secret-access-key "$R2_SECRET_ACCESS_KEY" --s3-endpoint "$ENDPOINT"
    --s3-no-check-bucket)

echo "Uploading $(du -sh "$SRC" | cut -f1) → r2:${BUCKET} ($ENDPOINT)"
rclone copy "$SRC/" ":s3:${BUCKET}/" "${RC[@]}" \
  --header-upload "Cache-Control: public, max-age=31536000, immutable" \
  --transfers 8 --checkers 16 --progress

echo ""
echo "Upload done. Remaining (dashboard — can't be scripted safely):"
echo "  1. R2 → ${BUCKET} → Settings → Custom Domains → Connect 'circuit.utxopia.com'"
echo "  2. R2 → ${BUCKET} → Settings → CORS → allow GET/HEAD from your web origins"
echo "  3. Web env: NEXT_PUBLIC_CIRCUIT_CDN_URL=https://circuit.utxopia.com  (then redeploy)"
echo ""
echo "Verify the exact versioned URL staged in ${SRC}."
