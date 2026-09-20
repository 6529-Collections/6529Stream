// Project the retained clone-factory compiler capture without compiling Solidity.
import { createHash } from "node:crypto";
import { readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

const INPUT_SHA = "80edca9e4bde72d2ea6aa5421ce28424997608b3459554db34f22786bd464c8b";
const OUTPUT_SHA = "3027012564f0782f8e9a0160d70ced192544a87ada9481b282acbd772245376a";
const SOURCE_COMMIT = "7382327933c90638e8552fc8dd0340e9de53c449";
const TEST_EXCEPTION = "test/unit/revenue/StreamSplitWalletClones.t.sol";
const sha = raw => createHash("sha256").update(raw).digest("hex");
const selections = {
  factory: { source: "smart-contracts/domains/revenue/StreamSplitFactory.sol", contract: "StreamSplitFactory" },
  wallet: { source: "smart-contracts/domains/revenue/StreamSplitWallet.sol", contract: "StreamSplitWallet" },
  factoryInterface: { source: "smart-contracts/interfaces/stream/revenue/IStreamSplitFactory.sol", contract: "IStreamSplitFactory" },
  implementationInterface: { source: "smart-contracts/interfaces/stream/revenue/IStreamSplitWalletImplementation.sol", contract: "IStreamSplitWalletImplementation" },
  deployment: { source: "smart-contracts/domains/revenue/StreamSplitWalletDeployment.sol", contract: "StreamSplitWalletDeployment" },
  assetPolicy: { source: "smart-contracts/interfaces/stream/revenue/IStreamAssetPolicyRegistry.sol", contract: "IStreamAssetPolicyRegistry",
    methods: ["isStreamAssetPolicyRegistry", "ASSET_STATUS_ACTIVE"] },
};

export function splitFactoryFixture(inputBytes, outputBytes) {
  if (sha(inputBytes) !== INPUT_SHA || sha(outputBytes) !== OUTPUT_SHA) throw Error("Expected exact frozen clone-factory compiler capture");
  const input = JSON.parse(inputBytes), output = JSON.parse(outputBytes);
  if (input.language !== "Solidity" || Object.keys(input.sources ?? {}).length !== 31
    || output.errors?.some(row => row.severity === "error")) throw Error("Expected clean 31-source capture");
  const sources = Object.fromEntries(Object.entries(input.sources).sort(([a], [b]) => a.localeCompare(b)).map(([path, source]) => {
    if (typeof source.content !== "string") throw Error(`Missing literal source ${path}`);
    return [path, sha(source.content)];
  }));
  if (!sources[TEST_EXCEPTION]) throw Error("Missing documented test source exception");
  const abis = {};
  for (const [key, selection] of Object.entries(selections)) {
    const full = output.contracts?.[selection.source]?.[selection.contract]?.abi;
    if (!Array.isArray(full)) throw Error(`Missing ABI ${key}`);
    const abi = selection.methods ? full.filter(row => row.type === "function" && selection.methods.includes(row.name)) : full;
    if (selection.methods && (abi.length !== selection.methods.length
      || selection.methods.some(name => abi.filter(row => row.name === name).length !== 1))) throw Error(`Incomplete ABI ${key}`);
    abis[key] = abi;
  }
  return { schemaVersion: 1, capture: "split-clones-abi2", compilerVersion: "0.8.19", sourceCommit: SOURCE_COMMIT,
    sourceCount: 31, inputSha256: INPUT_SHA, outputSha256: OUTPUT_SHA,
    sourceBinding: "30 of 31 literal sources, including every production source, are byte-identical to this Git commit. The single test-only exception is recorded below.",
    sourceExceptions: [{ path: TEST_EXCEPTION, capturedSha256: sources[TEST_EXCEPTION],
      reason: "Capture predates the final test-only fix caching the profile ID before vm.etch changes the implementation code. Production source is unchanged." }],
    qualification: "Frozen production-source and ABI evidence. This compiler capture is not the final native test input and does not establish current-stack, Safe, gas, genesis or release acceptance.",
    sources, selections, abis };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [input, output, mode] = process.argv.slice(2);
  if (!input || !output || (mode !== undefined && mode !== "--check")) throw Error("Usage: generate-current-split-factory-fixture.mjs INPUT OUTPUT [--check]");
  const canonical = JSON.stringify(splitFactoryFixture(await readFile(input), await readFile(output)), null, 2) + "\n";
  const target = new URL("../test/fixtures/current-split-factory-abi.json", import.meta.url);
  if (mode === "--check") {
    if (await readFile(target, "utf8") !== canonical) throw Error("Stale clone-factory ABI fixture");
  } else await writeFile(target, canonical, "utf8");
}
