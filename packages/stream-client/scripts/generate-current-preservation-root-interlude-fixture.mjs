// Exact source/tool and selected ordinary ABI witness. Never executes the tool,
// a compiler, an EVM, a signer or an RPC request.
import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { readFile, writeFile } from "node:fs/promises";
import { resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";
import { currentViewPreservationConsumersV1Fixture } from "./generate-current-view-preservation-consumers-v1-fixture.mjs";

const SOURCE = "61d0efc5c88db67126a1af2e3ccaa6d1ddecb41d";
const REPORT = "5537434a6b43233bcc2c6f577659c18a045db0144c8dbb2c8d74d9f3ef82f5df";
const TOOL = "0c9d4afe6a5a9df72a5b560bda3fe5684fe63c378e6b4746aa8afcb753cda178";
const MANIFEST = "51c4b4fd180da69b40b797666d0f99920798a9e554f410f737647bc026e26901";
const root = fileURLToPath(new URL("../../../", import.meta.url));
const sha = value => createHash("sha256").update(value).digest("hex");
const type = p => p.type.startsWith("tuple") ? `(${p.components.map(type).join(",")})${p.type.slice(5)}` : p.type;
const targetContracts = {
  core: "StreamCore", registry: "StreamArtistOnboardingRegistry",
  coordinator: "StreamArtistOnboardingCoordinator", metadata: "StreamCollectionMetadataV1",
  router: "StreamMetadataRouter", artistSafe: "OfficialSafe",
  "identityOwner=owners[2]": "StreamArtistIdentityAuthority",
  "consentOwner=owners[6]": "StreamArtistConsentFinalityLifecycle",
  "output=graph.children[2]": "StreamPreservationPolicyOutputManifestV2",
  "snapshot=graph.children[3]": "StreamScopedPreservationPolicySnapshotPublicationV2",
};

function gitBlobs(paths) {
  const out = execFileSync("git", ["cat-file", "--batch"], {
    cwd: root, input: paths.map(path => `${SOURCE}:${path}\n`).join(""), maxBuffer: 32 * 1024 * 1024,
  });
  let at = 0; const result = {};
  for (const path of paths) {
    const end = out.indexOf(10, at), header = out.subarray(at, end).toString("ascii").split(" "), size = Number(header[2]);
    if (end < at || header[1] !== "blob" || !Number.isSafeInteger(size) || size < 0) throw Error(`Missing source ${path}`);
    result[path] = out.subarray(end + 1, end + 1 + size); at = end + size + 2;
  }
  if (at !== out.length) throw Error("Unconsumed source bytes");
  return result;
}

export async function currentPreservationRootInterludeFixture(directory, inputBytes, outputBytes, bridgeBytes) {
  const dir = resolve(directory), manifestBytes = await readFile(resolve(dir, "manifest.json"));
  if (sha(manifestBytes) !== MANIFEST) throw Error("Expected exact clarified interlude manifest");
  const manifest = JSON.parse(manifestBytes), files = {};
  for (const f of manifest.files) {
    const path = resolve(dir, f.path);
    if (!path.startsWith(dir + sep)) throw Error("Manifest path escape");
    const bytes = await readFile(path);
    if (bytes.length !== f.bytes || sha(bytes) !== f.sha256) throw Error(`Changed interlude file ${f.path}`);
    files[f.path] = bytes;
  }
  if (sha(files["source-plan.json"]) !== REPORT || sha(files["interlude.py"]) !== TOOL) throw Error("Changed original tool/report");
  const report = JSON.parse(files["source-plan.json"]);
  if (report.sourceCommit !== SOURCE || report.sourcePins.length !== 41 || report.abi.length !== 35) throw Error("Wrong original source report");
  // Reuse the established byte-exact ABI157 input/output/Git bridge verifier.
  // This does not regenerate or modify its existing fixture.
  const compiler = currentViewPreservationConsumersV1Fixture(inputBytes, outputBytes, bridgeBytes);
  const input = JSON.parse(inputBytes), output = JSON.parse(outputBytes);
  const methods = report.abi.map(entry => {
    const name = targetContracts[entry.target];
    if (!name) throw Error(`Unknown source target ${entry.target}`);
    const matches = Object.entries(output.contracts).filter(([, contracts]) => Object.hasOwn(contracts, name));
    if (matches.length !== 1) throw Error(`Expected one concrete ${name}`);
    const [source, contracts] = matches[0], contract = contracts[name];
    const abis = contract.abi.filter(a => a.type === "function" && `${a.name}(${a.inputs.map(type).join(",")})` === entry.signature);
    if (abis.length !== 1 || `(${abis[0].outputs.map(type).join(",")})` !== entry.returns
      || `0x${contract.evm.methodIdentifiers[entry.signature]}` !== entry.selector) throw Error(`Compiler ABI differs ${entry.signature}`);
    return { ...entry, contract: name, source, abi: abis[0], compilerSourceSha256: sha(input.sources[source].content) };
  });
  const pinned = [...report.sourcePins, ...manifest.supplementalSourcePins];
  const paths = [...new Set([...pinned.map(p => p.path), ...methods.map(m => m.source)])].sort();
  const blobs = gitBlobs(paths), sources = {};
  for (const path of paths) {
    const bytes = blobs[path], expected = pinned.filter(p => p.path === path);
    for (const pin of expected) if (bytes.length !== pin.bytes || sha(bytes) !== pin.sha256) throw Error(`Source report/Git differs ${path}`);
    for (const method of methods.filter(m => m.source === path)) {
      if (sha(bytes) !== method.compilerSourceSha256) throw Error(`Selected compiler source differs at caller commit ${path}`);
    }
    sources[path] = { bytes: bytes.length, sha256: sha(bytes), text: bytes.toString("utf8") };
  }
  return {
    schemaVersion: 1, profile: "current-preservation-root-interlude", sourceCommit: SOURCE,
    sourceTree: execFileSync("git", ["rev-parse", `${SOURCE}^{tree}`], { cwd: root, encoding: "utf8" }).trim(),
    sourceReport: { sha256: REPORT, bytes: files["source-plan.json"].length, text: files["source-plan.json"].toString("utf8") },
    tool: { sha256: TOOL, bytes: files["interlude.py"].length, text: files["interlude.py"].toString("utf8") },
    manifest: { sha256: MANIFEST, bytes: manifestBytes.length, text: manifestBytes.toString("utf8") },
    syntheticInputs: Object.fromEntries(["collection", "scoped"].flatMap(kind => ["admission", "request"].map(part => {
      const path = `example.synthetic.${kind}.${part}.json`, bytes = files[path];
      return [path, { bytes: bytes.length, sha256: sha(bytes), text: bytes.toString("utf8") }];
    }))),
    compiler: { sourceCommit: compiler.sourceCommit, sourceTree: compiler.sourceTree, inputSha256: compiler.inputSha256,
      outputSha256: compiler.outputSha256, bridgeSha256: compiler.committedSourceBridge.sha256, literalSources: compiler.sourceCount },
    methods, sources,
    qualification: "Selected ordinary ABI entries match exact ABI157 compiler output. Each selected declaration file is byte-identical at caller source61d0; all41 report and5 supplemental source pins match that Git commit. This is not a complete linked-runtime closure, deployment/state-import admission, proof that a supplied packet was produced by the original tool, or original protocol/native/Safe execution acceptance. Repaired source requires a reviewed rejoin; this fixture never relabels it.",
  };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [directory, input, output, bridge, mode] = process.argv.slice(2);
  if (!directory || !input || !output || !bridge || mode !== undefined && mode !== "--check") throw Error("Usage: generate-current-preservation-root-interlude-fixture.mjs TOOL_DIRECTORY ABI_INPUT ABI_OUTPUT ABI_BRIDGE [--check]");
  const fixture = await currentPreservationRootInterludeFixture(directory, await readFile(input), await readFile(output), await readFile(bridge));
  const rendered = JSON.stringify(fixture, null, 2) + "\n";
  const target = new URL("../test/fixtures/current-preservation-root-interlude-source.json", import.meta.url);
  if (mode === "--check") {
    if (await readFile(target, "utf8") !== rendered) throw Error("Stale root interlude witness");
    process.stdout.write("Root interlude witness matches\n");
  } else { await writeFile(target, rendered, "utf8"); process.stdout.write("Root interlude witness written\n"); }
}
