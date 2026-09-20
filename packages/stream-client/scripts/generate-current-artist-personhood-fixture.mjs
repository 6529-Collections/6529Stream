// Project the retained ABI102 capture. This script never invokes a compiler.
import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { readFile, writeFile } from "node:fs/promises";
import { posix, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { solidityImports } from "./generate-current-entropy-policy-succession-fixture.mjs";
const sourceCommit = "70c0d9c37f6435c480b87083af8d1cbd4fa7098d";
const inputSha256 = "cceb85599b712a445de6ecc8235bd7c7673b287926265982cd0bfe5321577dbe";
const outputSha256 = "101c9b9c30be178034d15548f34aaf2eb87f61f1da8756d3617b8113b4121054";
const sha = b => createHash("sha256").update(b).digest("hex");
const names = {
  personhood: "IStreamArtistPersonhoodEvidence", summary: "StreamArtistPersonhoodSummary", json: "StreamArtistPersonhoodJSON",
  registry: "StreamArtistOnboardingRegistry", coordinator: "StreamArtistOnboardingCoordinator", reads: "StreamArtistOnboardingReads", owner: "StreamArtistOwner",
  binding: "StreamArtistBindingLifecycle", identity: "StreamArtistIdentityAuthority", attribution: "StreamArtistAttributionLifecycle",
  archive: "StreamArtistArchiveV2", suite: "IStreamArtistSuiteReads", nativeReceipts: "IStreamArtistNativeReceipts", dormancy: "IStreamArtistDormancy", dormancyEvents: "IStreamArtistDormancyReconstructionEvents",
  general: "IStreamGeneralAttestations", generalHost: "StreamGeneralAttestations", moduleRegistry: "IStreamModuleRegistry",
  schemaRegistry: "IStreamSchemaRegistry", schemaFacts: "IStreamSchemaDocumentFacts", store: "StreamSchemaDocumentStore", core: "IStreamCorePointers", coreHost: "StreamCore",
  erc1271: "IERC1271",
};
const documents = ["docs/integrations/artist-personhood-reference.md", "docs/guides/artist-recovered-authority-hydration.md",
  "schemas/records/STREAM_ARTIST_PERSONHOOD_REFERENCE_JSON_PROFILE_V1.json", "schemas/records/STREAM_IDENTITY_NOTARIZATION_V1.json",
  "schemas/records/STREAM_IDENTITY_NOTARIZATION_JSON_PROFILE_V1.json", "schemas/museum/account-profile/RFC8785_JCS.json"];
export function artistPersonhoodFixture(inputBytes, outputBytes) {
  if (sha(inputBytes) !== inputSha256 || sha(outputBytes) !== outputSha256) throw Error("Expected exact retained ABI102 input/output");
  const input = JSON.parse(inputBytes), output = JSON.parse(outputBytes);
  if (input.language !== "Solidity" || Object.keys(input.sources ?? {}).length !== 2710 || output.errors?.some(e => e.severity === "error")) throw Error("Invalid ABI102 capture");
  const abis = {}, selections = {}, sourceHashes = {}, sourceTexts = {}, retainedDocuments = {};
  function visit(path) {
    if (sourceHashes[path]) return;
    const text = input.sources[path]?.content;
    if (typeof text !== "string") throw Error(`Missing source ${path}`);
    sourceHashes[path] = sha(text);
    for (const imported of solidityImports(text)) visit(imported.startsWith(".") ? posix.normalize(posix.join(posix.dirname(path), imported)) : imported);
  }
  for (const [key, name] of Object.entries(names)) {
    const matches = Object.entries(output.contracts).filter(([path, contracts]) => path.startsWith("smart-contracts/") && contracts[name]);
    if (matches.length !== 1) throw Error(`Expected unique ${name}`);
    const [path, contracts] = matches[0];
    selections[key] = { source: path, contract: name, full: true };
    abis[key] = contracts[name].abi;
    visit(path);
  }
  const retained = Object.keys(input.sources).filter(p => /Personhood|StreamArtistHashes\.sol$|StreamArtistAttestation|StreamArtistAttributionOperations|StreamArtistC2PACredentials|StreamGeneralAttestationHash|StreamIndependentReads|StreamGeneralAttestationDefinitions|StreamWorkRecordDefinitions|StreamArtistIdentityOperations\.sol$|StreamArtistIdentityState\.sol$|StreamArtistCurrentAuthorityFacts\.sol$|StreamArtistAuthorityPolicy\.sol$|StreamArtistDormancyState\.sol$|StreamArtistDormancyRecordEvents\.sol$/.test(p));
  for (const path of [...new Set([...Object.values(selections).map(v => v.source), ...retained])].sort()) { visit(path); sourceTexts[path] = input.sources[path].content; }
  for (const path of documents) {
    const bytes = execFileSync("git", ["show", `${sourceCommit}:${path}`], { maxBuffer: 2 ** 20 });
    retainedDocuments[path] = { sha256: sha(bytes), byteLength: bytes.length, text: bytes.toString("utf8") };
  }
  return { schemaVersion: 1, profile: "artist-personhood-reference-v1", capture: "parallel-feature-batch102-20260920", sourceCommit,
    sourceTree: "6f5e76e63d2ed31fa881aed6983e405b7aa07e89", sourceCount: 2710, inputSha256, outputSha256,
    sourceBinding: "All 2710 literal inputs independently byte-bound to frozen Git source; 31838018 literal bytes, no compiler errors.",
    qualification: "Source/ABI and client-only evidence. No native, actual Safe, whole graph, gas, deployment or release acceptance. Recovered op60 with personhood is excluded at this source.",
    selections, abis, sourceHashes: Object.fromEntries(Object.entries(sourceHashes).sort(([a], [b]) => a.localeCompare(b))), sourceTexts, documents: retainedDocuments };
}
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [input, output, mode] = process.argv.slice(2);
  if (!input || !output || mode !== undefined && mode !== "--check") throw Error("Usage: generate-current-artist-personhood-fixture.mjs INPUT OUTPUT [--check]");
  const result = JSON.stringify(artistPersonhoodFixture(await readFile(input), await readFile(output)), null, 2) + "\n";
  const target = new URL("../test/fixtures/current-artist-personhood-abi.json", import.meta.url);
  if (mode === "--check") { if (await readFile(target, "utf8") !== result) throw Error("Personhood fixture differs"); }
  else await writeFile(target, result, "utf8");
  console.log(`Personhood fixture ${mode === "--check" ? "matches" : "written"}`);
}
