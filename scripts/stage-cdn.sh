#!/bin/bash
# Stage circuit artifacts into the exact layout the prover requests, ready to
# upload to the circuit CDN (Cloudflare R2 served at https://circuit.utxopia.com).
#
# Prover fetches (v2 is the only maintained prefix; v1 is frozen):
#   {CDN}/circuits/v2/groth16/<variant>/<variant>.zkey
#   {CDN}/circuits/v2/groth16/<variant>/<variant>_js/<variant>.wasm
#   {CDN}/circuits/v2/groth16/<variant>/<variant>.vkey.json
#
# Usage:
#   UTXOPIA_CIRCUITS_BUILD_DIR=build-o2 \
#   UTXOPIA_CDN_STAGE_DIR=cdn-upload-o2 \
#   bash scripts/stage-cdn.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="${UTXOPIA_CIRCUITS_BUILD_DIR:-$ROOT/build}"
STAGE="${UTXOPIA_CDN_STAGE_DIR:-$ROOT/cdn-upload}"
PREFIX="${UTXOPIA_CDN_PREFIX:-circuits/v2/groth16}"
OUT="$STAGE/$PREFIX"

if [ -e "$STAGE" ]; then
  echo "Refusing to overwrite existing stage directory: $STAGE" >&2
  echo "Choose a fresh UTXOPIA_CDN_STAGE_DIR." >&2
  exit 1
fi
mkdir -p "$OUT"

# Aux circuits share the joinsplit layout, so stage both from one loop.
AUX="${UTXOPIA_AUX_CIRCUITS:-ownership range_sum range_sum_4 range_sum_16}"

n=0
for d in "$BUILD"/joinsplit_*/ $(for a in $AUX; do echo "$BUILD/$a/"; done); do
  v=$(basename "$d")
  [ -f "$d/$v.zkey" ] || continue
  mkdir -p "$OUT/$v/${v}_js"
  cp "$d/$v.zkey"            "$OUT/$v/$v.zkey"
  cp "$d/$v.vkey.json"       "$OUT/$v/$v.vkey.json"
  cp "$d/${v}_js/$v.wasm"    "$OUT/$v/${v}_js/$v.wasm"
  n=$((n+1))
done
echo "staged $n circuits into $STAGE/"
echo "upload with: UTXOPIA_CDN_STAGE_DIR=\"$STAGE\" bash scripts/setup-r2.sh"
