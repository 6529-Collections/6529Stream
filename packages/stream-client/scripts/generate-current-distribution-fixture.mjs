// Extract the bounded operator-distribution caller ABI from an accepted compiler capture.
import { createHash } from "node:crypto";
import { readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

const selections = [
  ["smart-contracts/interfaces/stream/mint/IStreamOperatorDistribution.sol", "IStreamOperatorDistribution", ["programHash", "sliceHash", "sliceAuthorization", "distribute", "sliceUsed", "nftClaim", "claimNft", "claimNftFor"]],
  ["smart-contracts/domains/mint/StreamOperatorDistribution.sol", "StreamOperatorDistribution", ["core", "manager"]],
  ["smart-contracts/interfaces/stream/mint/IStreamMintManager.sol", "IStreamMintManager", ["phase", "phasePolicyHash", "phaseExecutor", "counterConfig"]],
  ["smart-contracts/domains/mint/StreamMintManager.sol", "StreamMintManager", ["core", "mintLedger"]],
  ["smart-contracts/interfaces/stream/mint/IStreamMintRoyaltyPolicy.sol", "IStreamMintRoyaltyPolicy", ["phaseRoyaltyPolicy", "phaseRoyaltyConfigHash"]],
  ["smart-contracts/interfaces/stream/core/IStreamCorePointers.sol", "IStreamCorePointers", ["getSatellitePointer"]],
  ["smart-contracts/interfaces/stream/entropy/IStreamRevealFeeEscrow.sol", "IStreamRevealFeeEscrow", ["core", "collectionRevealPolicy"]],
];
const sha = value => createHash("sha256").update(value).digest("hex");

export function currentDistributionFixture(inputBytes, outputBytes, bindingBytes, compilerCommit, compilerTree, targetCommit, targetTree) {
  for (const [name, value] of Object.entries({ compilerCommit, compilerTree, targetCommit, targetTree })) {
    if (!/^[0-9a-f]{40}$/.test(value)) throw new Error(`${name} must be a full lowercase git object ID`);
  }
  const input = JSON.parse(inputBytes), output = JSON.parse(outputBytes), binding = JSON.parse(bindingBytes);
  if (input.language !== "Solidity" || Object.keys(input.sources ?? {}).length !== 1014 || output.errors?.some(item => item.severity === "error")
    || binding.builderCommit !== compilerCommit || binding.sourceCount !== 1014 || binding.compilerErrorCount !== 0 || binding.mismatches?.length !== 0
    || binding.inputSha256 !== sha(inputBytes) || binding.outputSha256 !== sha(outputBytes)) {
    throw new Error("Expected the accepted successful 1014-source compiler capture and matching source binding");
  }
  const bindingSources = new Map(binding.sources.map(item => [item.path, item]));
  const contracts = selections.map(([source, contract, methods]) => {
    const literal = input.sources?.[source]?.content, full = output.contracts?.[source]?.[contract]?.abi, bound = bindingSources.get(source);
    if (typeof literal !== "string" || !Array.isArray(full) || !bound?.matchesCommit || bound.compilerSourceSha256 !== sha(literal)) throw new Error(`Missing or unbound ${source}::${contract}`);
    const abi = full.filter(item => item.type === "function" && methods.includes(item.name));
    if (abi.length !== methods.length || methods.some(name => !abi.some(item => item.name === name))) throw new Error(`Incomplete selected ABI ${contract}`);
    return { source, contract, gitBlob: bound.gitBlob, sourceSha256: sha(literal), methods, abi };
  });
  return { compilerCommit, compilerTree, targetCommit, targetTree, compilerVersion: "0.8.19", sourceCount: 1014,
    normalization: "Compiler capture strips a UTF-8 BOM and uses universal newlines; source-binding.json records comparison to compilerCommit.",
    scope: "Selected operator-distribution hashes, execution, current Manager/reveal reads and claims; encoding/read/simulation only",
    provenance: { compilerInputSha256: sha(inputBytes), compilerOutputSha256: sha(outputBytes), sourceBindingSha256: sha(bindingBytes) }, contracts };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [input, output, binding, compilerCommit, compilerTree, targetCommit, targetTree, mode] = process.argv.slice(2);
  if (!input || !output || !binding || !compilerCommit || !compilerTree || !targetCommit || !targetTree || (mode !== undefined && mode !== "--check")) {
    throw new Error("Usage: generate-current-distribution-fixture.mjs INPUT OUTPUT SOURCE_BINDING COMPILER_COMMIT COMPILER_TREE TARGET_COMMIT TARGET_TREE [--check]");
  }
  const file = new URL("../test/fixtures/current-distribution-abi.json", import.meta.url);
  const rendered = JSON.stringify(currentDistributionFixture(await readFile(input), await readFile(output), await readFile(binding), compilerCommit, compilerTree, targetCommit, targetTree), null, 2) + "\n";
  if (mode === "--check") {
    if (await readFile(file, "utf8") !== rendered) throw new Error("Stale current distribution ABI fixture");
  } else await writeFile(file, rendered, "utf8");
}
