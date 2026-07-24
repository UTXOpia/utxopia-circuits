#!/bin/bash
# Stage circuit artifacts into the exact layout the prover requests, ready to
# upload to the circuit CDN (Cloudflare R2 served at https://circuit.utxopia.com).
#
# Prover fetches:
#   {CDN}/circuits/groth16/<variant>/<variant>.zkey
#   {CDN}/circuits/groth16/<variant>/<variant>_js/<variant>.wasm
#   {CDN}/circuits/groth16/<variant>/<variant>.vkey.json
#
# Usage: bash scripts/stage-cdn.sh   →   ./cdn-upload/circuits/groth16/...
set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="$ROOT/build"
OUT="$ROOT/cdn-upload/circuits/groth16"
rm -rf "$ROOT/cdn-upload"
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
echo "staged $n variants into $ROOT/cdn-upload/"
echo "upload with:  rclone sync \"$ROOT/cdn-upload/\" r2:utxopia-circuits/ --progress"
