import { createHash } from "node:crypto";
import { readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

const INPUT_SHA = "fc38c3ca352512ac8e86c515c031e9c9e280cca2e941996fedfaf03d7024c822";
const OUTPUT_SHA = "de02dfa841cd9b7333159f810f1bddf26e0d60e5e4fa7d1b0661b2346bd76f2a";
const sha = bytes => createHash("sha256").update(bytes).digest("hex");
const sourcePaths = [
  "smart-contracts/domains/mint/StreamMintManager.sol",
  "smart-contracts/domains/mint/StreamMintLedger.sol",
  "smart-contracts/domains/mint/StreamMintRevocation.sol",
  "smart-contracts/domains/mint/StreamMintTicketHash.sol",
  "smart-contracts/domains/mint/StreamPrivateSaleHash.sol",
  "smart-contracts/domains/mint/StreamPreparedNativeContentPurchaseHash.sol",
  "smart-contracts/interfaces/stream/mint/IStreamMintSaleAuthorizationRevocation.sol",
  "smart-contracts/interfaces/stream/mint/IStreamMintAuthorizationRevocation.sol",
  "smart-contracts/interfaces/stream/mint/IStreamMintLedger.sol",
  "smart-contracts/interfaces/stream/mint/IStreamMintLedgerRevocation.sol",
  "smart-contracts/interfaces/stream/mint/StreamPrivateSaleTypes.sol",
];
const selections = {
  manager: { source: sourcePaths[0], contract: "StreamMintManager",
    methods: ["mintLedger", "mintSaleAuthorizationId", "voidMintSaleAuthorization", "isAuthorizationUsed"] },
  ledger: { source: sourcePaths[1], contract: "StreamMintLedger", methods: ["isManagerAuthorizationUsed"] },
};
export function curatedRevocationFixture(inputBytes, outputBytes) {
  if (sha(inputBytes) !== INPUT_SHA || sha(outputBytes) !== OUTPUT_SHA) throw Error("Expected exact committed shared-seam ABI capture");
  const input = JSON.parse(inputBytes), output = JSON.parse(outputBytes);
  if (input.language !== "Solidity" || Object.keys(input.sources ?? {}).length !== 1989
    || output.errors?.some(error => error.severity === "error")) throw Error("Expected clean 1989-source ABI/type/storage capture");
  const sources = Object.fromEntries(sourcePaths.map(path => {
    const content = input.sources?.[path]?.content;
    if (typeof content !== "string") throw Error(`Missing revocation source ${path}`);
    return [path, sha(content)];
  }));
  const abis = {};
  for (const [key, selection] of Object.entries(selections)) {
    const all = output.contracts?.[selection.source]?.[selection.contract]?.abi;
    if (!Array.isArray(all)) throw Error(`Missing ABI ${key}`);
    const selected = all.filter(item => item.type === "function" && selection.methods.includes(item.name));
    if (selected.length !== selection.methods.length || selection.methods.some(name => !selected.some(item => item.name === name))) throw Error(`Incomplete ABI ${key}`);
    abis[key] = selected;
  }
  return { schemaVersion: 1, sourceCommit: "33ddd13251716f5409d66c1bd22544ed1cb9cb3a",
    sourceTree: "b0c723f77f949ea923ad9edcf2971139e2281ff9", sourceCount: 1989, compilerVersion: "0.8.19",
    sourceNormalization: "UTF-8 CRLF to LF", inputSha256: INPUT_SHA, outputSha256: OUTPUT_SHA,
    qualification: "Original Manager/Ledger historical authorization ABI and selected source evidence; separate from carrier capture and from runtime/Safe acceptance.",
    sources, selections, abis };
}
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [input, output, mode] = process.argv.slice(2);
  if (!input || !output || (mode !== undefined && mode !== "--check")) throw Error("Usage: generate-current-curated-revocation-fixture.mjs INPUT OUTPUT [--check]");
  const rendered = JSON.stringify(curatedRevocationFixture(await readFile(input), await readFile(output)), null, 2) + "\n";
  const path = new URL("../test/fixtures/current-curated-revocation-abi.json", import.meta.url);
  if (mode === "--check") {
    if (await readFile(path, "utf8") !== rendered) throw Error("Stale curated revocation fixture");
  } else await writeFile(path, rendered, "utf8");
}
