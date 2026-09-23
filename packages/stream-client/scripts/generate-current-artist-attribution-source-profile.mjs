// Deterministic source bridge only: retained ABI12 remains compiler evidence for bd4.
// No compiler invocation and no claim of whole-suite source or runtime equivalence.
import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { readFileSync, writeFileSync } from "node:fs";
import { posix, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { solidityImports } from "./generate-current-entropy-policy-succession-fixture.mjs";

const root = fileURLToPath(new URL("../../../", import.meta.url));
const fixtureURL = new URL("../test/fixtures/current-artist-recovered-multiple-attestation-hydration-abi.json", import.meta.url);
const outputURL = new URL("../test/fixtures/current-artist-attribution-source-profile.json", import.meta.url);
const BASE = "bd4a291e9e159cbbb5079a9a2a418fb151a8c01b";
const TARGET = "c715354ed57d2ab639f874cc595b272a7631de71";
const TREE = "3df66325b3b251755a6b2df7de0bf239fa4eb8b4";
const FIXTURE_SHA = "2cd33a780cfd61c9d338a917ce029596b2b0a9c62542e7ab1b502a29ea19c6e9";
const sha = bytes => createHash("sha256").update(bytes).digest("hex");
const sorted = object => Object.fromEntries(Object.entries(object).sort(([a], [b]) => a < b ? -1 : a > b ? 1 : 0));
const roots = ["StreamArtistOnboardingRegistry", "StreamArtistOnboardingCoordinator", "StreamArtistBindingLifecycle", "StreamArtistCollaboratorLifecycle", "StreamArtistIdentityAuthority", "StreamArtistAcceptanceLifecycle", "StreamArtistAttributionLifecycle", "StreamArtistPayoutLifecycle", "StreamArtistConsentFinalityLifecycle", "StreamArtistArchiveV2"];
const writes = ["fileAttributionClaim", "openAttributionDispute", "recordCounterStatement", "resolveAttributionDispute", "revokeAttribution", "vetoAttributionRepudiation", "cancelAttributionRepudiation", "executeAttributionRepudiation", "withdrawAttributionDispute"];
const hydration = ["hydrateArtistAuthorityWithDelegations", "hydrateArtistAuthority", "hydrateArtistAuthorityWithPayout", "hydrateArtistAuthorityWithEconomics", "hydrateArtistAuthorityWithReadiness", "hydrateArtistAuthorityWithPublications", "hydrateArtistAuthorityWithEntropyFindings"];
const documents = ["docs/adr/0048-attribution-repudiation-identity-effects.md", "docs/adr/0050-attribution-dispute-withdrawal.md", "docs/architecture/artist-operation61-dispute-withdrawal.json", "docs/artist-attribution-disputes.md", "docs/artist-attribution-repudiation.md", "docs/integrations/artist-attribution-dispute-capacity.md", "docs/integrations/artist-attribution-terminal-reads.md"];

function git(args, input) { return execFileSync("git", args, { cwd: root, input, maxBuffer: 64 * 1024 * 1024, windowsHide: true }); }
function blobs(commit, paths) {
  const raw = git(["cat-file", "--batch"], paths.map(path => `${commit}:${path}\n`).join(""));
  const result = {}; let cursor = 0;
  for (const path of paths) {
    const end = raw.indexOf(10, cursor), line = raw.subarray(cursor, end).toString("utf8"), match = /^([0-9a-f]{40}) blob ([0-9]+)$/.exec(line);
    if (!match) throw Error(`Expected committed blob ${commit}:${path}: ${line}`);
    const length = Number(match[2]); cursor = end + 1;
    const bytes = raw.subarray(cursor, cursor + length); cursor += length;
    if (raw[cursor++] !== 10) throw Error("Invalid git batch separator");
    const text = bytes.toString("utf8");
    if (!Buffer.from(text, "utf8").equals(bytes)) throw Error(`Invalid UTF-8: ${path}`);
    result[path] = { blob: match[1], sha256: sha(bytes), byteLength: length, text };
  }
  if (cursor !== raw.length) throw Error("Unexpected git batch tail");
  return result;
}
const imports = (path, text) => solidityImports(text).map(value => value.startsWith(".") ? posix.normalize(posix.join(posix.dirname(path), value)) : value);
function retainedClosure(fixture, paths) {
  const seen = new Set();
  function visit(path) {
    if (seen.has(path)) return;
    const text = fixture.sourceTexts[path];
    if (typeof text !== "string") throw Error(`Missing retained source ${path}`);
    if (sha(Buffer.from(text)) !== fixture.sourceHashes[path]) throw Error(`Retained source hash mismatch ${path}`);
    seen.add(path); imports(path, text).forEach(visit);
  }
  paths.forEach(visit); return [...seen].sort();
}
// Return exact function bytes, skipping braces in strings/comments. This is a
// source comparison, not a Solidity parser or executable dispatch proof.
export function sourceFunction(source, name) {
  const marker = new RegExp(`\\bfunction\\s+${name}\\s*\\(`, "g"), matches = [...source.matchAll(marker)];
  if (matches.length !== 1) throw Error(`Expected one source function ${name}`);
  const start = matches[0].index, rest = source.slice(start);
  const tokens = /\/\*[\s\S]*?\*\/|\/\/[^\r\n]*|"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|[{};]/g;
  let depth = 0, opened = false;
  for (const match of rest.matchAll(tokens)) {
    if (match[0] === "{") { opened = true; depth++; }
    else if (match[0] === "}" && --depth === 0 && opened) return rest.slice(0, match.index + 1);
    else if (match[0] === ";" && !opened) return rest.slice(0, match.index + 1);
  }
  throw Error(`Unclosed source function ${name}`);
}

export function artistAttributionSourceProfile() {
  const raw = readFileSync(fixtureURL);
  if (sha(raw) !== FIXTURE_SHA) throw Error("Expected exact retained ABI12 fixture");
  const fixture = JSON.parse(raw);
  if (fixture.sourceCommit !== BASE || git(["rev-parse", `${TARGET}^{tree}`]).toString().trim() !== TREE) throw Error("Source coordinate mismatch");
  const rootPaths = roots.map(name => fixture.selections[name].source);
  const oldPaths = retainedClosure(fixture, rootPaths);
  const oldGit = blobs(BASE, oldPaths);
  for (const path of oldPaths) if (oldGit[path].text !== fixture.sourceTexts[path]) throw Error(`Retained compiler source differs from raw Git ${path}`);
  const current = {}; let pending = [...rootPaths];
  while (pending.length) {
    Object.assign(current, blobs(TARGET, [...new Set(pending)].sort()));
    pending = [...new Set(Object.entries(current).flatMap(([path, row]) => imports(path, row.text)).filter(path => !Object.hasOwn(current, path)))];
  }
  const oldSet = new Set(oldPaths), currentPaths = Object.keys(current).sort();
  const rows = {}, overrides = {}, changes = [], additions = [];
  for (const path of currentPaths) {
    const row = current[path], old = oldSet.has(path) ? oldGit[path] : null;
    rows[path] = { blob: row.blob, sha256: row.sha256, byteLength: row.byteLength, retainedCompilerSourceEqual: old?.text === row.text };
    if (!old || old.text !== row.text) {
      overrides[path] = row.text;
      if (!old) additions.push(path);
      else changes.push({ path, compilerBlob: old.blob, compilerSha256: old.sha256, compilerBytes: old.byteLength, currentBlob: row.blob, currentSha256: row.sha256, currentBytes: row.byteLength });
    }
  }
  const writerPath = "smart-contracts/domains/artist/StreamArtistRegistryWriterExtension.sol";
  const previous = oldGit[writerPath].text, writer = current[writerPath].text;
  const forwarders = Object.fromEntries(writes.filter(name => previous.includes(`function ${name}(`)).map(name => {
    const before = sourceFunction(previous, name), after = sourceFunction(writer, name);
    if (before !== after) throw Error(`Attribution forwarding changed: ${name}`);
    return [name, { sha256: sha(before), byteLength: Buffer.byteLength(before) }];
  }));
  let restored = writer;
  for (const name of hydration) restored = restored.replace(sourceFunction(writer, name), sourceFunction(previous, name));
  // Match only the added statement, never consume preceding import statements.
  const statement = writer.match(/import\s*\{\s*StreamArtistRegistryAuthorityHydrationWriter[^}]*\}\s*from\s*"\.\/StreamArtistRegistryAuthorityHydrationWriter\.sol";\r?\n/);
  if (!statement || restored.replace(statement[0], "") !== previous) throw Error("Writer delta exceeds seven hydration forwarders and one import");
  const retainedDocuments = {};
  for (const [path, row] of Object.entries(blobs(TARGET, documents))) retainedDocuments[path] = row;
  const operationalNames = ["AttributionClaimOperations", "AttributionClaimState", "AttributionDisputeTransport", "CoordinatorDisputeTransport", "DisputeAdmission", "DisputeHashes", "DisputeIdentityMutation", "DisputeOperations", "DisputeReadEncoding", "DisputeState", "DisputeWithdrawalAdmission", "DisputeWithdrawalOperations", "DisputeWithdrawalState", "RepudiationAdmission", "RepudiationAttributionTransport", "RepudiationFacts", "RepudiationHashes", "RepudiationIdentityMutation", "RepudiationOperations", "RepudiationReadEncoding", "RepudiationState", "RepudiationTiming"];
  const operationalSources = operationalNames.map(name => `smart-contracts/domains/artist/StreamArtist${name}.sol`);
  for (const path of [...rootPaths, ...operationalSources]) if (!rows[path]?.retainedCompilerSourceEqual) throw Error(`Original producer root changed: ${path}`);
  return {
    schemaVersion: 1, profile: "artist-attribution-original-operations-10-44-50-61",
    compilerEvidence: { sourceCommit: BASE, sourceTree: fixture.sourceTree, capture: fixture.capture, inputSha256: fixture.inputSha256, outputSha256: fixture.outputSha256, fixtureFile: "current-artist-recovered-multiple-attestation-hydration-abi.json", fixtureSha256: FIXTURE_SHA, fixtureBytes: raw.length },
    currentSource: { commit: TARGET, tree: TREE }, roots, rootPaths, operationalSources, writes,
    qualification: { compilerWasRerun: false, currentWholeSuiteSourceEqual: false, originalOperationalProducersEqual: true, nativeExecutionVerified: false, linkedRuntimeAdmissionVerified: false, description: "The retained compiler evidence belongs to bd4. Concrete roots and the original attribution operations are raw-byte identical at c715. The complete current import closure is recorded, including separately retained recovery/hydration deltas; those deltas are not compiler or semantic equivalence proofs." },
    statistics: { retainedClosureSources: oldPaths.length, retainedClosureBytes: oldPaths.reduce((n, path) => n + oldGit[path].byteLength, 0), currentClosureSources: currentPaths.length, currentClosureBytes: currentPaths.reduce((n, path) => n + current[path].byteLength, 0), equalSources: currentPaths.filter(path => rows[path].retainedCompilerSourceEqual).length, changedSources: changes.length, addedSources: additions.length },
    changes, additions, removedSources: oldPaths.filter(path => !current[path]), writerDelta: { path: writerPath, replacedHydrationMethods: hydration, addedImport: "StreamArtistRegistryAuthorityHydrationWriter", preservedOperationalForwarders: forwarders },
    sources: sorted(rows), sourceOverrides: sorted(overrides), documents: sorted(retainedDocuments),
  };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  if (process.argv.slice(2).some(arg => arg !== "--check")) throw Error("Usage: node generate-current-artist-attribution-source-profile.mjs [--check]");
  const result = artistAttributionSourceProfile(), bytes = Buffer.from(JSON.stringify(result, null, 2) + "\n");
  if (process.argv.includes("--check")) { if (!readFileSync(outputURL).equals(bytes)) throw Error("Attribution source profile is stale"); }
  else writeFileSync(outputURL, bytes);
  console.log(JSON.stringify({ ...result.statistics, bytes: bytes.length, sha256: sha(bytes), check: process.argv.includes("--check") }));
}
