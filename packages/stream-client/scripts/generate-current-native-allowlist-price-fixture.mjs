// Encoding provenance for the additive native allowlist price consumer.
import { createHash } from "node:crypto";
import { readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

const COMMIT = "f1745f33be3e601aca75a89ffe428f534a352615";
const TREE = "b4d68b320f8a7dfde2b5f4caba4218b8713b27b3";
const INPUT_SHA = "c59a2da7dcecfa40e5b3e9ac4223bcc4ed111c5bfd2edc46c9c49b093289b7e6";
const OUTPUT_SHA = "c2e32bb4330404d4a923d810b4a32a801eeaf9ff2f9b478cbefbb0201b51b677";
const sha = bytes => createHash("sha256").update(bytes).digest("hex");
const paths = [
  "smart-contracts/domains/mint/StreamNativeFixedPriceSaleAdapter.sol",
  "smart-contracts/domains/mint/StreamNativeImmediateSaleWorker.sol",
  "smart-contracts/domains/mint/StreamNativePriceProgram.sol",
  "smart-contracts/domains/mint/StreamMintSaleAllowlist.sol",
  "smart-contracts/domains/mint/StreamMintCounterPolicy.sol",
  "smart-contracts/interfaces/stream/mint/IStreamNativeAllowlistPricePrograms.sol",
  "smart-contracts/interfaces/stream/mint/IStreamNativePricePrograms.sol",
  "smart-contracts/interfaces/stream/revenue/StreamNativeSettlementTypes.sol",
];
const methods = ["registerAllowlistPriceProgram", "allowlistPricePolicy", "previewAllowlistPriceProgram",
  "executeAllowlistPriceProgram", "priceProgramIdFor", "priceProgramRecord", "priceProgramAuthorizationDigest",
  "saleRevealQuote", "nextSaleNonce", "owner", "core", "mintManager"];

export function currentNativeAllowlistPriceFixture(inputBytes, outputBytes) {
  if (sha(inputBytes) !== INPUT_SHA || sha(outputBytes) !== OUTPUT_SHA) {
    throw Error("Compiler capture differs from the reviewed native allowlist price capture");
  }
  const input = JSON.parse(inputBytes), output = JSON.parse(outputBytes);
  if (input.language !== "Solidity" || Object.keys(input.sources ?? {}).length !== 159
    || output.errors?.some(error => error.severity === "error")) {
    throw Error("Expected the clean 159-source native allowlist price ABI capture");
  }
  const sources = {};
  for (const path of paths) {
    const source = input.sources?.[path]?.content;
    if (typeof source !== "string") throw Error(`Missing source ${path}`);
    sources[path] = sha(source);
  }
  const full = output.contracts?.[paths[0]]?.StreamNativeFixedPriceSaleAdapter?.abi;
  if (!Array.isArray(full)) throw Error("Missing native sale adapter compiler ABI");
  const abi = full.filter(item => item.type === "function" && methods.includes(item.name));
  if (abi.length !== methods.length || methods.some(name => !abi.some(item => item.name === name))) {
    throw Error("Incomplete selected native allowlist price ABI");
  }
  return { schemaVersion: 1, sourceCommit: COMMIT, sourceTree: TREE, sourceCount: 159,
    compilerVersion: "0.8.19", sourceNormalization: "UTF-8 CRLF to LF",
    qualification: "Selected ABI and source encoding evidence only; no native-runtime, live eligibility, signature, payment, or release acceptance claim.",
    inputSha256: INPUT_SHA, outputSha256: OUTPUT_SHA, sources, methods, abi };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [input, output, mode] = process.argv.slice(2);
  if (!input || !output || (mode !== undefined && mode !== "--check")) {
    throw Error("Usage: generate-current-native-allowlist-price-fixture.mjs INPUT OUTPUT [--check]");
  }
  const file = new URL("../test/fixtures/current-native-allowlist-price-abi.json", import.meta.url);
  const rendered = JSON.stringify(currentNativeAllowlistPriceFixture(await readFile(input), await readFile(output)), null, 2) + "\n";
  if (mode === "--check") {
    if (await readFile(file, "utf8") !== rendered) throw Error("Stale native allowlist price ABI fixture");
  } else await writeFile(file, rendered, "utf8");
}
