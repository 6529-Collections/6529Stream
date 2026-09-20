// Project the immutable current-citation admission capture; this generator never compiles.
import { createHash } from "node:crypto";
import { readFile, writeFile } from "node:fs/promises";
import { posix, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { id, keccak256, toUtf8Bytes } from "ethers";

const INPUT_SHA = "f90c651734bfc3e320bc0f3cbb856a5d13a55d0ac9034534e48ef53b8b8a0626";
const OUTPUT_SHA = "549a36627ce9f8e35fbd0ac3851c9c8a5ccac1f3c38e2cf763c9c7d97cfdc174";
const SOURCE_COMMIT = "680d5aaa7384438a6e1264bc17eca5a604abcb0f";
const ENCODING_ARTIFACT_SHA = "25dbe8abd0de4abc4798305f128a202071e0a33a48151794a304f541be51ef9f";
const sha = bytes => createHash("sha256").update(bytes).digest("hex");
const metadata = "smart-contracts/domains/metadata/", interfaces = "smart-contracts/interfaces/stream/metadata/";
const governance = "smart-contracts/domains/governance/";
const full = (source, contract) => ({ source, contract, full: true });
const select = (source, contract, methods, events = []) => ({ source, contract, methods, events });
const selections = {
  registry: full(metadata + "StreamRendererRegistry.sol", "StreamRendererRegistry"),
  currentRegistry: full(interfaces + "IStreamCurrentCitationRegistry.sol", "IStreamCurrentCitationRegistry"),
  registryInterface: full(interfaces + "IStreamRendererRegistry.sol", "IStreamRendererRegistry"),
  currentRenderer: full(interfaces + "IStreamCurrentCitationRenderer.sol", "IStreamCurrentCitationRenderer"),
  rendererInterface: full(interfaces + "IStreamRenderer.sol", "IStreamRenderer"),
  renderer: select(metadata + "StreamRendererV1.sol", "StreamRendererV1", [
    "supportsInterface", "currentCitationProfile", "encodingBinding", "renderCurrent", "rendererVersion", "renderContextVersion",
    "rendererManifest", "tokenURI", "renderView", "sourceBindings", "governanceAuthority", "gasParameter", "gasParameterInfo",
  ]),
  encoding: full(metadata + "StreamStaticRenderEncoding.sol", "StreamStaticRenderEncoding"),
  admission: full(metadata + "StreamCurrentCitationAdmission.sol", "StreamCurrentCitationAdmission"),
  schemaRegistry: select(metadata + "StreamSchemaRegistry.sol", "StreamSchemaRegistry", [
    "supportsInterface", "governanceAuthority", "governanceAuthorityCodeHash", "chunkStore", "documentFacts", "document", "documentChunkHashAt", "documentBytes",
  ]),
  documentFacts: full(interfaces + "IStreamSchemaDocumentFacts.sol", "IStreamSchemaDocumentFacts"),
  schemaInterface: full(interfaces + "IStreamSchemaRegistry.sol", "IStreamSchemaRegistry"),
  store: select(metadata + "StreamSchemaDocumentStore.sol", "StreamSchemaDocumentStore", ["chunk", "readChunk"]),
  governanceIdentity: select(governance + "StreamGovernanceBootstrap.sol", "StreamGovernanceBootstrap", [
    "governanceActionId", "governanceCallsHash", "deriveBatchTransitionHashes", "minimumDelay", "validateActionWindow",
  ]),
  executor: select(governance + "StreamGovernanceExecutor.sol", "StreamGovernanceExecutor", [
    "owner", "currentAction", "minimumDelay", "isProposer", "governanceNonce", "governanceRootState", "roleRegistry",
    "scheduleGovernanceBatch", "executeGovernanceBatch", "governanceAction", "governanceActionFacts", "scheduledCallData",
    "scheduledCallDataPointer", "publishedCallData", "publishGovernanceCallData", "governanceActionPolicyState",
    "systemManifestBatchTailRule", "systemManifestBootstrapState", "supportsInterface", "freezeSelectorConfig", "isFreezeSelector",
  ], ["GovernanceActionScheduled", "GovernanceActionExecuted", "GovernanceCallDataPublished", "GovernanceActionPolicyValidated"]),
  roleRegistry: full("smart-contracts/interfaces/stream/governance/IStreamRoleRegistry.sol", "IStreamRoleRegistry"),
};
const oracleSources = [
  metadata + "StreamMetadataCitation.sol", metadata + "StreamCurrentCitationRouting.sol", metadata + "StreamMetadataRouterRendering.sol",
  metadata + "StreamMetadataStaticRouting.sol", metadata + "StreamMetadataTokenRenderer.sol", metadata + "StreamMetadataBundleRenderer.sol",
  metadata + "StreamMetadataRenderer.sol", metadata + "StreamRendererRegistryModule.sol", metadata + "StreamRendererCalls.sol",
  governance + "StreamGovernanceBootstrap.sol", governance + "StreamGovernanceScheduling.sol",
  governance + "StreamGovernanceActionPolicy.sol", governance + "StreamGovernancePolicy.sol",
];

export function metadataCitationFixture(inputBytes, outputBytes, encodingArtifactBytes) {
  if (sha(inputBytes) !== INPUT_SHA || sha(outputBytes) !== OUTPUT_SHA) throw Error("Expected exact frozen current-citation ABI7 capture");
  const input = JSON.parse(inputBytes), output = JSON.parse(outputBytes);
  if (input.language !== "Solidity" || Object.keys(input.sources ?? {}).length !== 1055
    || output.errors?.some(row => row.severity === "error")) throw Error("Expected clean 1055-source capture");
  if (sha(encodingArtifactBytes) !== ENCODING_ARTIFACT_SHA) throw Error("Expected exact retained native2 encoding artifact");
  const artifact = JSON.parse(encodingArtifactBytes), artifactSources = artifact.metadata?.sources;
  if (!artifactSources || Object.keys(artifactSources).length !== 15 || !artifact.metadata.compiler.version.startsWith("0.8.19+")) throw Error("Unexpected encoding artifact metadata");
  for (const [path, metadata] of Object.entries(artifactSources)) {
    if (typeof input.sources[path]?.content !== "string" || keccak256(toUtf8Bytes(input.sources[path].content)) !== metadata.keccak256) throw Error(`Encoding metadata source mismatch ${path}`);
  }
  const signatures = {
    "render(IStreamRenderer.RenderRequest,StreamStaticRenderEncoding.Prepared,string,address,uint8)": "c992b4e4",
    "renderCurrent(IStreamRenderer.RenderRequest,StreamStaticRenderEncoding.Prepared,string,address,uint8)": "55bbfc11",
  };
  for (const [signature, selector] of Object.entries(signatures)) {
    if (artifact.methodIdentifiers?.[signature] !== selector || id(signature).slice(2, 10) !== selector) throw Error("Unexpected compiler library method identifier");
  }
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
  for (const [key, selection] of Object.entries(selections)) {
    visit(selection.source);
    const all = output.contracts?.[selection.source]?.[selection.contract]?.abi;
    if (!Array.isArray(all)) throw Error(`Missing compiled ABI ${key}`);
    const abi = selection.full ? all : all.filter(row => row.type === "function" && selection.methods.includes(row.name)
      || row.type === "event" && selection.events.includes(row.name));
    if (!selection.full) for (const [type, names] of [["function", selection.methods], ["event", selection.events]]) {
      if (names.some(name => abi.filter(row => row.type === type && row.name === name).length !== 1)) throw Error(`Incomplete or overloaded ABI ${key}`);
    }
    abis[key] = abi;
  }
  for (const path of [...new Set([...Object.values(selections).map(row => row.source), ...oracleSources, ...Object.keys(artifactSources)])].sort()) {
    visit(path); sourceTexts[path] = input.sources[path].content;
  }
  return {
    schemaVersion: 1, capture: "default-citation-abi7", compilerVersion: "0.8.19", sourceCommit: SOURCE_COMMIT,
    sourceCount: 1055, inputSha256: INPUT_SHA, outputSha256: OUTPUT_SHA,
    librarySelectorEvidence: {
      capture: "default-citation-unit-native2", artifact: "StreamStaticRenderEncoding.sol/StreamStaticRenderEncoding.json",
      artifactSha256: ENCODING_ARTIFACT_SHA, compilerVersion: artifact.metadata.compiler.version,
      qualification: "Retained compiler methodIdentifiers for public library calls use nominal struct names. ABI7 has no methodIdentifiers. All 15 artifact metadata source hashes match this frozen ABI7 input; no new compilation was performed.",
      methodIdentifiers: signatures,
      sourceKeccak256: Object.fromEntries(Object.entries(artifactSources).map(([path, value]) => [path, value.keccak256])),
    },
    sourceBinding: "All 1055 literal compiler inputs independently verified byte-for-byte against this frozen Git commit. Selected production dependency hashes and current/historical rendering boundaries are retained.",
    qualification: "Frozen source and ABI evidence only. CurrentAnalysis and CurrentGoldenVector envelopes are source-derived internal schemas; their nested RenderRequest has a compiler ABI witness. Client tests do not establish complete STATIC analysis, native current-stack, actual Safe, operational gas or release acceptance.",
    sourceHashes: Object.fromEntries(Object.entries(sourceHashes).sort(([a], [b]) => a.localeCompare(b))),
    sourceTexts, selections, abis,
  };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [input, output, encodingArtifact, mode] = process.argv.slice(2);
  if (!input || !output || !encodingArtifact || (mode !== undefined && mode !== "--check")) throw Error("Usage: generate-current-metadata-citation-fixture.mjs INPUT OUTPUT ENCODING_ARTIFACT [--check]");
  const rendered = JSON.stringify(metadataCitationFixture(await readFile(input), await readFile(output), await readFile(encodingArtifact)), null, 2) + "\n";
  const target = new URL("../test/fixtures/current-metadata-citation-abi.json", import.meta.url);
  if (mode === "--check") {
    if (await readFile(target, "utf8") !== rendered) throw Error("Stale current metadata citation fixture");
  } else await writeFile(target, rendered, "utf8");
}
