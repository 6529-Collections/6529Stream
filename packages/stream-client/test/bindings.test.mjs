import test from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, readFile, writeFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { resolve, join } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";
import { Interface } from "ethers";
import { BoundStreamClient, boundStackConfigFromJSON, toSafeCall } from "../dist/index.js";
import { renderBindings, generateBindings } from "../scripts/generate-bindings.mjs";

const root = fileURLToPath(new URL("../", import.meta.url));
const addr = "0x1111111111111111111111111111111111111111";
const sender = "0x2222222222222222222222222222222222222222";
const abi = JSON.parse(new Interface([
  "function revision() view returns (uint256)",
  "function values() view returns (uint256 length,uint256 ok)",
  "function namedTuple() view returns (tuple(uint256 length,uint256 then) result)",
  "function nestedTuple() view returns (tuple(uint256 id,tuple(uint256 length)[] children) result)",
  "function configure(uint256 revision)",
  "function configure(address owner)",
  "function purchase(tuple(uint256,address) order) payable returns (uint256)",
  "event Purchased(uint256 indexed id)"
]).formatJson());
const catalog = { core: abi };
const config = () => boundStackConfigFromJSON({ schemaVersion: 1, chainId: "31337", addresses: { core: addr } }, catalog);
const build = () => ({ solcVersion: "0.8.19", solcLongVersion: "0.8.19+commit.7dd6d404",
  input: { language: "Solidity", sources: { "contracts/Current.sol": { content: "// Controlled compiler fixture for generator tests, not deployment evidence." } } },
  output: { contracts: { "contracts/Current.sol": { Current: { abi } } } } });
const targets = { core: { source: "contracts/Current.sol", contract: "Current" } };
const bytes = value => Buffer.from(JSON.stringify(value));

test("explicit catalog drives reads, overloaded writes, positional tuples and exact Safe calls", async () => {
  const calls = [], iface = new Interface(abi);
  const provider = { getNetwork: async () => ({ chainId: 31337n }), call: async call => { calls.push(call); return iface.encodeFunctionResult("revision", [29n]); } };
  const client = new BoundStreamClient(provider, config(), catalog);
  assert.equal(await client.read("core", "revision", []), 29n);
  const write = client.prepare("core", "configure(uint256)", [29n]);
  assert.equal(write.data, iface.encodeFunctionData("configure(uint256)", [29n]));
  assert.throws(() => client.prepare("core", "configure", [29n]), /ambiguous/);
  assert.throws(() => client.prepare("core", "ownerOf", [1n]), /Unknown function/);
  const purchase = client.prepare("core", "purchase", [[9n, sender]], { value: 2n ** 100n });
  assert.deepEqual(toSafeCall(purchase), { to: addr, data: purchase.data, value: (2n ** 100n).toString(), operation: 0 });
  await client.simulate(purchase, sender);
  assert.deepEqual(calls.at(-1), { ...purchase, from: sender });
  assert.throws(() => client.prepare("core", "configure(uint256)", [1n], { value: 1n }), /nonpayable/);
  await assert.rejects(client.read("core", "configure(uint256)", [1n]), /view or pure/);
});

test("client snapshots supplied ABI/configuration and keeps emitter and chain checks", async () => {
  const mutable = { core: structuredClone(abi) }, supplied = config();
  const provider = { getNetwork: async () => ({ chainId: 1n }), call: async () => { throw Error("must not reach RPC call"); } };
  const client = new BoundStreamClient(provider, supplied, mutable);
  mutable.core.length = 0;
  assert.equal(client.prepare("core", "revision", []).data, new Interface(abi).encodeFunctionData("revision", []));
  await assert.rejects(client.read("core", "revision", []), /chain ID/);
  assert.throws(() => client.interface("missing"), /Unknown contract/);
  assert.throws(() => client.address("toString"), /No address configured/);
  const event = client.interface("core").encodeEventLog("Purchased", [7n]);
  assert.equal(client.uniqueEvent({ status: 1, logs: [{ address: addr, ...event }] }, "core", "Purchased").args[0], 7n);
  assert.throws(() => client.uniqueEvent({ status: 1, logs: [{ address: sender, ...event }] }, "core", "Purchased"), /Expected one/);
});

test("compiler projections select exact source/contract and reject unsupported or missing inputs", () => {
  const first = renderBindings(bytes(build()), bytes(targets));
  assert.deepEqual(renderBindings(bytes(build()), bytes(targets)), first);
  assert.match(first["contracts.ts"], /configure\(uint256\)/);
  assert.match(first["contracts.ts"], /readonly \[readonly \[bigint, Address\]\]/);
  assert.doesNotMatch(first["contracts.ts"], /field0/);
  assert.doesNotMatch(first["index.ts"], /nativeSaleTypedData/);
  const compact = structuredClone(build());
  for (const f of compact.output.contracts["contracts/Current.sol"].Current.abi) { if (f.outputs?.length === 0) delete f.outputs; if (f.inputs?.length === 0) delete f.inputs; }
  assert.equal(renderBindings(bytes(compact), bytes(targets))["contracts.ts"], first["contracts.ts"]);
  const changed = build(); changed.input.sources["contracts/Current.sol"].content += "\n";
  assert.notEqual(renderBindings(bytes(changed), bytes(targets))["provenance.ts"], first["provenance.ts"]);
  for (const mutate of [
    b => { b.solcVersion = "0.8.20"; },
    b => { b.output.errors = [{ severity: "error" }]; },
    b => { delete b.input.sources["contracts/Current.sol"].content; },
    b => { delete b.output.contracts["contracts/Current.sol"].Current; },
  ]) { const invalid = build(); mutate(invalid); assert.throws(() => renderBindings(bytes(invalid), bytes(targets))); }
  assert.throws(() => renderBindings(bytes(build()), bytes({ alternate: targets.core })), /core binding/);
  assert.throws(() => renderBindings(bytes(build()), Buffer.from('{"core":{"source":"contracts/Current.sol","contract":"Current"},"__proto__":{"source":"contracts/Current.sol","contract":"Current"}}')), /Invalid binding/);
});

test("generated catalog typechecks real usage, catches stale output and protects retained projections", async () => {
  const temp = await mkdtemp(join(tmpdir(), "stream-compiler-bindings-"));
  try {
    const buildInfo = join(temp, "build.json"), targetFile = join(temp, "targets.json"), out = join(temp, "generated");
    await writeFile(buildInfo, bytes(build())); await writeFile(targetFile, bytes(targets));
    const options = { buildInfo, targets: targetFile, out };
    await generateBindings(options); await generateBindings({ ...options, check: true });
    await writeFile(join(temp, "package.json"), '{"type":"module"}');
    await writeFile(join(temp, "usage.ts"), `import { StreamClient } from "./generated/index.js";
declare const client: StreamClient;
client.prepare("core", "configure(uint256)", [1n]);
client.prepare("core", "purchase", [[1n, "0x1111"]], {value: 1n});
client.read("core", "revision", []).then(value => value + 1n);
client.read("core", "values", []).then(value => { const size: number = value.length; return value[0] + value.ok; });
client.read("core", "namedTuple", []).then(value => value[0] + value[1]);
client.read("core", "nestedTuple", []).then(value => value.children[0]![0] + value.id);
// @ts-expect-error Result.length is the tuple length, not the ABI bigint field
client.read("core", "values", []).then(value => { const wrong: bigint = value.length; });
// @ts-expect-error Result.then does not expose a named ABI field
client.read("core", "namedTuple", []).then(value => value.then + 1n);
// @ts-expect-error integer ABI inputs require bigint
client.prepare("core", "configure(uint256)", [1]);
// @ts-expect-error overloaded functions require an exact signature
client.prepare("core", "configure", [1n]);
// @ts-expect-error an unnamed tuple must be positional, not invented property names
client.prepare("core", "purchase", [{field0: 1n, field1: "0x1111"}]);
// @ts-expect-error mutations cannot use read
client.read("core", "configure(uint256)", [1n]);
// @ts-expect-error current catalog cannot silently use old RC1 methods
client.read("core", "ownerOf", [1n]);
`);
    await writeFile(join(temp, "tsconfig.json"), JSON.stringify({ compilerOptions: {
      target: "ES2022", module: "NodeNext", moduleResolution: "NodeNext", strict: true, noEmit: true, skipLibCheck: true,
      paths: { "@6529/stream-client": [join(root, "dist/index.d.ts")], ethers: [join(root, "node_modules/ethers/lib.esm/index.d.ts")] }
    }, include: ["*.ts", "generated/*.ts"] }));
    const result = spawnSync(process.execPath, [join(root, "node_modules/typescript/bin/tsc"), "-p", join(temp, "tsconfig.json")], { encoding: "utf8", timeout: 30000 });
    assert.equal(result.status, 0, result.stdout + result.stderr);
    const file = join(out, "contracts.ts"); await writeFile(file, (await readFile(file, "utf8")) + "\n");
    await assert.rejects(generateBindings({ ...options, check: true }), /Stale compiler binding/);
    await assert.rejects(generateBindings({ ...options, out: join(root, "src/generated") }), /retained release/);
  } finally {
    assert.ok(resolve(temp).startsWith(resolve(tmpdir()) + "/") || resolve(temp).startsWith(resolve(tmpdir()) + "\\"));
    await rm(temp, { recursive: true, force: true });
  }
});

test("reserved Result fields use positional output access, including nested tuples", async () => {
  const iface = new Interface(abi);
  const values = { values: [99n, 4n], namedTuple: [[99n, 5n]], nestedTuple: [[7n, [[9n]]]] };
  const provider = { getNetwork: async () => ({ chainId: 31337n }), call: async call => {
    const fragment = iface.getFunction(call.data.slice(0, 10));
    return iface.encodeFunctionResult(fragment, values[fragment.name]);
  } };
  const client = new BoundStreamClient(provider, config(), catalog);
  const many = await client.read("core", "values", []);
  assert.equal(many.length, 2); assert.equal(many[0], 99n); assert.equal(many.ok, 4n);
  const single = await client.read("core", "namedTuple", []);
  assert.equal(single.length, 2); assert.equal(single[0], 99n); assert.equal(single[1], 5n); assert.equal(single.then, undefined);
  const nested = await client.read("core", "nestedTuple", []);
  assert.equal(nested.id, 7n); assert.equal(nested.children[0].length, 1); assert.equal(nested.children[0][0], 9n);
});
