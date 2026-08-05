#!/bin/bash
# Verify the committed vkeys still match what the circuit CDN serves.
#
# The vkey JSONs under build/ are the only build artifacts kept in git (see
# .gitignore): they are the record of the verifying keys anchored on-chain, and
# ops/scripts/_vkupdate.ts sources VkRegistry material from this same CDN. If
# the two drift, anything regenerated from build/ (e.g. scripts/export-vk-rust.js)
# will emit keys that no longer verify the proofs the CDN's zkeys produce.
#
# A recompile changes the constraint system, so *any* rebuild — an optimisation
# flag included — changes every vkey. Re-run this after publishing new artifacts.
#
# Usage:
#   bash scripts/verify-cdn-vkeys.sh
#
# Exit 0 when every published circuit matches, 1 on any mismatch.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BASE="${UTXOPIA_CIRCUIT_CDN_URL:-https://circuit.utxopia.com/circuits/v2/groth16}"

match=0
mismatch=0
unpublished=0

for f in build/*/*.vkey.json; do
  [ -e "$f" ] || continue
  rel="${f#build/}"
  name=$(basename "$(dirname "$f")")
  tmp=$(mktemp)

  code=$(curl -s -o "$tmp" -w "%{http_code}" -L --max-time 40 "$BASE/$rel")
  if [ "$code" != "200" ]; then
    # Variants with n+m > 10 are deliberately not published: the prover refuses
    # to request them (web/src/lib/prover/circuit-artifacts.ts).
    unpublished=$((unpublished + 1))
    rm -f "$tmp"
    continue
  fi

  if cmp -s "$f" "$tmp"; then
    match=$((match + 1))
  else
    mismatch=$((mismatch + 1))
    echo "MISMATCH $name — committed vkey differs from $BASE/$rel"
  fi
  rm -f "$tmp"
done

echo "matched=$match mismatched=$mismatch unpublished=$unpublished"

if [ "$mismatch" -ne 0 ]; then
  echo "Committed vkeys are stale. Refresh them from the CDN (the deployed truth)," >&2
  echo "or re-publish artifacts if the local build is the intended one." >&2
  exit 1
fi
