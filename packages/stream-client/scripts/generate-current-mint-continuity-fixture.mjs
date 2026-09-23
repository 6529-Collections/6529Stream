// Extract the bounded mint counter/continuity caller ABI from accepted compiler artifacts.
import { createHash } from "node:crypto";
import { readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

const selections = [
  ["smart-contracts/interfaces/stream/mint/IStreamMintCounterPolicy.sol", "IStreamMintCounterPolicy", ["registerCounterDefinition", "counterDefinition", "counterDefinitionForManager", "managerDefinitionCount", "managerDefinitionAt"]],
  ["smart-contracts/interfaces/stream/mint/IStreamMintLedgerImport.sol", "IStreamMintLedgerImport", ["ledgerWriterRetiredAt", "commitCounterImportRoot", "importCounterDefinitions", "mintImportDefinitionProgress", "completeCounterImport", "mintImportCommitment", "isMintSuccessorReady"]],
  ["smart-contracts/interfaces/stream/mint/IStreamMintManagerImport.sol", "IStreamMintManagerImport", ["importMintState"]],
  ["smart-contracts/interfaces/stream/mint/IStreamMintLedger.sol", "IStreamMintLedger", ["deriveCounterValueKey", "counterValue", "isManagerNullifierUsed"]],
  ["smart-contracts/interfaces/stream/mint/IStreamMintLedgerContinuity.sol", "IStreamMintLedgerContinuity", ["mintAncestorCount", "mintAncestorAt", "importMintAncestors", "mintImportAncestryProgress", "isCompletedMintDescendant"]],
  ["smart-contracts/domains/mint/StreamMintLedger.sol", "StreamMintLedger", ["owner", "ledgerWriter"]],
  ["smart-contracts/domains/mint/StreamMintManager.sol", "StreamMintManager", ["owner", "governanceAuthority", "mintLedger", "core"]],
];
const sha = value => createHash("sha256").update(value).digest("hex");
export function currentMintContinuityFixture(inputBytes, outputBytes, sourceCommit, sourceTree) {
  if (!/^[0-9a-f]{40}$/.test(sourceCommit) || !/^[0-9a-f]{40}$/.test(sourceTree)) throw Error("Expected full lowercase source commit and tree");
  const input = JSON.parse(inputBytes), output = JSON.parse(outputBytes); if (input.language !== "Solidity" || Object.keys(input.sources ?? {}).length !== 130 || output.errors?.some(x => x.severity === "error")) throw Error("Expected successful 130-source Solidity compiler artifacts");
  const contracts = selections.map(([source, contract, methods]) => { const literal = input.sources?.[source]?.content, full = output.contracts?.[source]?.[contract]?.abi; if (typeof literal !== "string" || !Array.isArray(full)) throw Error(`Missing ${source}::${contract}`); const abi = full.filter(x => x.type === "function" && methods.includes(x.name)); if (abi.length !== methods.length || methods.some(n => !abi.some(x => x.name === n))) throw Error(`Incomplete selected ABI ${contract}`); return { source, contract, sourceSha256: sha(literal), methods, abi }; });
  return { sourceCommit, sourceTree, compilerVersion: "0.8.19", sourceCount: 130, scope: "Selected mint counter-profile and Manager/Ledger continuity/ancestry callers and reads; no retirement, Core activation or runtime acceptance", provenance: { compilerInputSha256: sha(inputBytes), compilerOutputSha256: sha(outputBytes) }, contracts };
}
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [input, output, commit, tree, mode] = process.argv.slice(2); if (!input || !output || !commit || !tree || (mode !== undefined && mode !== "--check")) throw Error("Usage: generate-current-mint-continuity-fixture.mjs INPUT OUTPUT COMMIT TREE [--check]");
  const file = new URL("../test/fixtures/current-mint-continuity-abi.json", import.meta.url), rendered = JSON.stringify(currentMintContinuityFixture(await readFile(input), await readFile(output), commit, tree), null, 2) + "\n";
  if (mode === "--check") { if (await readFile(file, "utf8") !== rendered) throw Error("Stale current mint continuity ABI fixture"); } else await writeFile(file, rendered, "utf8");
}
