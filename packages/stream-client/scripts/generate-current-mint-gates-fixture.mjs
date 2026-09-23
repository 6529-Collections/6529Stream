// Extract mint-gate ABI from the exact reviewed bba738e9 compiler capture.
import { createHash } from "node:crypto";
import { readFile, writeFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { resolve } from "node:path";

const SOURCE_COMMIT = "bba738e9a9af3f12fdccd2e9cbc825aa555adb08";
const SOURCE_TREE = "236b9e7c52de9701177394f302925788a2bbb695";
const REVIEWED_INPUT_SHA256 = "b2e12eef016901d44188ced46c02fd5893a0554c65dc1cc061c6c9445b6d79ac";
const REVIEWED_OUTPUT_SHA256 = "736b7dd4955030afb89d3cc9feef1b8eddefc7fbe5d00f905b043b9b07782b59";
const sha = value => createHash("sha256").update(value).digest("hex");

const selections = [
  ["ticket", "smart-contracts/domains/mint/StreamMintTicketGate.sol", "StreamMintTicketGate",
    ["eip712Domain", "gateConfigHash", "ticketSigner", "ticketSignerKind", "validateMint", "validateMintBatch"]],
  ["delegate", "smart-contracts/domains/mint/StreamDelegateRegistryGate.sol", "StreamDelegateRegistryGate",
    ["collectionDelegationRights", "core", "delegateRegistry", "delegateRegistryCodeHash", "delegationUsecase", "gateConfigHash", "isDelegated", "validateMint"]],
  ["allowlist", "smart-contracts/domains/mint/StreamMintAllowlistGate.sol", "StreamMintAllowlistGate",
    ["capRoot", "counterId", "gateConfigHash", "previewAuthorizationId", "validateMint", "validateMintBatch"]],
];
const sourcePaths = [
  "smart-contracts/domains/mint/StreamMintTicketGate.sol",
  "smart-contracts/domains/mint/StreamMintTicketHash.sol",
  "smart-contracts/interfaces/stream/mint/StreamMintTicketTypes.sol",
  "smart-contracts/domains/mint/StreamDelegateRegistryGate.sol",
  "smart-contracts/domains/mint/StreamMintAllowlistGate.sol",
  "smart-contracts/domains/mint/StreamMintCounterPolicy.sol",
  "smart-contracts/interfaces/stream/mint/IStreamMintManager.sol",
];

export function currentMintGatesFixture(inputBytes, outputBytes) {
  const inputSha256 = sha(inputBytes), outputSha256 = sha(outputBytes);
  if (inputSha256 !== REVIEWED_INPUT_SHA256 || outputSha256 !== REVIEWED_OUTPUT_SHA256) {
    throw Error("Compiler capture differs from the reviewed canonical mint-gates ABI capture");
  }
  const input = JSON.parse(inputBytes), output = JSON.parse(outputBytes);
  if (input.language !== "Solidity" || Object.keys(input.sources ?? {}).length !== 130
    || output.errors?.some(item => item.severity === "error")) throw Error("Expected the clean 130-source Solidity standard JSON capture");
  const sources = {};
  for (const path of sourcePaths) {
    const source = input.sources?.[path]?.content;
    if (typeof source !== "string") throw Error(`Missing mint-gate source ${path}`);
    sources[path] = sha(source);
  }
  const abis = {};
  for (const [name, path, contract, methods] of selections) {
    const full = output.contracts?.[path]?.[contract]?.abi;
    if (!Array.isArray(full)) throw Error(`Missing compiler target ${path}::${contract}`);
    const selected = full.filter(item => item.type === "function" && methods.includes(item.name));
    if (selected.length !== methods.length || methods.some(method => !selected.some(item => item.name === method))) {
      throw Error(`Incomplete selected mint-gate ABI ${contract}`);
    }
    abis[name] = selected;
  }
  return { schemaVersion: 1, sourceCommit: SOURCE_COMMIT, sourceTree: SOURCE_TREE,
    qualification: "Exact compiler-selected mint-gate ABI and source provenance; no native-runtime, live eligibility, signature acceptance, send, deployment, audit or release claim.",
    compilerVersion: "0.8.19", sourceCount: 130, inputSha256, outputSha256, sources, abis };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [input, output, mode] = process.argv.slice(2);
  if (!input || !output || (mode !== undefined && mode !== "--check")) {
    throw Error("Usage: node scripts/generate-current-mint-gates-fixture.mjs INPUT OUTPUT [--check]");
  }
  const file = new URL("../test/fixtures/current-mint-gates-abi.json", import.meta.url);
  const rendered = JSON.stringify(currentMintGatesFixture(await readFile(input), await readFile(output)), null, 2) + "\n";
  if (mode === "--check") {
    if (await readFile(file, "utf8") !== rendered) throw Error("Stale current mint-gates ABI fixture");
  } else await writeFile(file, rendered, "utf8");
  console.log("Verified exact compiler-selected current mint-gates fixture; runtime acceptance remains separate.");
}
