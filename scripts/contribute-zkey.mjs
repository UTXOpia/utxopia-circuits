#!/usr/bin/env node

import { randomBytes } from "node:crypto";
import { zKey } from "snarkjs";

const [inputPath, outputPath, contributionName = "UTXOpia devnet O2 migration"] =
  process.argv.slice(2);

if (!inputPath || !outputPath) {
  console.error("Usage: node scripts/contribute-zkey.mjs <input.zkey> <output.zkey> [name]");
  process.exit(1);
}

// Keep the entropy inside this process. Passing it through CLI arguments would
// expose it to process-list readers while the contribution is running.
const entropy = randomBytes(64).toString("hex");
await zKey.contribute(inputPath, outputPath, contributionName, entropy);
process.exit(0);
