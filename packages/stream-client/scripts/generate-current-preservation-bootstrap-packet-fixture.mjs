/** Offline schema witness extraction only. No compiler, native execution, RPC or packet admission.
 * Usage: node scripts/generate-current-preservation-bootstrap-packet-fixture.mjs
 *   --artifact-dir <caller-baseline-abi-v1> --historical-tuple-witness <retained-json>
 *   --handoff <caller-baseline-2825-handoff.json> [--check]
 * The compiler captured an earlier working source; its sole Bootstrap delta is a comment word.
 * Both identities remain recorded instead of relabeling compiler evidence as the final source.
 */
import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

const repo = fileURLToPath(new URL("../../../", import.meta.url));
const sourceCommit = "06a361af3f2aee053652b7d1d331480b439f1966";
const sourceTree = "45eadcea1043f24d389b781dfa260285bd5da754";
const sha = b => createHash("sha256").update(b).digest("hex");
const args = process.argv.slice(2);
const options = new Map();
for (let i = 0; i < args.length; i++) {
  const name = args[i];
  if (!["--check", "--artifact-dir", "--historical-tuple-witness", "--handoff"].includes(name) || options.has(name)) throw Error("Unknown or duplicate generator argument");
  if (name === "--check") options.set(name, true);
  else {
    const value = args[++i];
    if (!value || value.startsWith("--")) throw Error(`Missing value for ${name}`);
    options.set(name, value);
  }
}
for (const name of ["--artifact-dir", "--historical-tuple-witness", "--handoff"]) if (!options.has(name)) throw Error(`Required ${name}`);
const artifact = options.get("--artifact-dir"), check = options.has("--check");
const git = args => execFileSync("git", args, { cwd: repo, windowsHide: true, maxBuffer: 4194304 });
if (git(["rev-parse", `${sourceCommit}^{tree}`]).toString().trim() !== sourceTree) throw Error("Final source tree differs");
const expected = {
  "input.json": "0f4dd2721c069146c94b32d71bb333070fe6b07a2a0db22c12ca94c3020fbc9b",
  "output.json": "d6ac4ec66dcca6e63eb8fc41112ee6c7a4a32684ca60fef6c0cbab881e256288",
  "source-pins.json": "fc11639e878a718fd7b7d6e68900b06e805408cb9de2a39f2e2d61cb57122d8f",
  "result.json": "3a0d9a6ea6cf49f917668ada29a08aeb5087d2c3102ef8909836c5e752f3f74d",
};
const captures = Object.fromEntries(Object.entries(expected).map(([name, hash]) => {
  const bytes = readFileSync(join(artifact, name));
  if (sha(bytes) !== hash) throw Error(`Compiler artifact differs: ${name}`);
  return [name, JSON.parse(bytes.toString("utf8"))];
}));
const input = captures["input.json"], output = captures["output.json"], pins = captures["source-pins.json"], result = captures["result.json"];
if (result.status !== "PASS" || result.bytecodeRequested !== false || result.evmStarted !== false || result.sourcePinsStable !== true || result.errors.length !== 0 || result.inputSha256 !== expected["input.json"] || result.outputSha256 !== expected["output.json"] || result.sourcePinsSha256 !== expected["source-pins.json"]) throw Error("Unexpected compiler qualification");
const handoffBytes = readFileSync(options.get("--handoff"));
const handoffSha = "a1a2114a63c43ee178c8bfab5d69647bd45ecc78f0657d56363db5a51d67688b";
if (sha(handoffBytes) !== handoffSha) throw Error("Historical handoff differs");
const oldBytes = readFileSync(options.get("--historical-tuple-witness"));
const oldSha = "bcddf720360fa5192283e1424b831498e626cbe383863fffd9580981674f7624";
if (sha(oldBytes) !== oldSha) throw Error("Historical tuple witness differs");
const old = JSON.parse(oldBytes.toString("utf8"));
const bootstrap = "test/helpers/StreamCurrentAuthorityPreservationCallerBootstrap.sol";
const scenario = "test/helpers/StreamCurrentAuthorityPreservationCallerScenario.sol";
const paths = [bootstrap, scenario,
  "test/helpers/FoundryAccountStateExport.sol",
  "test/helpers/StreamCurrentAuthorityPreservationCallerPreparationFixture.sol",
  "test/helpers/StreamCurrentAuthorityCollectionPreservationCallerFixture.sol",
  "test/helpers/StreamCurrentAuthorityScopedPreservationPolicyPublicationFixture.sol",
  "test/current/tooling/StreamCurrentAuthorityPreservationCallerExport.t.sol",
  "test/current/tooling/StreamCurrentAuthorityPreservationCallerBootstrapFile.t.sol",
  "test/current/tooling/FoundryAccountStateDump.t.sol",
  "test/current/tooling/FoundryAccountStateExport.t.sol",
  "smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol",
];
const sources = Object.fromEntries(paths.map(path => {
  const bytes = git(["show", `${sourceCommit}:${path}`]), text = bytes.toString("utf8"), compilerText = input.sources[path]?.content;
  if (sha(Buffer.from(compilerText ?? "", "utf8")) !== pins[path]) throw Error(`Source compiler pin differs: ${path}`);
  if (path === bootstrap) {
    const before = "/// script result", after = "/// execution result";
    if (compilerText.split(before).length !== 2 || compilerText.replace(before, after) !== text) throw Error("Bootstrap comment-only delta differs");
  } else if (!bytes.equals(Buffer.from(compilerText, "utf8"))) throw Error(`Selected source changed: ${path}`);
  return [path, { bytes: bytes.length, sha256: sha(bytes), compilerInputSha256: pins[path], text }];
}));
const declarations = [
  [bootstrap, "StreamCurrentAuthorityPreservationCallerBootstrap"],
  [scenario, "StreamCurrentAuthorityPreservationCallerScenario"],
  ["test/current/tooling/StreamCurrentAuthorityPreservationCallerExport.t.sol", "StreamCurrentAuthorityPreservationCallerExportTest"],
  ["test/current/tooling/FoundryAccountStateDump.t.sol", "FoundryAccountStateDumpTest"],
  ["test/current/tooling/FoundryAccountStateExport.t.sol", "FoundryAccountStateExportTest"],
];
const abis = Object.fromEntries(declarations.map(([path, name]) => [name, output.contracts[path][name].abi]));
const fn = (name, method) => abis[name].find(x => x.type === "function" && x.name === method);
for (const [prior, name, method] of [[old.scenario.abi, "StreamCurrentAuthorityPreservationCallerScenario", "preparation"], [old.bootstrap.abi, "StreamCurrentAuthorityPreservationCallerBootstrap", "exportPreparation"]]) {
  const oldFn = prior.find(x => x.type === "function" && x.name === method);
  if (JSON.stringify(oldFn.outputs) !== JSON.stringify(fn(name, method).outputs)) throw Error("Historical tuple shape changed");
}
const account = fn("FoundryAccountStateDumpTest", "parse").outputs[0];
const snapshot = fn("FoundryAccountStateExportTest", "check").inputs.find(x => x.internalType === "struct FoundryAccountStateExport.Snapshot");
if (!snapshot) throw Error("Snapshot compiler witness missing");
const schema = {
  prestate: [account],
  snapshot: [snapshot],
  preparation: fn("StreamCurrentAuthorityPreservationCallerScenario", "preparation").outputs,
  writer: [{ name: "writerState", type: "tuple", internalType: "struct StreamCurrentAuthorityPreservationCallerBootstrap.WriterState", components: fn("StreamCurrentAuthorityPreservationCallerScenario", "writerState").outputs }],
  cut: fn("StreamCurrentAuthorityPreservationCallerBootstrap", "exportPreparation").outputs,
  complete: [{ name: "profile", type: "bytes32" }, { name: "cutHash", type: "bytes32" }],
};
const fixture = {
  schemaVersion: 1, qualification: "Offline schema/source witness only; no packet, dump grammar/parity, native execution, closure, library trace, import or deployment admission.",
  sourceCommit, sourceTree, compiler: { artifacts: expected, result, bootstrapCommentOnlyDelta: { before: "/// script result", after: "/// execution result" } },
  historicalTupleWitness: { sha256: oldSha, sourceCommit: old.sourceCommit, status: old.status },
  historicalHandoff: { sha256: handoffSha, value: JSON.parse(handoffBytes.toString("utf8")) },
  declarations: Object.fromEntries(declarations.map(([path, name]) => [name, path])), abis, sources, schema,
};
const target = new URL("../test/fixtures/current-preservation-bootstrap-packet-source.json", import.meta.url);
const bytes = Buffer.from(`${JSON.stringify(fixture, null, 2)}\n`, "utf8");
if (check) { if (!readFileSync(target).equals(bytes)) throw Error("Bootstrap schema fixture is stale"); }
else writeFileSync(target, bytes);
process.stdout.write(`${JSON.stringify({ check, bytes: bytes.length, sha256: sha(bytes), selectedSources: paths.length, declarations: declarations.length })}\n`);
