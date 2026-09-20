// Project an authenticated retained compiler capture; never invoke a compiler.
import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { readFile, writeFile } from "node:fs/promises";
import { posix, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { id } from "ethers";
import { solidityImports } from "./generate-current-entropy-policy-succession-fixture.mjs";

const capture = {
  capture: "parallel-feature-batch106-20260920", compilerVersion: "0.8.19",
  sourceCommit: "836b9c64e1f0630d4e79e6cee831450059616fd7",
  sourceTree: "2fcb2562f0f58780fbd7d77918df0afd505b7dd7",
  sourceCount: 2830, literalBytes: 33_562_139,
  inputSha256: "c0b3cfb4ced367158d114c521e6922bc4e0b1da8a8a2da46012d12f513e890c5",
  outputSha256: "e6c76a69a6419af87cff2e6a97f589057d9bfe5e08ae2db7e3fd1dcd97423d3a",
};
const nominalIdentifiers = {
  "collect(StreamArtistOnboardingTypes.SuiteConfiguration,StreamArtistRecoveredHydrationTypes.Request)": "35c07ee8",
  "collect(StreamArtistOnboardingTypes.SuiteConfiguration,StreamArtistRecoveredHydrationTypes.Request,StreamArtistOnboardingTypes.RoyaltyFreeze[])": "86909776",
  "inventory(StreamArtistRecoveredHydrationCommit.Prepared)": "69f71db4",
  "prepare(StreamArtistOnboardingTypes.SuiteConfiguration,StreamArtistRecoveredHydrationTypes.Request)": "72c84763",
  "prepare(StreamArtistOnboardingTypes.SuiteConfiguration,StreamArtistRecoveredHydrationTypes.Request,StreamArtistOnboardingTypes.RoyaltyFreeze[])": "4925300f",
  "requiredFeatures(StreamArtistRecoveredIdentityHydrationTypes.Bundle,StreamArtistRecoveredPayoutTypes.Bundle,uint256)": "0681a748",
};
const sha = value => createHash("sha256").update(value).digest("hex");
const compare = (a, b) => a < b ? -1 : a > b ? 1 : 0;
const names = {
  registry: "StreamArtistOnboardingRegistry", coordinator: "StreamArtistOnboardingCoordinator",
  reads: "StreamArtistOnboardingReads", archive: "StreamArtistArchiveV2", owner: "StreamArtistOwner",
  binding: "StreamArtistBindingLifecycle", collaborator: "StreamArtistCollaboratorLifecycle",
  identity: "StreamArtistIdentityAuthority", acceptance: "StreamArtistAcceptanceLifecycle",
  attribution: "StreamArtistAttributionLifecycle", payout: "StreamArtistPayoutLifecycle",
  consent: "StreamArtistConsentFinalityLifecycle", checkpoint: "IStreamArtistAuthorityCheckpoint",
  recovered: "IStreamArtistRecoveredHydration", recoveredCoordinator: "IStreamArtistRecoveredHydrationCoordinator",
  recoveredOwner: "IStreamArtistRecoveredHydrationOwner", chronology: "IStreamArtistRecoveredNativeChronology",
  hydrationOwner: "IStreamArtistAuthorityHydrationOwner", hydrationCoordinator: "IStreamArtistAuthorityHydrationCoordinator",
  history: "IStreamArtistHistory", nativeReceipts: "IStreamArtistNativeReceipts", reconstruction: "IStreamArtistReconstruction",
  suite: "IStreamArtistSuiteReads", ingress: "IStreamArtistIngressBinding", timing: "IStreamArtistRecoveredTimingInventory",
  timingWorker: "StreamArtistRecoveredTimingInventory",
  prepared: "StreamArtistRecoveredHydrationPrepared", admission: "StreamArtistRecoveredHydrationAdmission",
  source: "StreamArtistRecoveredHydrationSource", provenance: "StreamArtistRecoveredHydrationProvenance",
  guards: "StreamArtistRecoveredHydrationGuards", codec: "StreamArtistRecoveredHydrationCodec",
  payload: "StreamArtistRecoveredHydrationOwnerPayload", commit: "StreamArtistRecoveredHydrationCommit",
  evidence: "StreamArtistRecoveredHydrationEvidence", external: "StreamArtistRecoveredExternalGuards",
  publications: "StreamArtistRecoveredPayloadHydration", witnesses: "StreamArtistRecoveredRecordWitnesses",
  core: "IStreamCorePointers", coreHost: "StreamCore", governanceFacts: "IStreamGovernanceActionFacts",
  finalityRecovery: "IStreamArtworkFinalityRecovery", finalityBinding: "IStreamFinalityRecoveryGovernanceBinding",
  entropyUnavailability: "IStreamEntropyArtistUnavailability", entropyFreshRecovery: "IStreamEntropyFreshRecovery",
  personhood: "IStreamArtistPersonhoodEvidence",
  recoveredConsents: "IStreamArtistRecoveredConsentHydration",
  recoveredConsentsCoordinator: "IStreamArtistRecoveredConsentHydrationCoordinator",
  contentHydration: "StreamArtistRecoveredContentConsentHydration",
  contentReads: "StreamArtistRecoveredContentConsentReads",
  contentValidation: "StreamArtistRecoveredContentConsentValidation",
  contentFacts: "StreamArtistRecoveredContentConsentFacts",
  contentFactRows: "StreamArtistRecoveredContentConsentFactRows",
  contentRecords: "IStreamArtistContentRecordsOwner",
  consentOwner: "IStreamArtistConsentOwner",
  delegatedConsentOwner: "IStreamArtistDelegatedConsentOwner",
  delegatedPolicySale: "IStreamArtistDelegatedPolicySaleConsentOwner",
  saleConsentOwner: "IStreamArtistSaleConsentOwner",
};
const documents = [
  "docs/adr/0047-complete-artist-authority-hydration.md",
  "docs/guides/artist-recovered-authority-hydration.md",
  "docs/architecture/artist-operation60-authority-hydration.json",
  "artifacts/art35-recovered-attestations.md",
  "artifacts/art36-recovered-content-consents.md",
  "artifacts/art36-content-capacity.md",
];

function bindGitLiterals(input, sourceCommit) {
  const entries = Object.entries(input.sources).sort(([a], [b]) => compare(a, b));
  if (entries.some(([path, source]) => /[\r\n]/.test(path) || typeof source.content !== "string")) throw Error("Invalid compiler source literal");
  const bytes = execFileSync("git", ["cat-file", "--batch"], {
    input: entries.map(([path]) => `${sourceCommit}:${path}\n`).join(""), maxBuffer: 128 * 1024 * 1024,
  });
  let cursor = 0, literalBytes = 0;
  for (const [path, source] of entries) {
    const end = bytes.indexOf(10, cursor);
    if (end < cursor) throw Error(`Missing Git object header ${path}`);
    const match = /^[0-9a-f]+ blob ([0-9]+)$/.exec(bytes.subarray(cursor, end).toString("ascii"));
    if (!match) throw Error(`Missing frozen Git source ${path}`);
    const size = Number(match[1]), actual = Buffer.from(source.content, "utf8");
    cursor = end + 1;
    if (!Number.isSafeInteger(size) || size !== actual.length || !bytes.subarray(cursor, cursor + size).equals(actual)
      || bytes[cursor + size] !== 10) throw Error(`Literal source differs from frozen Git ${path}`);
    literalBytes += size;
    cursor += size + 1;
  }
  if (cursor !== bytes.length) throw Error("Unexpected trailing Git object bytes");
  return literalBytes;
}

export function artistRecoveredConsentHydrationFixture(inputBytes, outputBytes) {
  if (sha(inputBytes) !== capture.inputSha256 || sha(outputBytes) !== capture.outputSha256) throw Error("Expected exact retained recovered-hydration capture");
  const input = JSON.parse(inputBytes), output = JSON.parse(outputBytes);
  if (input.language !== "Solidity" || Object.keys(input.sources ?? {}).length !== capture.sourceCount
    || output.errors?.some(error => error.severity === "error")) throw Error("Invalid retained compiler capture");
  const literalBytes = bindGitLiterals(input, capture.sourceCommit);
  if (literalBytes !== capture.literalBytes) throw Error("Compiler literal byte count differs");
  const sourceTree = execFileSync("git", ["rev-parse", `${capture.sourceCommit}^{tree}`], { encoding: "utf8" }).trim();
  if (sourceTree !== capture.sourceTree) throw Error("Frozen Git tree differs");
  const selections = {}, abis = {}, sourceHashes = {}, sourceTexts = {}, retainedDocuments = {};
  function visit(path) {
    if (Object.hasOwn(sourceHashes, path)) return;
    const text = input.sources[path]?.content;
    if (typeof text !== "string") throw Error(`Missing source ${path}`);
    sourceHashes[path] = sha(text);
    for (const imported of solidityImports(text)) visit(imported.startsWith(".") ? posix.normalize(posix.join(posix.dirname(path), imported)) : imported);
  }
  for (const [key, name] of Object.entries(names)) {
    const matches = Object.entries(output.contracts ?? {}).filter(([path, contracts]) => path.startsWith("smart-contracts/") && contracts[name]);
    if (matches.length !== 1) throw Error(`Expected unique compiled contract ${name}`);
    const [path, contracts] = matches[0];
    if (!Array.isArray(contracts[name].abi)) throw Error(`Missing complete ABI ${name}`);
    selections[key] = { source: path, contract: name, full: true };
    abis[key] = contracts[name].abi;
    visit(path);
  }
  const prepared = selections.prepared;
  const actualIdentifiers = output.contracts[prepared.source][prepared.contract].evm?.methodIdentifiers;
  if (JSON.stringify(actualIdentifiers) !== JSON.stringify(nominalIdentifiers)) throw Error("Original library method identifiers differ");
  for (const [signature, selector] of Object.entries(nominalIdentifiers)) {
    if (id(signature).slice(2, 10) !== selector) throw Error(`Nominal selector differs ${signature}`);
  }
  // Public library value ABIs also retain some nominal enum labels. Preserve the
  // original ABI and witness their encoding width against ordinary contract ABIs.
  const nominalEnums = new Map(), enumWitnesses = new Map();
  function enumFields(fields, witness, path = []) {
    for (let i = 0; i < fields.length; i++) {
      const field = fields[i], parameterPath = [...path, i];
      if (field.internalType?.startsWith("enum ")) {
        if (field.type === "uint8") {
          if (!enumWitnesses.has(field.internalType)) enumWitnesses.set(field.internalType, { ...witness, parameterPath });
        } else {
          if (field.internalType !== `enum ${field.type}`) throw Error("Unexpected nominal enum shape");
          nominalEnums.set(field.internalType, field.type);
        }
      }
      if (field.components) enumFields(field.components, witness, [...parameterPath, "components"]);
    }
  }
  for (const [segment, rows] of Object.entries(abis)) for (const row of rows) {
    if (row.type !== "function") continue;
    for (const direction of ["inputs", "outputs"]) enumFields(row[direction] ?? [], { segment, function: row.name, direction });
  }
  const libraryValueTypeEvidence = Object.fromEntries([...nominalEnums].sort(([a], [b]) => compare(a, b)).map(([type, nominalType]) => {
    if (!enumWitnesses.has(type)) throw Error(`No ordinary ABI encoding witness for ${type}`);
    return [type, { nominalType, abiType: "uint8", witness: enumWitnesses.get(type) }];
  }));
  const retained = Object.keys(input.sources).filter(path => path.startsWith("smart-contracts/")
    && /StreamArtistRecovered|StreamArtistOwnerCommit|StreamArtistHydrationSourceGuards|StreamArtistHistoryProof|StreamArtistPayloadSync|StreamArtistPayloadStore/.test(path));
  for (const path of [...new Set([...Object.values(selections).map(value => value.source), ...retained])].sort(compare)) {
    visit(path); sourceTexts[path] = input.sources[path].content;
  }
  for (const path of documents) {
    const bytes = execFileSync("git", ["show", `${capture.sourceCommit}:${path}`], { maxBuffer: 2 ** 20 });
    retainedDocuments[path] = { sha256: sha(bytes), byteLength: bytes.length, text: bytes.toString("utf8") };
  }
  return {
    schemaVersion: 1, profile: "artist-recovered-content-consent-hydration-v1", ...capture,
    sourceBinding: "Every literal compiler input byte is matched to its frozen Git blob by this generator.",
    qualification: "Source/ABI and bounded client evidence only; actual contract/Safe execution, whole graph, gas and release acceptance remain separate. ART36 content/freeze composition is source-qualified; later generation feature512/1023 and Prepared capacity extraction are excluded.",
    librarySelectorEvidence: {
      selection: prepared, outputSha256: capture.outputSha256, methodIdentifiers: nominalIdentifiers,
      qualification: "Original compiler evm.methodIdentifiers from the same authenticated ABI106 output. Public library selectors retain nominal struct names; ordinary tuple selectors do not identify these calls. No bytecode/runtime acceptance is inferred.",
    },
    libraryValueTypeEvidence,
    selections, abis, sourceHashes: Object.fromEntries(Object.entries(sourceHashes).sort(([a], [b]) => compare(a, b))),
    sourceTexts, documents: retainedDocuments,
  };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [input, output, mode] = process.argv.slice(2);
  if (!input || !output || mode !== undefined && mode !== "--check") throw Error("Usage: generate-current-artist-recovered-consent-hydration-fixture.mjs INPUT OUTPUT [--check]");
  const result = JSON.stringify(artistRecoveredConsentHydrationFixture(await readFile(input), await readFile(output)), null, 2) + "\n";
  const target = new URL("../test/fixtures/current-artist-recovered-consent-hydration-abi.json", import.meta.url);
  if (mode === "--check") {
    if (await readFile(target, "utf8") !== result) throw Error("Recovered-consent-hydration fixture differs");
  } else await writeFile(target, result, "utf8");
  console.log(`Recovered-consent-hydration fixture ${mode === "--check" ? "matches" : "written"}`);
}
