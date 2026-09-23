// Project the five original counter accounting views from exact frozen ABI65; never compile.
import { createHash } from "node:crypto";
import { readFile, writeFile } from "node:fs/promises";
import { posix, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const INPUT_SHA = "dc9032a36b5a9d54c9a6f75259ad15057131dede213bbb6a315f2129154c8f13";
const OUTPUT_SHA = "557bfe82dd881dc2f3db2b624219ecdf8d67512f4ed3f4cd5b2215728d97205f";
const SOURCE_COMMIT = "ea92b7d41ae9e9eede2a00f2c12b70543f125307";
const sha = raw => createHash("sha256").update(raw).digest("hex");
const mint = "smart-contracts/domains/mint/", interfaces = "smart-contracts/interfaces/stream/mint/";
const managerMethods = ["rawCounterValue", "counterValue", "remainingForCounter", "resolveCounter", "remainingForResolvedCounter",
  "mintLedger", "isStreamMintManager", "supportsInterface", "phase", "counterConfig", "previewCounterValueKey",
  "isAuthorizationUsed", "isNullifierUsed", "isOperationRootUsed", "phasePolicyGrace"];
const selections = {
  manager: { source: mint + "StreamMintManager.sol", contract: "StreamMintManager", methods: managerMethods },
  fallback: { source: mint + "StreamMintManagerFallback.sol", contract: "StreamMintManagerFallback", methods: managerMethods },
  ledger: { source: mint + "StreamMintLedger.sol", contract: "StreamMintLedger", methods: [
    "isStreamMintLedger", "supportsInterface", "counterValue", "deriveCounterValueKey", "counterDefinitionForManager",
  ] },
  counterReadsInterface: { source: interfaces + "IStreamMintCounterReads.sol", contract: "IStreamMintCounterReads", full: true },
  counterPolicyInterface: { source: interfaces + "IStreamMintCounterPolicy.sol", contract: "IStreamMintCounterPolicy", full: true },
  operationIdentity: { source: mint + "StreamMintOperationIdentity.sol", contract: "StreamMintOperationIdentity", methods: ["counterConsumption", "subjectKey"] },
  preparation: { source: mint + "StreamMintCounterPreparation.sol", contract: "StreamMintCounterPreparation", methods: ["resolveCounter"] },
};
const oracleSources = [
  mint + "StreamMintCounterReads.sol", mint + "StreamMintCounterPreparation.sol", mint + "StreamMintCounterPolicy.sol",
  mint + "StreamMintOperationIdentity.sol", mint + "StreamMintManagerAccounting.sol", mint + "StreamMintManager.sol",
  mint + "StreamMintManagerViews.sol", mint + "StreamMintManagerFallback.sol",
  interfaces + "IStreamMintCounterReads.sol", interfaces + "IStreamMintCounterPolicy.sol",
  interfaces + "IStreamMintManager.sol", interfaces + "IStreamMintLedger.sol",
];

export function mintCounterReadsFixture(inputBytes, outputBytes) {
  if (sha(inputBytes) !== INPUT_SHA || sha(outputBytes) !== OUTPUT_SHA) throw Error("Expected exact frozen CounterReads ABI65 capture");
  const input = JSON.parse(inputBytes), output = JSON.parse(outputBytes);
  if (input.language !== "Solidity" || Object.keys(input.sources ?? {}).length !== 2309
    || output.errors?.some(row => row.severity === "error")) throw Error("Expected clean 2309-source capture");
  const sourceHashes = {}, sourceTexts = {}, abis = {};
  function visit(path) {
    if (Object.hasOwn(sourceHashes, path)) return;
    const literal = input.sources[path]?.content;
    if (typeof literal !== "string") throw Error(`Missing literal source ${path}`);
    sourceHashes[path] = sha(literal);
    for (const match of literal.matchAll(/import\s+(?:[\s\S]*?\s+from\s+)?["']([^"']+)["']\s*;/g)) {
      visit(match[1].startsWith(".") ? posix.normalize(posix.join(posix.dirname(path), match[1])) : match[1]);
    }
  }
  for (const [key, selected] of Object.entries(selections)) {
    visit(selected.source);
    const full = output.contracts?.[selected.source]?.[selected.contract]?.abi;
    if (!Array.isArray(full)) throw Error(`Missing compiled ABI ${key}`);
    const abi = selected.full ? full : full.filter(row => row.type === "function" && selected.methods.includes(row.name));
    if (!selected.full && selected.methods.some(name => abi.filter(row => row.name === name).length !== 1)) throw Error(`Incomplete or overloaded ABI ${key}`);
    abis[key] = abi;
  }
  for (const path of oracleSources) { visit(path); sourceTexts[path] = input.sources[path].content; }
  return {
    schemaVersion: 1, capture: "parallel-feature-batch65-20260920", compilerVersion: "0.8.19", sourceCommit: SOURCE_COMMIT,
    sourceCount: 2309, inputSha256: INPUT_SHA, outputSha256: OUTPUT_SHA,
    sourceBinding: "All 2309 literal input sources independently verified byte-for-byte against this Git commit. Selected production closure hashes and original counter, scope and proof recipes follow.",
    qualification: "Frozen source and ABI evidence only; accounting views do not establish mint authorization. Client tests do not establish native current-stack, actual Safe, gas, genesis or release acceptance.",
    sourceHashes: Object.fromEntries(Object.entries(sourceHashes).sort(([a], [b]) => a.localeCompare(b))),
    sourceTexts, selections, abis,
  };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [input, output, mode] = process.argv.slice(2);
  if (!input || !output || (mode !== undefined && mode !== "--check")) throw Error("Usage: generate-current-mint-counter-reads-fixture.mjs INPUT OUTPUT [--check]");
  const rendered = JSON.stringify(mintCounterReadsFixture(await readFile(input), await readFile(output)), null, 2) + "\n";
  const target = new URL("../test/fixtures/current-mint-counter-reads-abi.json", import.meta.url);
  if (mode === "--check") {
    if (await readFile(target, "utf8") !== rendered) throw Error("Stale current Mint CounterReads fixture");
  } else await writeFile(target, rendered, "utf8");
}
