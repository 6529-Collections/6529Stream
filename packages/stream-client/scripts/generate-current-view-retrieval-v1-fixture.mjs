// Focused exact ABI157 witness for attributed VIEW retrieval producer clients.
// Never invokes Solidity, modifies captures, or refreshes historical fixtures.
import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { readFile, writeFile } from "node:fs/promises";
import { posix, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { solidityImports } from "./generate-current-entropy-policy-succession-fixture.mjs";

const SOURCE = "a2973d360f6ab18881c04d58193f855704ec56d3";
const TREE = "f66d6a195a9e59b31cfe9ad8bd819e29054298bd";
const INPUT_SHA = "bdeb13c7467525241cfdc4fffe97e11aefbbd310972606eefe1ebebe47358234";
const OUTPUT_SHA = "b6b473ed08be283b2efba661132193670d8f2ff2d39e06cd1bb6f31729573da6";
const BRIDGE_SHA = "32d8ad5e406ff13d7558e2d3a29fe44bb9f6108b0644cece83b45e1685d08a6a";
const repositoryRoot = fileURLToPath(new URL("../../../", import.meta.url));
const sha = value => createHash("sha256").update(value).digest("hex");
const order = (a, b) => a < b ? -1 : a > b ? 1 : 0;
const roots = ["StreamViewRetrievalWitnessV1"];

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
    if (!bytes.equals(Buffer.from(source.content, "utf8"))) throw Error("Compiler/Git bytes differ: " + path);
    if (bridge.committedBlobSHA256[path] !== sha(bytes)) throw Error("Bridge/Git hash differs: " + path);
    cursor = end + size + 2;
    literalBytes += size;
  }
  if (cursor !== blobs.length || literalBytes !== 48_186_075) throw Error("Frozen literal inventory differs");
}

export function currentViewRetrievalV1Fixture(inputBytes, outputBytes, bridgeBytes) {
  if (sha(inputBytes) !== INPUT_SHA || sha(outputBytes) !== OUTPUT_SHA) throw Error("Expected exact ABI157 input/output");
  if (sha(bridgeBytes) !== BRIDGE_SHA) throw Error("Expected exact ABI157 committed source bridge");
  const input = JSON.parse(inputBytes), output = JSON.parse(outputBytes), bridge = JSON.parse(bridgeBytes);
  if (bridge.commit !== SOURCE || bridge.sources !== 4059
    || Object.keys(bridge.committedBlobSHA256 ?? {}).length !== 4059
    || !Array.isArray(bridge.mismatches) || bridge.mismatches.length !== 0) throw Error("Invalid committed source bridge");
  if (input.language !== "Solidity" || Object.keys(input.sources ?? {}).length !== 4059
    || output.errors?.some(error => error.severity === "error")) throw Error("Invalid VIEW retrieval ABI157 capture");
  if (execFileSync("git", ["rev-parse", SOURCE + "^{tree}"], { cwd: repositoryRoot, encoding: "utf8" }).trim() !== TREE) throw Error("Frozen tree differs");
  bindAllGitLiterals(input, bridge);
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
  // Select every compiler declaration already in the witness host's imported closure.
  // Nominal library selectors remain separate from ordinary wallet ABIs.
  for (const [path, entries] of candidates) {
    if (!Object.hasOwn(sourceTexts, path)) continue;
    for (const [name, contract] of Object.entries(entries)) select(path, name, contract, kind(path, name) === "library");
  }
  const documents = [
    "docs/integrations/view-attributed-retrieval-witness.md",
    "docs/adr/0054-explicit-non-sanction-preservation-rendering.md",
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
    profile: "current-view-retrieval-v1",
    capture: "parallel-feature-batch157-20260921",
    compilerVersion: "0.8.19",
    sourceCommit: SOURCE,
    sourceTree: TREE,
    sourceCount: 4059,
    compilerReportedCommit: SOURCE,
    committedSourceBridge: { sha256: sha(bridgeBytes), ...bridge },
    literalBytes: 48_186_075,
    inputSha256: INPUT_SHA,
    outputSha256: OUTPUT_SHA,
    sourceBinding: "Every compiler input literal matches its frozen Git blob byte-for-byte; this verifier performs no line-ending normalization. All selected ABIs are complete compiler output, with the full imported source closure of the original retrieval witness. Interpretation documents come from the same source commit.",
    qualification: "Exact ABI157 source/ABI witness for the attributed VIEW retrieval producer at a2973d36. This witness supports the two publish/revoke writes and original prepare/history/current reads; it does not establish client coverage of the companion VIEW inventory or Bundle consumer extension. Historical fixtures remain unchanged. No actual native/Safe execution, runtime provenance, rollback, gas/capacity, release or deployment acceptance is established by this fixture.",
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
    throw Error("Usage: generate-current-view-retrieval-v1-fixture.mjs INPUT OUTPUT COMMITTED_SOURCE_BRIDGE [--check]");
  }
  const rendered = JSON.stringify(currentViewRetrievalV1Fixture(await readFile(input), await readFile(output), await readFile(bridge)), null, 2) + "\n";
  const target = new URL("../test/fixtures/current-view-retrieval-v1-abi.json", import.meta.url);
  if (mode === "--check") {
    if (await readFile(target, "utf8") !== rendered) throw Error("Stale current VIEW retrieval V1 fixture");
    process.stdout.write("Current VIEW retrieval V1 fixture matches\n");
  } else {
    await writeFile(target, rendered, "utf8");
    process.stdout.write("Current VIEW retrieval V1 fixture written\n");
  }
}
