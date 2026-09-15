// Explicit compiler-selected current revenue interfaces; retained catalogs are untouched.
import { readFile, writeFile } from "node:fs/promises";
import { createHash } from "node:crypto";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";
const sha = value => createHash("sha256").update(value).digest("hex");
export function revenueFixture(inputBytes, outputBytes) {
  const input = JSON.parse(inputBytes), output = JSON.parse(outputBytes);
  if (input.language !== "Solidity" || output.errors?.some(x => x.severity === "error")) throw Error("Expected successful Solidity compiler input/output");
  const targets = {
    primary: ["smart-contracts/domains/revenue/StreamRevenueResolver.sol", "StreamRevenueResolver"],
    royalty: ["smart-contracts/domains/revenue/StreamRoyaltyResolver.sol", "StreamRoyaltyResolver"],
    artist: ["smart-contracts/domains/artist/StreamArtistOnboardingRegistry.sol", "StreamArtistOnboardingRegistry"],
    manager: ["smart-contracts/domains/mint/StreamMintManager.sol", "StreamMintManager"],
    core: ["smart-contracts/interfaces/stream/core/IStreamCorePointers.sol", "IStreamCorePointers"],
  };
  const abis = {}, sources = {};
  for (const [key, [path, contract]] of Object.entries(targets)) {
    const literal = input.sources?.[path]?.content, abi = output.contracts?.[path]?.[contract]?.abi;
    if (typeof literal !== "string" || !Array.isArray(abi) || !abi.length) throw Error(`Missing compiler target ${key}`);
    const selected = key === "artist" ? ["core", "acceptedArtist", "economicsConsentDigest", "recordEconomicsConsent", "recordProspectiveEconomicsConsent", "recordProspectiveTemplateEconomicsConsent", "requireEconomicsConsent"]
      : key === "manager" ? ["core", "owner", "phaseRoyaltyConfigHash", "registerPhaseRoyaltyPolicy", "phaseRoyaltyPolicy"] : null;
    abis[key] = selected ? abi.filter(x => x.type === "function" && selected.includes(x.name)) : abi;
    if (selected && abis[key].length !== selected.length) throw Error(`Missing exact selected ${key} functions`);
    sources[path] = sha(literal);
  }
  const preimages = {};
  for (const [key, path, pattern] of [
    ["collaboratorSource", "smart-contracts/domains/revenue/StreamDynamicPrimaryTemplateRules.sol", /keccak256\("(6529STREAM_PRIMARY_COLLABORATOR_SOURCE_V1)"\)/],
    ["snapshotMode", "smart-contracts/domains/revenue/StreamRoyaltySnapshot.sol", /keccak256\("(6529STREAM_SNAPSHOT_ROYALTY_ASSIGNMENT_V1)"\)/],
    ["economics", "smart-contracts/domains/artist/StreamArtistHashes.sol", /"(StreamArtistEconomicsConsent\([^"\n]+\))"/],
    ["primaryTemplate", "smart-contracts/domains/revenue/StreamPrimaryTemplateRuntime.sol", /keccak256\("(6529STREAM_PRIMARY_TEMPLATE_V1)"\)/],
  ]) {
    const literal = input.sources?.[path]?.content, value = literal?.match(pattern)?.[1];
    if (!value) throw Error(`Missing original ${key} preimage`); preimages[key] = value; sources[path] = sha(literal);
  }
  return { schemaVersion: 1, qualification: "Explicit current compiler ABI/source fixture; no deployment or onchain execution claim", inputSha256: sha(inputBytes), outputSha256: sha(outputBytes), sources, preimages, abis };
}
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [input, output, mode] = process.argv.slice(2);
  if (!input || !output || (mode !== undefined && mode !== "--check")) throw Error("Usage: node scripts/generate-current-revenue-fixture.mjs INPUT OUTPUT [--check]");
  const file = new URL("../test/fixtures/current-revenue-abi.json", import.meta.url);
  const text = JSON.stringify(revenueFixture(await readFile(input), await readFile(output)), null, 2) + "\n";
  if (mode === "--check") { if (await readFile(file, "utf8") !== text) throw Error("Stale revenue fixture"); }
  else await writeFile(file, text, "utf8");
  console.log("Verified caller-selected current revenue ABI fixture; retained catalogs untouched.");
}
