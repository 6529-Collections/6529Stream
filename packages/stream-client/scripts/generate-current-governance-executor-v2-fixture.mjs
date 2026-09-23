// Exact ABI164 source/ABI witness for the original Executor and RoleRegistry.
// Never invokes Solidity, modifies captures, or refreshes historical fixtures.
import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { readFile, writeFile } from "node:fs/promises";
import { posix, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { solidityImports } from "./generate-current-entropy-policy-succession-fixture.mjs";

const SOURCE = "eda052c75dc9fd5c4e2e658bdf453ab01f5b7c0e";
const TREE = "1a71ae4ee9806c601237129d81e494058c547ee0";
const INPUT_SHA = "5fd1a5370ea1df068958317c48f67120e5cf9199ffe8e99ef5b99657b824374c";
const OUTPUT_SHA = "9ccdd82f1dee6b2d3a1b5ff3562417f64db27d72903b8fe2c8c06387b293ca90";
const BRIDGE_SHA = "d4ef14a96f8018de4ea99176e19c80009707439d5e9e7d8d72a163d342dee9af";
const repositoryRoot = fileURLToPath(new URL("../../../", import.meta.url));
const sha = value => createHash("sha256").update(value).digest("hex");
const order = (a, b) => a < b ? -1 : a > b ? 1 : 0;
const roots = ["StreamGovernanceExecutor", "StreamRoleRegistry"];

function bindAllGitLiterals(input, bridge) {
  const entries = Object.entries(input.sources).sort(([a], [b]) => order(a, b));
  if (entries.some(([path, source]) => /[\r\n]/.test(path) || typeof source.content !== "string")) {
    throw Error("Invalid compiler source literal");
  }
  const blobs = execFileSync("git", ["cat-file", "--batch"], {
    cwd: repositoryRoot,
    input: entries.map(([path]) => SOURCE + ":" + path + "\n").join(""),
    maxBuffer: 128 * 1024 * 1024,
  });
  let cursor = 0, literalBytes = 0;
  for (const [path, source] of entries) {
    const end = blobs.indexOf(10, cursor), header = blobs.subarray(cursor, end).toString("ascii");
    const size = Number(header.split(" ")[2]);
    if (end < cursor || !header.includes(" blob ") || !Number.isSafeInteger(size) || size < 0) {
      throw Error("Missing frozen source " + path);
    }
    const bytes = blobs.subarray(end + 1, end + 1 + size);
    if (bytes.toString("utf8").replace(/\r\n/g, "\n") !== source.content.replace(/\r\n/g, "\n")) throw Error("Compiler/Git content differs: " + path);
    if (bridge.committedBlobSHA256[path] !== sha(bytes)) throw Error("Bridge/Git hash differs: " + path);
    cursor = end + size + 2;
    literalBytes += size;
  }
  if (cursor !== blobs.length) throw Error("Frozen literal inventory differs");
  return literalBytes;
}

export function currentGovernanceExecutorV2Fixture(inputBytes, outputBytes, bridgeBytes) {
  if (sha(inputBytes) !== INPUT_SHA || sha(outputBytes) !== OUTPUT_SHA) throw Error("Expected exact ABI164 input/output");
  if (sha(bridgeBytes) !== BRIDGE_SHA) throw Error("Expected exact ABI164 committed source bridge");
  const input = JSON.parse(inputBytes), output = JSON.parse(outputBytes), bridge = JSON.parse(bridgeBytes);
  if (bridge.commit !== SOURCE || bridge.sources !== 4119
    || Object.keys(bridge.committedBlobSHA256 ?? {}).length !== 4119
    || !Array.isArray(bridge.mismatches) || bridge.mismatches.length !== 0) throw Error("Invalid committed source bridge");
  if (input.language !== "Solidity" || Object.keys(input.sources ?? {}).length !== 4119
    || output.errors?.some(error => error.severity === "error")) throw Error("Invalid governance ABI164 capture");
  if (execFileSync("git", ["rev-parse", SOURCE + "^{tree}"], { cwd: repositoryRoot, encoding: "utf8" }).trim() !== TREE) throw Error("Frozen tree differs");
  const literalBytes = bindAllGitLiterals(input, bridge);
  const abis = {}, selections = {}, methodIdentifiers = {}, sourceHashes = {}, sourceTexts = {};
  const libraryAbis = {}, librarySelections = {}, libraryMethodIdentifiers = {};
  const candidates = Object.entries(output.contracts).filter(([path]) => path.startsWith("smart-contracts/"));
  function visit(path) {
    if (Object.hasOwn(sourceHashes, path)) return;
    const source = input.sources[path]?.content;
    if (typeof source !== "string") throw Error("Missing source " + path);
    sourceHashes[path] = sha(source);
    sourceTexts[path] = source;
    for (const imported of solidityImports(source)) {
      visit(imported.startsWith(".") ? posix.normalize(posix.join(posix.dirname(path), imported)) : imported);
    }
  }
  function kind(path, name) {
    // Names come exclusively from the exact compiler result. Declarations are
    // lexically checked to keep nominal library selectors out of wallet ABIs.
    const text = input.sources[path].content.replace(/\/\*[\s\S]*?\*\//g, "").replace(/\/\/[^\r\n]*/g, "");
    const matches = [...text.matchAll(/\b(contract|interface|library)\s+([A-Za-z_][A-Za-z0-9_]*)\b/g)]
      .filter(match => match[2] === name);
    if (matches.length !== 1) throw Error("Ambiguous declaration kind: " + name);
    return matches[0][1];
  }
  function select(path, name, contract, nominal) {
    if (!Array.isArray(contract.abi)) throw Error("Missing full ABI " + name);
    if (Object.hasOwn(abis, name) || Object.hasOwn(libraryAbis, name)) return;
    const selected = { source: path, contract: name, full: true };
    if (nominal) {
      libraryAbis[name] = contract.abi;
      librarySelections[name] = { ...selected, nominal: true };
      libraryMethodIdentifiers[name] = contract.evm?.methodIdentifiers ?? {};
    } else {
      abis[name] = contract.abi;
      selections[name] = selected;
      methodIdentifiers[name] = contract.evm?.methodIdentifiers ?? {};
    }
    visit(path);
  }
  for (const name of roots) {
    const matches = candidates.filter(([, entries]) => Object.hasOwn(entries, name));
    if (matches.length !== 1) throw Error("Expected one compiled " + name);
    const [path, entries] = matches[0];
    select(path, name, entries[name], kind(path, name) === "library");
  }
  // Select every compiler declaration in the two original governance hosts' import closure.
  // Nominal library selectors remain separate from ordinary wallet ABIs.
  for (const [path, entries] of candidates) {
    if (!Object.hasOwn(sourceTexts, path)) continue;
    for (const [name, contract] of Object.entries(entries)) select(path, name, contract, kind(path, name) === "library");
  }
  const documents = [
    "docs/adr/0004-admin-governance.md",
    "docs/adr/0013-world-class-pass-round-4.md",
    "docs/adr/0017-raise-only-parameter-governance.md",
    "docs/adr/0024-append-only-governance-catalog.md",
    "docs/adr/0032-governance-foundation-before-product-activation.md",
  ];
  const retainedDocuments = {};
  for (const path of documents) {
    const bytes = execFileSync("git", ["show", SOURCE + ":" + path], { cwd: repositoryRoot, maxBuffer: 4 * 1024 * 1024 });
    const text = bytes.toString("utf8");
    if (!Buffer.from(text, "utf8").equals(bytes)) throw Error("Invalid UTF-8 document " + path);
    retainedDocuments[path] = { sha256: sha(bytes), byteLength: bytes.length, text };
  }
  const sorted = object => Object.fromEntries(Object.entries(object).sort(([a], [b]) => order(a, b)));
  return {
    schemaVersion: 1,
    profile: "current-governance-executor-v2",
    capture: "parallel-feature-batch164-20260921",
    compilerVersion: "0.8.19",
    sourceCommit: SOURCE,
    sourceTree: TREE,
    sourceCount: 4119,
    compilerReportedCommit: SOURCE,
    committedSourceBridge: { sha256: sha(bridgeBytes), ...bridge },
    literalBytes,
    inputSha256: INPUT_SHA,
    outputSha256: OUTPUT_SHA,
    sourceBinding: "Every compiler input literal matches its frozen Git blob after capture-declared CRLF-to-LF normalization. Raw Git hashes remain in committedSourceBridge, while sourceTexts/sourceHashes retain compiler literals. Full ordinary and nominal ABIs and the complete union of Executor/RoleRegistry imported source closures are retained separately. Interpretation documents come from the same source commit.",
    qualification: "Exact ABI164 source/ABI witness for the Executor and RoleRegistry at eda052c7. The client exposes only nine sealed-Executor lifecycle writes; retaining full host and imported ABIs does not add bootstrap, catalog, configuration or RoleRegistry writers. Nominal library selectors are not wallet call surfaces. Source imports do not attest deployed linked-runtime provenance, and delegatecall workers must not be called directly. This fixture does not establish actual native/Safe execution, target effects, rollback, gas/capacity, release or deployment acceptance.",
    sourceHashes: sorted(sourceHashes),
    sourceTexts: sorted(sourceTexts),
    documents: retainedDocuments,
    selections: sorted(selections),
    methodIdentifiers: sorted(methodIdentifiers),
    abis: sorted(abis),
    librarySelections: sorted(librarySelections),
    libraryMethodIdentifiers: sorted(libraryMethodIdentifiers),
    libraryAbis: sorted(libraryAbis),
  };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [input, output, bridge, mode] = process.argv.slice(2);
  if (!input || !output || !bridge || mode !== undefined && mode !== "--check") {
    throw Error("Usage: generate-current-governance-executor-v2-fixture.mjs INPUT OUTPUT COMMITTED_SOURCE_BRIDGE [--check]");
  }
  const rendered = JSON.stringify(currentGovernanceExecutorV2Fixture(await readFile(input), await readFile(output), await readFile(bridge)), null, 2) + "\n";
  const target = new URL("../test/fixtures/current-governance-executor-v2-abi.json", import.meta.url);
  if (mode === "--check") {
    if (await readFile(target, "utf8") !== rendered) throw Error("Stale current governance Executor V2 fixture");
    process.stdout.write("Current governance Executor V2 fixture matches\n");
  } else {
    await writeFile(target, rendered, "utf8");
    process.stdout.write("Current governance Executor V2 fixture written\n");
  }
}
