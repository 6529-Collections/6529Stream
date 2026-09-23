// Read-only source/compiler/tool joins for the separate strict eda profile.
// This never compiles, executes the Python tool, accesses RPC or admits runtime.
import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { readFile, writeFile } from "node:fs/promises";
import { resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";
import { FunctionFragment, ParamType, id } from "ethers";

const SOURCE = "eda052c75dc9fd5c4e2e658bdf453ab01f5b7c0e";
const TREE = "1a71ae4ee9806c601237129d81e494058c547ee0";
const MANIFEST = "cd955be78e90fe333276c3731581cb71799586d96bcba7d1c27fe4abe3dc1a55";
const INPUT = "5fd1a5370ea1df068958317c48f67120e5cf9199ffe8e99ef5b99657b824374c";
const OUTPUT = "9ccdd82f1dee6b2d3a1b5ff3562417f64db27d72903b8fe2c8c06387b293ca90";
const BRIDGE = "d4ef14a96f8018de4ea99176e19c80009707439d5e9e7d8d72a163d342dee9af";
const root = fileURLToPath(new URL("../../../", import.meta.url));
const sha = value => createHash("sha256").update(value).digest("hex");
const retain = bytes => ({ bytes: bytes.length, sha256: sha(bytes), text: bytes.toString("utf8") });
const normalize = text => text.replace(/\r\n/g, "\n");
function requireValue(condition, message) { if (!condition) throw Error(message); }

function gitBlobs(paths) {
  const bytes = execFileSync("git", ["cat-file", "--batch"], {
    cwd: root, input: paths.map(path => `${SOURCE}:${path}\n`).join(""), maxBuffer: 256 * 1024 * 1024,
  });
  let offset = 0; const result = {};
  for (const path of paths) {
    const end = bytes.indexOf(10, offset), header = bytes.subarray(offset, end).toString("ascii").split(" "), size = Number(header[2]);
    requireValue(end >= offset && header[1] === "blob" && Number.isSafeInteger(size) && size >= 0, `Missing Git source ${path}`);
    result[path] = bytes.subarray(end + 1, end + 1 + size); offset = end + size + 2;
  }
  requireValue(offset === bytes.length, "Unconsumed Git source bytes");
  return result;
}

export async function currentPreservationRootInterludeV2Fixture(directory, inputBytes, outputBytes, bridgeBytes) {
  const dir = resolve(directory), manifestBytes = await readFile(resolve(dir, "manifest.json"));
  requireValue(sha(manifestBytes) === MANIFEST, "Expected exact v2 manifest");
  const manifest = JSON.parse(manifestBytes), files = {};
  requireValue(manifest.files.length === 27 && manifest.toolVersion === 2 && manifest.sourceCommit === SOURCE, "Wrong v2 inventory/source");
  for (const entry of manifest.files) {
    const path = resolve(dir, entry.path);
    requireValue(path.startsWith(dir + sep), "Manifest path escape");
    const bytes = await readFile(path);
    requireValue(bytes.length === entry.bytes && sha(bytes) === entry.sha256, `Changed tool file ${entry.path}`);
    files[entry.path] = bytes;
  }
  requireValue(sha(inputBytes) === INPUT && sha(outputBytes) === OUTPUT && sha(bridgeBytes) === BRIDGE, "Changed ABI164 capture");
  const input = JSON.parse(inputBytes), output = JSON.parse(outputBytes), bridge = JSON.parse(bridgeBytes);
  const paths = Object.keys(input.sources).sort();
  requireValue(paths.length === 4119 && bridge.commit === SOURCE && bridge.sources === 4119 && bridge.mismatches.length === 0, "Wrong ABI164 source bridge");
  requireValue(Object.keys(bridge.committedBlobSHA256).length === paths.length, "Incomplete committed source bridge");
  requireValue(!(output.errors ?? []).some(error => error.severity === "error"), "Compiler capture contains errors");
  requireValue(execFileSync("git", ["rev-parse", `${SOURCE}^{tree}`], { cwd: root, encoding: "utf8" }).trim() === TREE, "Changed source tree");
  const blobs = gitBlobs(paths);
  for (const path of paths) {
    const source = input.sources[path];
    requireValue(typeof source.content === "string" && !Object.hasOwn(source, "urls"), `Nonliteral compiler source ${path}`);
    requireValue(sha(blobs[path]) === bridge.committedBlobSHA256[path], `Git source bridge differs ${path}`);
    requireValue(normalize(blobs[path].toString("utf8")) === normalize(source.content), `Compiler/Git source differs ${path}`);
  }
  const report = JSON.parse(files["source-plan.json"]), rejoin = JSON.parse(files["evidence/abi-rejoin.json"]);
  requireValue(report.sourceCommit === SOURCE && report.sourcePins.length === 59 && report.abi.length === 35, "Wrong source report");
  requireValue(rejoin.sourceCommit === SOURCE && rejoin.sourceJoins.length === 59 && rejoin.abiEntries.length === 35, "Wrong ABI rejoin");
  const methods = report.abi.map(entry => {
    const reviewed = rejoin.abiEntries.find(row => row.target === entry.target && row.signature === entry.signature);
    requireValue(reviewed?.match === true, `Unreviewed ABI entry ${entry.signature}`);
    const [source, contract] = reviewed.compiledCoordinate.split(":");
    const compiled = output.contracts[source]?.[contract];
    const matching = compiled?.abi.filter(row => row.type === "function" && FunctionFragment.from(row).format("sighash") === entry.signature);
    requireValue(matching?.length === 1, `Missing compiler function ${entry.signature}`);
    const abi = matching[0], returns = `(${abi.outputs.map(p => ParamType.from(p).format("sighash")).join(",")})`;
    requireValue(returns === entry.returns && id(entry.signature).slice(0, 10) === entry.selector
      && `0x${compiled.evm.methodIdentifiers[entry.signature]}` === entry.selector, `Original ABI differs ${entry.signature}`);
    return { ...entry, source, contract, abi, compilerSourceSha256: sha(input.sources[source].content) };
  });
  const selected = [...new Set([...report.sourcePins.map(pin => pin.path), ...methods.map(method => method.source)])].sort();
  const sources = {};
  for (const path of selected) {
    requireValue(blobs[path] !== undefined, `Uncompiled selected source ${path}`);
    sources[path] = retain(blobs[path]);
  }
  for (const pin of report.sourcePins) {
    const source = sources[pin.path], joined = rejoin.sourceJoins.find(row => row.path === pin.path);
    requireValue(source.sha256 === pin.sha256 && source.bytes === pin.bytes, `Reported source differs ${pin.path}`);
    requireValue(joined?.committedSha256 === pin.sha256 && joined.compilerContentSha256 === sha(input.sources[pin.path].content), `Reviewed source join differs ${pin.path}`);
  }
  const retainedPaths = ["source-plan.json", "interlude.py", "algorithm-equivalence.json", "algorithm-source.diff",
    "evidence/abi-rejoin.json", "evidence/source-abi-rejoin-review.json", "evidence/mechanical-evidence.json"];
  return {
    schemaVersion: 1, profile: "current-preservation-root-interlude-v2", sourceCommit: SOURCE, sourceTree: TREE,
    manifest: retain(manifestBytes), evidence: Object.fromEntries(retainedPaths.map(path => [path, retain(files[path])])),
    syntheticInputs: Object.fromEntries(["collection", "scoped"].flatMap(kind => ["admission", "request"].map(part => {
      const path = `example.synthetic.${kind}.${part}.json`; return [path, retain(files[path])];
    }))),
    compiler: { capture: "ABI164", inputSha256: INPUT, outputSha256: OUTPUT, bridgeSha256: BRIDGE, literalSources: paths.length,
      transport: "Every compiler literal matches the exact committed blob after CRLF-to-LF normalization; raw Git hashes retained separately." },
    methods, sources,
    qualification: "Exact59 reviewed source pins and35 selected ordinary ABI entries are joined to accepted ABI164. All4119 input literals match eda Git with declared CRLF normalization. This is source/ABI evidence only, not a complete linked-runtime closure, actual Safe implementation, native execution, bootstrap/state-import admission, signatures, protocol receipts or deployment readiness. V1 evidence remains unchanged; helper-only and later sources need their own explicit rejoin and strict version.",
  };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [directory, input, output, bridge, mode] = process.argv.slice(2);
  requireValue(directory && input && output && bridge && (mode === undefined || mode === "--check"), "Usage: generate-current-preservation-root-interlude-v2-fixture.mjs TOOL_DIRECTORY ABI_INPUT ABI_OUTPUT ABI_BRIDGE [--check]");
  const fixture = await currentPreservationRootInterludeV2Fixture(directory, await readFile(input), await readFile(output), await readFile(bridge));
  const rendered = JSON.stringify(fixture, null, 2) + "\n", target = new URL("../test/fixtures/current-preservation-root-interlude-v2-source.json", import.meta.url);
  if (mode === "--check") requireValue(await readFile(target, "utf8") === rendered, "Stale v2 root interlude witness");
  else await writeFile(target, rendered, "utf8");
  process.stdout.write(mode === "--check" ? "V2 root interlude witness matches\n" : "V2 root interlude witness written\n");
}
