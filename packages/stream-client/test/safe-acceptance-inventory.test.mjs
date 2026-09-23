import test from "node:test";
import assert from "node:assert/strict";
import { FunctionFragment, id } from "ethers";
import { buildInventory, canonical, sha256 } from "../scripts/safe-acceptance-inventory.mjs";

const selector = signature => id(signature).slice(2, 10);
const fn = text => { const fragment = FunctionFragment.from("function " + text); return { ...JSON.parse(fragment.format("json")), stateMutability: fragment.stateMutability }; };
const genesis = () => ({ entries: Array.from({ length: 37 }, (_, i) => ({ id: i + 1, key: "ROLE_" + (i + 1), deployment_scope: "singleton" })) });
function fixture() {
  const input = { language: "Solidity", settings: { optimizer: { runs: 200, enabled: true }, evmVersion: "paris" },
    sources: { "Base.sol": { content: "contract Base { function owner() external view returns(address); }\n" },
      "A.sol": { content: "contract A is Base { uint256 public counter; function call(uint256) external; function call(address) external; receive() external payable {} fallback() external {} }\n" } } };
  const abi = [fn("owner() view returns(address)"), fn("counter() view returns(uint256)"), fn("call(uint256)"), fn("call(address)"),
    { type: "receive", stateMutability: "payable" }, { type: "fallback", stateMutability: "nonpayable" }];
  const base = { id: 1, nodeType: "ContractDefinition", name: "Base", contractKind: "contract", abstract: false, linearizedBaseContracts: [1],
    nodes: [{ id: 2, nodeType: "FunctionDefinition", kind: "function", name: "owner", functionSelector: selector("owner()"), visibility: "public", body: {}, src: "0:64:0" }] };
  const derived = { id: 3, nodeType: "ContractDefinition", name: "A", contractKind: "contract", abstract: false, linearizedBaseContracts: [3, 1],
    nodes: [
      { id: 4, nodeType: "VariableDeclaration", name: "counter", functionSelector: selector("counter()"), visibility: "public", src: "0:20:1" },
      ...["call(uint256)", "call(address)"].map((s, i) => ({ id: 5 + i, nodeType: "FunctionDefinition", kind: "function", functionSelector: selector(s), visibility: "external", body: {}, src: "0:20:1" })),
      ...["receive", "fallback"].map((kind, i) => ({ id: 7 + i, nodeType: "FunctionDefinition", kind, visibility: "external", body: {}, src: "0:20:1" })) ] };
  const output = { errors: [], sources: { "Base.sol": { ast: { nodes: [base] } }, "A.sol": { ast: { nodes: [derived] } } },
    contracts: { "Base.sol": { Base: { abi: [abi[0]] } }, "A.sol": { A: { abi,
      evm: { methodIdentifiers: Object.fromEntries(abi.filter(r => r.type === "function").map(r => {
        const s = FunctionFragment.from(r).format("sighash"); return [s, selector(s)];
      })) } } } } };
  return { input, output, profile: { capture: { sourceCommit: "a".repeat(40), inputSha256: "b".repeat(64), outputSha256: "c".repeat(64),
    settingsSha256: sha256(canonical(input.settings)) }, products: [{ fqn: "A.sol:A", reason: "original selected product" }],
    edges: [], roleMappings: [{ roleId: 1, fqns: ["A.sol:A"], resolution: "resolved" }] }, genesis: genesis(), deployment: { status: "planning", instances: [] } };
}
function addProduct(f, source, name, abi, kind = "contract") {
  f.input.sources[source] = { content: kind + " " + name + " {}\n" };
  f.output.contracts[source] = { [name]: { abi } };
  f.output.sources[source] = { ast: { nodes: [{ id: 100 + Object.keys(f.output.contracts).length, nodeType: "ContractDefinition",
    name, contractKind: kind, abstract: false, nodes: [] }] } };
  return source + ":" + name;
}

test("enumerates full compiler ABI including inherited function, getter, overloads, receive and fallback", () => {
  const f = fixture(), result = buildInventory(f);
  assert.equal(result.schemaVersion, 1);
  assert.equal(result.entries.length, 6);
  assert.deepEqual(result.entries.filter(e => e.signature.startsWith("call(")).map(e => e.signature), ["call(address)", "call(uint256)"]);
  const owner = result.entries.find(e => e.signature === "owner()");
  assert.equal(owner.selector, "0x8da5cb5b");
  assert.equal(owner.declarations[0].fqn, "Base.sol:Base");
  assert.equal(result.entries.find(e => e.signature === "counter()").declarations[0].nodeType, "VariableDeclaration");
  for (const kind of ["receive", "fallback"]) {
    const row = result.entries.find(e => e.kind === kind);
    assert.equal(row.selector, null);
    assert.equal(row.declarations[0].nodeType, "FunctionDefinition");
  }
  assert(result.entries.every(e => e.status === "uncovered" && e.endpoint === "unknown"));
  assert.equal(result.roles.length, 37);
  assert.equal(result.unresolved.filter(r => r.kind === "unresolved-role").length, 36);
  assert.deepEqual(result.deployments, []);
  assert(result.unresolved.some(r => r.kind === "no-deployment-instances"));
});

test("inventory IDs bind capture, full ABI including return values/mutability, source bytes and exact FQN", () => {
  const original = fixture(), baseline = buildInventory(original).entries.find(e => e.signature === "owner()");
  for (const mutate of [
    f => { f.profile.capture.sourceCommit = "d".repeat(40); },
    f => { f.profile.capture.outputSha256 = "d".repeat(64); },
    f => { f.output.contracts["A.sol"].A.abi[0].outputs[0].type = "uint256"; },
    f => { f.output.contracts["A.sol"].A.abi[0].stateMutability = "pure"; },
    f => { f.input.sources["A.sol"].content += "// source drift\n"; },
  ]) {
    const f = fixture(); mutate(f);
    const row = buildInventory(f).entries.find(e => e.signature === "owner()");
    assert.notEqual(row.id, baseline.id);
    assert.equal(row.selector, baseline.selector);
  }
  assert.match(baseline.id, /^[a-f0-9]{64}$/);
});

test("same short names remain separate FQNs and duplicate or noncanonical product aliases reject", () => {
  const f = fixture();
  const first = addProduct(f, "one/Same.sol", "Same", [fn("value() view returns(uint256)")]);
  const second = addProduct(f, "two/Same.sol", "Same", [fn("value() view returns(uint256)")]);
  f.profile.products.push({ fqn: first, reason: "first" }, { fqn: second, reason: "second" });
  const result = buildInventory(f), rows = result.entries.filter(e => e.signature === "value()");
  assert.equal(rows.length, 2); assert.notEqual(rows[0].id, rows[1].id);
  f.profile.products.push({ fqn: first, reason: "duplicate alias" });
  assert.throws(() => buildInventory(f), /Duplicate FQN product alias/);
  for (const bad of ["A", "./A.sol:A", "a/../A.sol:A", "A.sol\\A", "A.sol:A:Alias"]) {
    const g = fixture(); g.profile.products[0].fqn = bad;
    assert.throws(() => buildInventory(g), /FQN|source path/);
  }
});

test("only explicit reachable edges expand the selection, with cycles bounded and imports not inferred", () => {
  const f = fixture(), b = addProduct(f, "B.sol", "B", [fn("b()")]), c = addProduct(f, "C.sol", "C", [fn("c()")]);
  const detached = addProduct(f, "Detached.sol", "Detached", [fn("d()")]);
  f.profile.edges = [
    { from: "A.sol:A", to: b, kind: "constructor", sourceRef: { path: "A.sol", line: 1 } },
    { from: b, to: c, kind: "fixed-worker" }, { from: c, to: b, kind: "callback" },
    { from: detached, to: "A.sol:A", kind: "not-reachable" },
  ];
  const result = buildInventory(f);
  assert.deepEqual(result.products.map(p => p.fqn), ["A.sol:A", b, c]);
  assert(result.unresolved.some(r => r.kind === "unreachable-profile-edge" && r.from === detached));
  assert.equal(result.products.find(p => p.fqn === c).selection.reason, "explicit edge closure");
  f.profile.edges.push({ from: c, to: "Missing.sol:M", kind: "constructor" });
  assert.throws(() => buildInventory(f), /Dangling compiler FQN edge/);
});

test("roles preserve all37 definitions; unknown mappings never disappear or acquire acceptance", () => {
  const f = fixture(); f.profile.roleMappings = [];
  const result = buildInventory(f);
  assert.deepEqual(result.roles.map(r => r.id), Array.from({ length: 37 }, (_, i) => i + 1));
  assert(result.roles.every(r => r.mapping.resolution === "unresolved"));
  f.profile.roleMappings = [{ roleId: 1, fqns: ["Base.sol:Base"], resolution: "resolved" }];
  assert.throws(() => buildInventory(f), /unselected role FQN/);
  f.profile.roleMappings = [{ roleId: 1, fqns: ["A.sol:A", "A.sol:A"], resolution: "resolved" }];
  assert.throws(() => buildInventory(f), /Duplicate FQN role alias/);
  f.profile.roleMappings = [{ roleId: 38, fqns: [], resolution: "unknown" }];
  assert.throws(() => buildInventory(f), /role mapping/);
  const g = fixture(); g.genesis.entries.pop(); assert.throws(() => buildInventory(g), /all37/);
});

test("ordinary selectors cross-check compiler evidence or record explicit derivation provenance", () => {
  const f = fixture(); delete f.output.contracts["A.sol"].A.evm;
  assert(buildInventory(f).entries.filter(e => e.kind === "function").every(e => e.selectorProvenance === "derived-canonical-ABI"));
  const g = fixture(); g.output.contracts["A.sol"].A.evm.methodIdentifiers["owner()"] = "00000000";
  assert.throws(() => buildInventory(g), /Compiler\/ABI selector differs/);
  const h = fixture(); h.output.contracts["A.sol"].A.evm.methodIdentifiers["owner()"] = "0x8da5cb5b";
  assert.throws(() => buildInventory(h), /Malformed compiler selector/);
});

test("library nominal selectors are compiler-authoritative and expanded tuple guesses remain unresolved", () => {
  const f = fixture(), l = addProduct(f, "L.sol", "L", [
    { type: "function", name: "set", inputs: [{ name: "v", type: "L.Box" }], outputs: [], stateMutability: "nonpayable" },
    fn("value(uint256) pure returns(uint256)"),
    { type: "function", name: "expanded", inputs: [{ name: "v", type: "tuple", internalType: "struct L.Box", components: [{ name: "n", type: "uint256" }] }], outputs: [], stateMutability: "view" },
  ], "library");
  f.output.contracts["L.sol"].L.evm = { methodIdentifiers: {
    "set(L.Box)": selector("set(L.Box)"), "value(uint256)": selector("value(uint256)"), "expanded(L.Box)": selector("expanded(L.Box)"),
  } };
  f.profile.products.push({ fqn: l, reason: "linked original worker" });
  f.profile.callbackObligations = [{ id: "expanded-worker-call", fqn: l, signature: "expanded((uint256))" }];
  const result = buildInventory(f), rows = result.entries.filter(e => e.fqn === l);
  assert.equal(rows.find(e => e.signature === "set(L.Box)").selector, "0x" + selector("set(L.Box)"));
  assert.equal(rows.find(e => e.signature === "value(uint256)").selectorProvenance, "compiler-methodIdentifiers");
  const expanded = rows.filter(e => e.signature === "expanded((uint256))");
  assert.equal(expanded.length, 2); assert(expanded.every(e => e.selector === null));
  assert(result.unresolved.some(r => r.kind === "unresolved-library-selector" && r.fqn === l));
  assert.equal(result.products.find(p => p.fqn === l).methodIdentifiers["expanded(L.Box)"], selector("expanded(L.Box)"));
});

test("absent AST remains explicit without dropping ABI rows or fabricating declaration evidence", () => {
  const f = fixture(); delete f.output.sources;
  const result = buildInventory(f);
  assert.equal(result.entries.length, 6);
  assert.equal(result.products[0].contractKind, "unknown");
  assert(result.entries.every(e => e.declarations.length === 0));
  assert(result.unresolved.some(r => r.kind === "missing-contract-AST"));
});

test("callbacks have distinct identities and external Safe receiver obligations remain unresolved", () => {
  const f = fixture();
  f.profile.callbackObligations = [
    { id: "owner-callback", fqn: "A.sol:A", signature: "owner()", callerClass: "self", workflow: "enclosing flow" },
    { id: "safe-erc721", fqn: null, externalTarget: "Safe", signature: "onERC721Received(address,address,uint256,bytes)" },
  ];
  const result = buildInventory(f), callbacks = result.entries.filter(e => e.kind === "callback");
  assert.equal(callbacks.length, 2); assert(callbacks.every(e => e.status === "uncovered"));
  assert.notEqual(callbacks.find(e => e.fqn === "A.sol:A").id, result.entries.find(e => e.kind === "function" && e.signature === "owner()").id);
  const external = callbacks.find(e => e.fqn === null);
  assert.equal(external.selector, "0x150b7a02"); assert.equal(external.abiSha256, null);
  assert(result.unresolved.some(r => r.kind === "external-callback"));
  const changed = fixture(); changed.profile.callbackObligations = [{ ...f.profile.callbackObligations[1], externalTarget: "AnotherReceiver" }];
  assert.notEqual(buildInventory(changed).entries.find(e => e.kind === "callback").id, external.id);
  f.profile.callbackObligations.push(f.profile.callbackObligations[0]);
  assert.throws(() => buildInventory(f), /Duplicate callback identity/);
});

test("callbacks reject unknown functions and dangling compiled FQNs", () => {
  for (const callback of [
    { id: "x", fqn: "A.sol:A", signature: "missing()" },
    { id: "x", fqn: "Missing.sol:M", signature: "owner()" },
    { id: "x", fqn: null, signature: "owner()" },
  ]) {
    const f = fixture(); f.profile.callbackObligations = [callback];
    assert.throws(() => buildInventory(f), /Callback absent|Dangling callback|external callback target/);
  }
});

test("deployment rows are preserved separately, never synthesized from roles or relabeled", () => {
  const f = fixture(), instance = { instance_id: "one", target: { source: "A.sol", name: "A" }, address: "0x" + "1".repeat(40), review_status: "pending" };
  f.deployment.instances = [instance];
  const result = buildInventory(f);
  assert.deepEqual(result.deployments, [instance]);
  assert(result.entries.every(e => e.status === "uncovered"));
  f.deployment.instances.push({ ...instance, instance_id: "two" });
  assert.throws(() => buildInventory(f), /Duplicate deployment address alias/);
  const g = fixture(); g.deployment.instances = [{ ...instance, fqn: "Base.sol:Base" }];
  assert.throws(() => buildInventory(g), /Conflicting deployment FQN/);
  const h = fixture(); h.deployment.instances = [{ ...instance, id: "alias" }];
  assert.throws(() => buildInventory(h), /Conflicting deployment identity/);
});

test("source references bind literal input text and source pins, not filesystem paths or lexical permission claims", () => {
  const f = fixture();
  f.profile.products[0].sourceRefs = [{ path: "A.sol", line: 1, sha256: sha256(f.input.sources["A.sol"].content) }];
  assert.equal(buildInventory(f).sourcePins["A.sol"], sha256(f.input.sources["A.sol"].content));
  f.profile.products[0].sourceRefs[0].sha256 = "e".repeat(64);
  assert.throws(() => buildInventory(f), /Source reference hash differs/);
  f.profile.products[0].sourceRefs = [{ path: "AGENTS.md", line: 1 }];
  assert.throws(() => buildInventory(f), /literal compiler input/);
  f.profile.products[0].sourceRefs = [{ path: "A.sol", line: 50 }];
  assert.throws(() => buildInventory(f), /line out of bounds/);
});

test("invalid captures, missing literals, compiler errors and duplicate ABI entries fail closed", () => {
  for (const [mutate, pattern] of [
    [f => { f.profile.capture.settingsSha256 = "e".repeat(64); }, /settings hash/],
    [f => { f.profile.capture.inputSha256 = "not-a-hash"; }, /SHA-256/],
    [f => { f.profile.capture.sourceCommit = "HEAD"; }, /Git source commit/],
    [f => { delete f.input.sources["A.sol"].content; }, /literal compiler source/],
    [f => { f.output.errors = [{ severity: "error", message: "compile failure" }]; }, /Compiler output contains errors/],
    [f => { f.output.contracts["A.sol"].A.abi.push(f.output.contracts["A.sol"].A.abi[0]); }, /Duplicate ABI entrypoint/],
  ]) { const f = fixture(); mutate(f); assert.throws(() => buildInventory(f), pattern); }
});

test("canonical values are sorted and strict; inventory output is deterministic, immutable and inputs remain unchanged", () => {
  assert.equal(canonical({ z: 1, a: { b: 2, a: true } }), '{"a":{"a":true,"b":2},"z":1}');
  assert.equal(canonical({ "2": 2, "10": 10 }), '{"10":10,"2":2}');
  assert.equal(sha256("abc"), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
  assert.equal(sha256(new TextEncoder().encode("abc")), sha256("abc"));
  const sparse = new Array(1); sparse.extra = 1;
  for (const value of [undefined, NaN, Infinity, 1n, -0, sparse, new Map(), { bad: undefined }]) assert.throws(() => canonical(value));
  const cyclic = {}; cyclic.self = cyclic; assert.throws(() => canonical(cyclic), /cyclic/);
  const f = fixture(), before = structuredClone(f), one = buildInventory(f), two = buildInventory(f);
  assert.equal(canonical(one), canonical(two)); assert.deepEqual(f, before);
  assert(Object.isFrozen(one.entries[0])); assert.throws(() => { one.entries[0].status = "covered"; }, TypeError);
  const order = fixture(); order.profile.products.push({ fqn: "Base.sol:Base", reason: "base" }); order.profile.products.reverse();
  assert.deepEqual(buildInventory(order).products.map(p => p.fqn), ["A.sol:A", "Base.sol:Base"]);
});

test("explicit unresolved notes and selection roots survive without conferring coverage", () => {
  const f = fixture(); f.profile.unresolved = [{ kind: "unsupported-role-alias", roleId: 16 }];
  f.profile.selectionRoots = [{ fqn: "A.sol:A", source: "current supported product" }];
  const result = buildInventory(f);
  assert.deepEqual(result.selectionRoots, f.profile.selectionRoots);
  assert(result.unresolved.some(r => r.kind === "unsupported-role-alias" && r.roleId === 16));
  assert(result.entries.every(e => e.status === "uncovered"));
});

test("missing AST cannot turn unmatched library tuple ABI into a guessed ordinary selector", () => {
  const f = fixture();
  const l = addProduct(f, "Opaque.sol", "Opaque", [{ type: "function", name: "apply", inputs: [{ name: "v", type: "tuple", components: [{ name: "n", type: "uint256" }] }], outputs: [], stateMutability: "view" }]);
  delete f.output.sources;
  f.output.contracts["Opaque.sol"].Opaque.evm = { methodIdentifiers: { "apply(Opaque.Box)": selector("apply(Opaque.Box)") } };
  f.profile.products.push({ fqn: l, reason: "compiled product without AST" });
  const result = buildInventory(f), row = result.entries.find(e => e.fqn === l && e.kind === "function");
  assert.equal(row.signature, "apply((uint256))"); assert.equal(row.selector, null);
  assert.equal(row.selectorProvenance, "unresolved-contract-kind-selector");
  assert.equal(result.products.find(p => p.fqn === l).methodIdentifiers["apply(Opaque.Box)"], selector("apply(Opaque.Box)"));
  assert.equal(result.entries.find(e => e.signature === "owner()").selector, "0x8da5cb5b");
  delete f.output.contracts["A.sol"].A.evm;
  assert(buildInventory(f).entries.filter(e => e.fqn === "A.sol:A" && e.kind === "function").every(e => e.selector === null));
});

test("explicit product mode retains provenance edges without promoting internal helpers to callable products", () => {
  const f = fixture(), helper = addProduct(f, "Helper.sol", "Helper", []);
  f.profile.selectionMode = "explicit-products";
  f.profile.edges = [{ from: "A.sol:A", to: helper, kind: "internal-library-reference" }, { from: helper, to: "Base.sol:Base", kind: "inherited-provenance" }];
  const result = buildInventory(f);
  assert.equal(result.selectionMode, "explicit-products");
  assert.deepEqual(result.products.map(p => p.fqn), ["A.sol:A"]);
  assert.deepEqual(result.edges, f.profile.edges);
  assert(!result.unresolved.some(r => r.kind === "unreachable-profile-edge"));
  f.profile.edges.push({ from: helper, to: "Missing.sol:Missing", kind: "dangling" });
  assert.throws(() => buildInventory(f), /Dangling compiler FQN edge/);
  f.profile.edges.pop(); f.profile.selectionMode = "implicit-source-guess";
  assert.throws(() => buildInventory(f), /Unknown selection mode/);
});

test("unmatched compiler method identities remain explicit selector obligations without guessed ABI joins", () => {
  const f = fixture(), l = addProduct(f, "L.sol", "L", [{ type: "function", name: "read", inputs: [{ name: "v", type: "tuple", components: [{ name: "n", type: "uint256" }] }], outputs: [], stateMutability: "view" }], "library");
  f.profile.products.push({ fqn: l, reason: "nominal library" });
  f.output.contracts["L.sol"].L.evm = { methodIdentifiers: { "read(L.Box)": selector("read(L.Box)") } };
  const result = buildInventory(f), rows = result.entries.filter(e => e.fqn === l);
  const abi = rows.find(e => e.kind === "function"), compiler = rows.find(e => e.kind === "compiler-method");
  assert.equal(rows.length, 2); assert.equal(abi.selector, null);
  assert.equal(compiler.signature, "read(L.Box)"); assert.equal(compiler.selector, "0x" + selector("read(L.Box)"));
  assert.equal(compiler.abiIndex, null); assert.equal(compiler.mutability, null);
  assert.equal(compiler.representation, "unmatched-compiler-method-may-alias-ABI-entry");
  assert.equal(compiler.status, "uncovered"); assert.equal(compiler.endpoint, "unknown");
  assert(result.unresolved.some(r => r.kind === "unmatched-compiler-method-ABI" && r.entryId === compiler.id));
  assert.deepEqual(new Set(result.products.find(p => p.fqn === l).entryIds), new Set(rows.map(r => r.id)));
});
