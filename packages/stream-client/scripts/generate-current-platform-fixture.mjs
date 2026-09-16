// Extract only the PLATFORM auction caller/read ABI from accepted compiler input/output.
import { createHash } from "node:crypto";
import { readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

const selections = [
  ["smart-contracts/interfaces/stream/auctions/IStreamPlatformNativeRightsAuction.sol", "IStreamPlatformNativeRightsAuction", ["platformRightsConfigurationHash", "platformRightsCreationDigest", "registerPlatformRightsAuction", "platformAuctionDeclaration"]],
  ["smart-contracts/interfaces/stream/auctions/IStreamPlatformCustodyAuction.sol", "IStreamPlatformCustodyAuction", ["platformCustodyAcquisitionDigest", "registerPlatformCustodyAuction"]],
  ["smart-contracts/interfaces/stream/auctions/IStreamPlatformTokenCustodyAuction.sol", "IStreamPlatformTokenCustodyAuction", ["platformTokenCustodyDigest", "activatePlatformTokenCustody", "platformTokenCustodyActivation", "platformTokenCustodyConfigurationHash", "platformTokenCustodyNonceUsed", "bidPlatformTokenCustody", "bidSignedPlatformTokenCustody", "settlePlatformTokenCustody"]],
  ["smart-contracts/interfaces/stream/auctions/IStreamNativeCustodyAuction.sol", "IStreamNativeCustodyAuction", ["custodyOrigin"]],
  ["smart-contracts/interfaces/stream/revenue/IStreamRevenueResolver.sol", "IStreamRevenueResolver", ["resolvePrimaryAssignment"]],
  ["smart-contracts/interfaces/stream/artist/IStreamArtistPlatformWorks.sol", "IStreamArtistPlatformWorks", ["platformWorksDeclaration", "platformWorksContest", "platformWorksCorrection"]],
  ["smart-contracts/domains/auctions/StreamNativeEnglishAuction.sol", "StreamNativeEnglishAuction", ["auction", "auctionDeadlines", "revenueResolver", "artistRegistry"]],
];
const sha = value => createHash("sha256").update(value).digest("hex");

export function currentPlatformFixture(inputBytes, outputBytes, sourceCommit) {
  if (typeof sourceCommit !== "string" || !/^[0-9a-f]{8,40}$/.test(sourceCommit)) throw Error("Expected lowercase source commit");
  const input = JSON.parse(inputBytes), output = JSON.parse(outputBytes);
  if (input.language !== "Solidity" || output.errors?.some(item => item.severity === "error")) throw Error("Expected successful Solidity compiler input/output");
  const contracts = selections.map(([source, contract, methods]) => {
    const literal = input.sources?.[source]?.content, fullAbi = output.contracts?.[source]?.[contract]?.abi;
    if (typeof literal !== "string" || !Array.isArray(fullAbi)) throw Error(`Missing compiler target ${source}::${contract}`);
    const abi = fullAbi.filter(item => item.type === "function" && methods.includes(item.name));
    if (abi.length !== methods.length || methods.some(name => !abi.some(item => item.name === name))) throw Error(`Incomplete selected ABI for ${contract}`);
    return { source, contract, sourceSha256: sha(literal), methods, abi };
  });
  return { sourceCommit, compilerVersion: "0.8.19", scope: "Selected declaration-bound PLATFORM auction callers and reads; no runtime or signature acceptance", provenance: { compilerInputSha256: sha(inputBytes), compilerOutputSha256: sha(outputBytes) }, contracts };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [input, output, sourceCommit, mode] = process.argv.slice(2);
  if (!input || !output || !sourceCommit || (mode !== undefined && mode !== "--check")) throw Error("Usage: generate-current-platform-fixture.mjs INPUT OUTPUT SOURCE_COMMIT [--check]");
  const file = new URL("../test/fixtures/current-platform-abi.json", import.meta.url);
  const rendered = JSON.stringify(currentPlatformFixture(await readFile(input), await readFile(output), sourceCommit), null, 2) + "\n";
  if (mode === "--check") { if (await readFile(file, "utf8") !== rendered) throw Error("Stale current PLATFORM ABI fixture"); }
  else await writeFile(file, rendered, "utf8");
}
