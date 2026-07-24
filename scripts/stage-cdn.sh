#!/bin/bash
# Stage circuit artifacts into the exact layout the prover requests, ready to
# upload to the circuit CDN (Cloudflare R2 served at https://circuit.utxopia.com).
#
# Prover fetches:
#   {CDN}/circuits/groth16/<variant>/<variant>.zkey
#   {CDN}/circuits/groth16/<variant>/<variant>_js/<variant>.wasm
#   {CDN}/circuits/groth16/<variant>/<variant>.vkey.json
#
# Usage:
#   UTXOPIA_CIRCUITS_BUILD_DIR=build-o2 \
#   UTXOPIA_CDN_STAGE_DIR=cdn-upload-o2 \
#   UTXOPIA_CDN_PREFIX=circuits/v2/groth16 \
#   bash scripts/stage-cdn.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="${UTXOPIA_CIRCUITS_BUILD_DIR:-$ROOT/build}"
STAGE="${UTXOPIA_CDN_STAGE_DIR:-$ROOT/cdn-upload}"
PREFIX="${UTXOPIA_CDN_PREFIX:-circuits/groth16}"
OUT="$STAGE/$PREFIX"

if [ -e "$STAGE" ]; then
  echo "Refusing to overwrite existing stage directory: $STAGE" >&2
  echo "Choose a fresh UTXOPIA_CDN_STAGE_DIR." >&2
  exit 1
fi
mkdir -p "$OUT"

n=0
for d in "$BUILD"/joinsplit_*/; do
  v=$(basename "$d")
  [ -f "$d/$v.zkey" ] || continue
  mkdir -p "$OUT/$v/${v}_js"
  cp "$d/$v.zkey"            "$OUT/$v/$v.zkey"
  cp "$d/$v.vkey.json"       "$OUT/$v/$v.vkey.json"
  cp "$d/${v}_js/$v.wasm"    "$OUT/$v/${v}_js/$v.wasm"
  n=$((n+1))
done
echo "staged $n variants into $STAGE/"
echo "upload with: UTXOPIA_CDN_STAGE_DIR=\"$STAGE\" bash scripts/setup-r2.sh"
