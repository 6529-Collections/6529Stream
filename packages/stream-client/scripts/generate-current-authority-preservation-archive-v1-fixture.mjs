// Focused exact ABI155 witness for current-authority preservation archive clients.
// Never invokes Solidity, modifies captures, or refreshes historical fixtures.
import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { readFile, writeFile } from "node:fs/promises";
import { posix, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { solidityImports } from "./generate-current-entropy-policy-succession-fixture.mjs";

const SOURCE = "e93cb09169dd90fe3b63cb32e93fe1a8955a0ee1";
const TREE = "0760c6a507204204f0c92201583cc7e5cb915f41";
const INPUT_SHA = "900111cb56eca5266fac836d72e444df5ff5a715e10bbfae22ee0ed29ae54e0b";
const OUTPUT_SHA = "e1bbe599cbf87ecfd552360cd7b3687eaa1c7ac710c1da6c89a0d0e2b993f384";
const BRIDGE_SHA = "224b34844a5e586e5f5cb6223567eb3b22027e219459fa2c4722da626ad9d35d";
const repositoryRoot = fileURLToPath(new URL("../../../", import.meta.url));
const sha = value => createHash("sha256").update(value).digest("hex");
const order = (a, b) => a < b ? -1 : a > b ? 1 : 0;
const roots = [
  "StreamCurrentAuthorityPreservationPolicyBundleArchiveCoverageV1",
  "StreamCurrentAuthorityScopedPreservationPolicyBundleArchiveCoverageV1",
  "StreamCurrentAuthorityPreservationPolicyRenderCriticalInventoryV1",
  "StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalInventoryV1"
];

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
  if (cursor !== blobs.length || literalBytes !== 47_822_956) throw Error("Frozen literal inventory differs");
}

export function currentAuthorityPreservationArchiveV1Fixture(inputBytes, outputBytes, bridgeBytes) {
  if (sha(inputBytes) !== INPUT_SHA || sha(outputBytes) !== OUTPUT_SHA) throw Error("Expected exact ABI155 input/output");
  if (sha(bridgeBytes) !== BRIDGE_SHA) throw Error("Expected exact ABI155 committed source bridge");
  const input = JSON.parse(inputBytes), output = JSON.parse(outputBytes), bridge = JSON.parse(bridgeBytes);
  if (bridge.commit !== SOURCE || bridge.sources !== 4014
    || Object.keys(bridge.committedBlobSHA256 ?? {}).length !== 4014
    || !Array.isArray(bridge.mismatches) || bridge.mismatches.length !== 0) throw Error("Invalid committed source bridge");
  if (input.language !== "Solidity" || Object.keys(input.sources ?? {}).length !== 4014
    || output.errors?.some(error => error.severity === "error")) throw Error("Invalid current preservation ABI155 capture");
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
  // Select every compiler declaration already in the four hosts' imported closure.
  // Nominal library selectors remain separate from ordinary wallet ABIs.
  for (const [path, entries] of candidates) {
    if (!Object.hasOwn(sourceTexts, path)) continue;
    for (const [name, contract] of Object.entries(entries)) select(path, name, contract, kind(path, name) === "library");
  }
  const documents = [
    "docs/guides/external-object-archive.md",
    "docs/guides/preservation-inventory.md",
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
    profile: "current-authority-preservation-archive-v1",
    capture: "parallel-feature-batch155-20260921",
    compilerVersion: "0.8.19",
    sourceCommit: SOURCE,
    sourceTree: TREE,
    sourceCount: 4014,
    compilerReportedCommit: SOURCE,
    committedSourceBridge: { sha256: sha(bridgeBytes), ...bridge },
    literalBytes: 47_822_956,
    inputSha256: INPUT_SHA,
    outputSha256: OUTPUT_SHA,
    sourceBinding: "Every compiler input literal matches its frozen Git blob byte-for-byte; this verifier performs no line-ending normalization. All selected ABIs are complete compiler output, with the full imported source closure of both archive and inventory hosts. Interpretation documents come from the same source commit.",
    qualification: "Exact ABI155 source/ABI witness for current-authority preservation archive coverage at e93cb091, including the four exact fixed-preservation V2 correspondence pairs. Fixture inclusion alone does not imply client workflow coverage. Historical ABI146 inventory clients retain their original fixture. Archive coverage does not imply current inventory-source admission or finality. No actual native/Safe execution, runtime provenance, rollback, gas/capacity, release or deployment acceptance is established by this fixture.",
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
    throw Error("Usage: generate-current-authority-preservation-archive-v1-fixture.mjs INPUT OUTPUT COMMITTED_SOURCE_BRIDGE [--check]");
  }
  const rendered = JSON.stringify(currentAuthorityPreservationArchiveV1Fixture(await readFile(input), await readFile(output), await readFile(bridge)), null, 2) + "\n";
  const target = new URL("../test/fixtures/current-authority-preservation-archive-v1-abi.json", import.meta.url);
  if (mode === "--check") {
    if (await readFile(target, "utf8") !== rendered) throw Error("Stale current-authority preservation archive V1 fixture");
    process.stdout.write("Current-authority preservation archive V1 fixture matches\n");
  } else {
    await writeFile(target, rendered, "utf8");
    process.stdout.write("Current-authority preservation archive V1 fixture written\n");
  }
}
