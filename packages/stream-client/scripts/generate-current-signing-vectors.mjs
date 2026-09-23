// Produce encoding-only vectors from actual compiled current getter code.
// Starts an isolated loopback Anvil; never accepts an existing RPC or signer.
import { readFile, writeFile } from "node:fs/promises";
import { createHash } from "node:crypto";
import { spawn } from "node:child_process";
import { createServer } from "node:net";
import { resolve } from "node:path";
import { Interface, getCreateAddress, toBeHex } from "ethers";

const args = process.argv.slice(2);
if (args.length !== 4 || args[0] !== "--build-info" || args[2] !== "--output") throw new Error("Usage: node scripts/generate-current-signing-vectors.mjs --build-info <native.json> --output <vectors.json>");
const buildPath = resolve(args[1]), outputPath = resolve(args[3]);
const raw = await readFile(buildPath), build = JSON.parse(raw);
const sha = value => "sha256:" + createHash("sha256").update(value).digest("hex");
if (build.solcVersion !== "0.8.19") throw new Error("Expected the reviewed Solidity 0.8.19 compilation");
const houseSource = "smart-contracts/domains/auctions/StreamNativeEnglishAuction.sol";
const houseName = "StreamNativeEnglishAuction";
const products = build.output.contracts;
const contract = (source, name) => { const item = products[source]?.[name]; if (!item?.evm) throw new Error(`Missing native product ${source}:${name}`); return item; };
const house = contract(houseSource, houseName);
const nodes = new Map();
function visit(source, name) {
  const key = source + ":" + name;
  if (nodes.has(key)) return;
  const item = contract(source, name); nodes.set(key, { source, name, item });
  for (const section of ["bytecode", "deployedBytecode"]) for (const [s, names] of Object.entries(item.evm[section].linkReferences ?? {})) for (const n of Object.keys(names)) visit(s, n);
}
for (const [source, names] of Object.entries(house.evm.deployedBytecode.linkReferences)) for (const name of Object.keys(names)) visit(source, name);
const libraries = [...nodes.values()].sort((a, b) => (a.source + ":" + a.name).localeCompare(b.source + ":" + b.name));
const selector = new Interface(house.abi);
const schemes = [
  ["nativeAuctionCreation", "creationAuthorizationDigest"],
  ["nativeAuctionBid", "bidAuthorizationDigest"],
  ["nativeCustodyAcquisition", "custodyAcquisitionDigest"],
  ["preparedNativeCustodyAcquisition", "preparedCustodyAcquisitionDigest"],
];
const listener = createServer();
await new Promise((done, reject) => { listener.once("error", reject); listener.listen(0, "127.0.0.1", done); });
const port = listener.address().port; await new Promise(done => listener.close(done));
const child = spawn(process.env.ANVIL_BIN ?? "anvil", ["--host", "127.0.0.1", "--port", String(port), "--chain-id", "31337", "--silent"], { stdio: "ignore", windowsHide: true });
let childError; child.on("error", error => { childError = error; });
let requestId = 0;
async function rpc(method, params = []) {
  const response = await fetch(`http://127.0.0.1:${port}`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ jsonrpc: "2.0", id: ++requestId, method, params }), signal: AbortSignal.timeout(15000) });
  if (!response.ok) throw new Error(`Loopback RPC HTTP ${response.status}`);
  const result = await response.json(); if (result.error) throw new Error(`${method}: ${result.error.message}`); return result.result;
}
try {
  const until = Date.now() + 15000; let ready = false;
  while (Date.now() < until) {
    if (childError) throw childError; if (child.exitCode !== null) throw new Error("Owned Anvil exited");
    try { ready = await rpc("web3_clientVersion"); if (ready) break; } catch {}
    await new Promise(done => setTimeout(done, 100));
  }
  if (!ready || !String(ready).toLowerCase().includes("anvil") || child.exitCode !== null) throw new Error("Owned Anvil did not become ready");
  const chainId = BigInt(await rpc("eth_chainId")), accounts = await rpc("eth_accounts");
  if (chainId !== 31337n || await rpc("eth_blockNumber") !== "0x0" || await rpc("eth_getTransactionCount", [accounts[0], "latest"]) !== "0x0") throw new Error("Expected a fresh owned Anvil");
  const addresses = Object.fromEntries(libraries.map((entry, i) => [entry.source + ":" + entry.name, getCreateAddress({ from: accounts[0], nonce: i })]));
  function linked(section) {
    let code = section.object.replace(/^0x/, "");
    for (const [source, names] of Object.entries(section.linkReferences ?? {})) for (const [name, refs] of Object.entries(names)) {
      const address = addresses[source + ":" + name]; if (!address) throw new Error("Unbound library");
      for (const ref of refs) { if (ref.length !== 20) throw new Error("Unexpected library slot"); code = code.slice(0, ref.start * 2) + address.slice(2).toLowerCase() + code.slice((ref.start + 20) * 2); }
    }
    if (!/^[0-9a-f]*$/i.test(code)) throw new Error("Unresolved native bytecode"); return "0x" + code;
  }
  const deployedLibraries = [];
  for (const entry of libraries) {
    const bytecode = linked(entry.item.evm.bytecode), address = addresses[entry.source + ":" + entry.name];
    const tx = await rpc("eth_sendTransaction", [{ from: accounts[0], data: bytecode, gas: "0x1000000" }]);
    const receipt = await rpc("eth_getTransactionReceipt", [tx]);
    if (receipt?.status !== "0x1" || receipt.contractAddress.toLowerCase() !== address.toLowerCase()) throw new Error("Library creation failed");
    const code = await rpc("eth_getCode", [address, "latest"]);
    deployedLibraries.push({ source: entry.source, name: entry.name, address, creationSha256: sha(Buffer.from(bytecode.slice(2), "hex")), runtimeSha256: sha(Buffer.from(code.slice(2), "hex")), transactionHash: tx });
  }
  const address = "0x0000000000000000000000000000000065290001";
  const runtime = linked(house.evm.deployedBytecode); await rpc("anvil_setCode", [address, runtime]);
  if ((await rpc("eth_getCode", [address, "latest"])).toLowerCase() !== runtime.toLowerCase()) throw new Error("House runtime differs");
  const vectors = [];
  for (const [kind, getter] of schemes) {
    const method = selector.getFunction(getter); const fields = method.inputs[0].components;
    const message = Object.fromEntries(fields.map((field, i) => {
      const n = BigInt(i + 1);
      const value = field.type === "bytes32" ? toBeHex(0x123400n + n, 32) : field.type === "address" ? toBeHex(0xabc000n + n, 20) : field.type === "uint64" ? ((1n << 64n) - 64n + n).toString() : field.type === "uint256" ? ((1n << 200n) + n).toString() : null;
      if (value === null) throw new Error(`Unexpected signed field ${field.type}`); return [field.name, value];
    }));
    const calldata = selector.encodeFunctionData(method, [message]);
    const result = await rpc("eth_call", [{ to: address, data: calldata }, "latest"]);
    const digest = selector.decodeFunctionResult(method, result)[0];
    vectors.push({ request: { kind, chainId: chainId.toString(), verifyingContract: address, message }, getter, fields: fields.map(({ name, type }) => ({ name, type })), calldata, result, digest });
  }
  const sourcePaths = new Set([houseSource, ...libraries.map(entry => entry.source)]);
  const fixture = { schemaVersion: 1, description: "Encoding-only actual current-house getter calls on a disposable Anvil. Linked libraries were normally deployed; the exact linked house runtime was installed with anvil_setCode, without its constructor or initialized immutable dependencies. These four getters use only the authorization, chain ID and house address. No auction lifecycle, valid authorization, deployment or gas acceptance is claimed.", nativeBuildId: build.id, nativeBuildSha256: sha(raw), nativeCompilerInputSha256: sha(JSON.stringify(build.input)), sourceHashes: Object.fromEntries([...sourcePaths].sort().map(source => [source, sha(build.input.sources[source].content)])), houseRuntimeSha256: sha(Buffer.from(runtime.slice(2), "hex")), houseImmutableReferences: house.evm.deployedBytecode.immutableReferences ?? {}, chainId: chainId.toString(), house: address, libraries: deployedLibraries, getterAbi: house.abi.filter(item => item.type === "function" && schemes.some(([, getter]) => getter === item.name)), vectors };
  await writeFile(outputPath, JSON.stringify(fixture, null, 2) + "\n");
  console.log(`Wrote ${vectors.length} actual getter vectors from ${build.id}; ${libraries.length} linked libraries; encoding only.`);
} finally { child.kill(); }
