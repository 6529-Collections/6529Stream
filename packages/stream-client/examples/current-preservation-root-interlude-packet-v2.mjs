/** Closed adapter for the pinned Prepared tool's unsigned packets. No I/O or signing. */
import { createHash } from "node:crypto";
import { AbiCoder, Interface, TypedDataEncoder, ZeroAddress, ZeroHash, getAddress, id, keccak256 } from "ethers";

export const PRESERVATION_ROOT_INTERLUDE_SOURCE_COMMIT = "eda052c75dc9fd5c4e2e658bdf453ab01f5b7c0e";
export const PRESERVATION_ROOT_INTERLUDE_SOURCE_REPORT_SHA256 = "66f66b99a6cb5af3c8997ab27c67ece208257eac6a337b78096cea8ff07af706";
export const PRESERVATION_ROOT_INTERLUDE_TOOL_SHA256 = "065f5ee0748ab75f143c5bee600646e3da6e3e6225a91654a0c1f300f72837d7";
export const PRESERVATION_ROOT_INTERLUDE_CAST_SHA256 = "b2541a63789931fc4c170e2502c16c3be259f2da4daba1a8d05ea5cfa7729baa";
export const PRESERVATION_ROOT_INTERLUDE_MAX_PACKET_BYTES = 4 * 1024 * 1024;
const MAX_STRING_BYTES = 2 * 1024 * 1024;
const MAX_DEPTH = 64;
const MAX_NODES = 65536;
const MAX_ARRAY = 4096;
const coder = AbiCoder.defaultAbiCoder();
const SCOPE = "(uint8,uint256,uint256,bytes32)";
const COLLECTION = "(uint256,bytes32,bytes32,string)";
const SCOPED = `(${SCOPE},bytes32,bytes32,uint64,string)`;
const CONSENT = "(uint256,address,bytes32,bytes32)";
const AUTHORIZATION = "(uint256,uint64,bytes)";
const calls = new Interface([
  `function recordContentConsent(${CONSENT},${AUTHORIZATION}) returns (bytes32)`,
  `function publishVerifiedPreservationPolicyContentRoot(${COLLECTION}) returns (bytes32)`,
  `function publishScopedPreservationPolicyContentRootPublication(${SCOPED}) returns (bytes32)`,
]);
const SAFE_FIELDS = [
  ["to", "address"], ["value", "uint256"], ["data", "bytes"], ["operation", "uint8"],
  ["safeTxGas", "uint256"], ["baseGas", "uint256"], ["gasPrice", "uint256"],
  ["gasToken", "address"], ["refundReceiver", "address"], ["nonce", "uint256"],
];
const LIMITATIONS = [
  "Unsigned only; no transactions sent or keys handled.",
  "Block pin is not a state reservation.",
  "No native, gas, deployment, or state-import acceptance asserted.",
];

function requireValue(condition, message) {
  if (!condition) throw Error(message);
}
function exact(value, keys, label) {
  requireValue(value !== null && typeof value === "object" && !Array.isArray(value), `${label}: object required`);
  const actual = Reflect.ownKeys(value);
  requireValue(actual.length === keys.length && actual.every(k => typeof k === "string" && keys.includes(k)), `${label}: unexpected fields`);
}
function array(value, length, label) {
  requireValue(Array.isArray(value) && value.length <= MAX_ARRAY && (length === undefined || value.length === length), `${label}: array width`);
  requireValue(Reflect.ownKeys(value).length === value.length + 1, `${label}: array fields`);
  for (let i = 0; i < value.length; i++) requireValue(Object.hasOwn(value, i), `${label}: sparse array`);
  return value;
}
function scalarText(value, limit = MAX_STRING_BYTES) {
  requireValue(typeof value === "string" && value.length <= limit, "String bound");
  for (let i = 0; i < value.length; i++) {
    const n = value.charCodeAt(i);
    requireValue(n < 0xdc00 || n > 0xdfff, "Invalid Unicode scalar");
    if (n >= 0xd800 && n <= 0xdbff) {
      const next = value.charCodeAt(++i);
      requireValue(next >= 0xdc00 && next <= 0xdfff, "Invalid Unicode scalar");
    }
  }
  requireValue(Buffer.byteLength(value, "utf8") <= limit, "UTF-8 string bound");
  return value;
}
function sha(value) { return createHash("sha256").update(value).digest("hex"); }
function shaText(value) {
  requireValue(typeof value === "string" && /^[0-9a-f]{64}$/.test(value), "Expected lowercase SHA256");
  return value;
}
function hex(value, length, nonzero = false) {
  requireValue(typeof value === "string" && value.length <= MAX_STRING_BYTES && /^0x(?:[0-9a-fA-F]{2})*$/.test(value), "Invalid hex");
  requireValue(length === undefined || value.length === 2 + length * 2, "Wrong hex width");
  const result = value.toLowerCase();
  if (nonzero) requireValue(!/^0x0*$/.test(result), "Zero hex value");
  return result;
}
function addr(value, nonzero = true) { return hex(value, 20, nonzero); }
function uint(value, bits = 256) {
  requireValue(typeof value === "bigint" || (typeof value === "string" && /^[0-9]+$/.test(value) && value.length <= 78), "Exact integer required");
  const result = BigInt(value);
  requireValue(result >= 0n && result < (1n << BigInt(bits)), "Integer width");
  return result;
}
function same(actual, expected, label) { requireValue(actual === expected, `${label} mismatch`); }
function codepointOrder(left, right) {
  const a = Array.from(left), b = Array.from(right);
  for (let i = 0; i < Math.min(a.length, b.length); i++) {
    const difference = a[i].codePointAt(0) - b[i].codePointAt(0);
    if (difference) return difference;
  }
  return a.length - b.length;
}
/** Python json.dumps(sort_keys=True, separators=(',', ':'), ensure_ascii=False). */
function canonical(value, depth = 0, state = { nodes: 0 }) {
  requireValue(depth <= MAX_DEPTH && ++state.nodes <= MAX_NODES, "JSON structure bound");
  if (typeof value === "bigint") return value.toString();
  if (typeof value === "string") return JSON.stringify(scalarText(value));
  if (value === null || typeof value === "boolean") return String(value);
  if (Array.isArray(value)) return `[${array(value, undefined, "JSON").map(v => canonical(v, depth + 1, state)).join(",")}]`;
  requireValue(value !== null && typeof value === "object", "Unsupported JSON value");
  return `{${Object.keys(value).sort(codepointOrder).map(k => `${JSON.stringify(scalarText(k))}:${canonical(value[k], depth + 1, state)}`).join(",")}}`;
}
function canonicalBytes(value) { return canonical(value) + "\n"; }
function freeze(value) {
  if (value && typeof value === "object") {
    for (const child of Object.values(value)) freeze(child);
    Object.freeze(value);
  }
  return value;
}

/** Bound depth, node/array counts and string tokens before JSON allocates its object graph. */
function scan(text) {
  let index = 0, nodes = 0;
  const skip = () => { while (/\s/.test(text[index] ?? "") && index < text.length) index++; };
  function string() {
    requireValue(text[index++] === '"', "JSON string required");
    const start = index;
    while (index < text.length) {
      requireValue(index - start <= MAX_STRING_BYTES * 6, "JSON string token bound");
      const ch = text[index++];
      if (ch === '"') return;
      if (ch === "\\") index++;
    }
    throw Error("Unterminated JSON string");
  }
  function value(depth) {
    requireValue(depth <= MAX_DEPTH && ++nodes <= MAX_NODES, "JSON structure bound");
    skip();
    const ch = text[index];
    if (ch === '"') { string(); return; }
    if (ch === "[" || ch === "{") {
      index++;
      const end = ch === "[" ? "]" : "}";
      skip();
      if (text[index] === end) { index++; return; }
      let count = 0;
      while (true) {
        requireValue(++count <= MAX_ARRAY, "JSON array/object bound");
        if (ch === "{") { skip(); string(); skip(); requireValue(text[index++] === ":", "JSON colon required"); }
        value(depth + 1); skip();
        if (text[index] === end) { index++; return; }
        requireValue(text[index++] === ",", "JSON separator required");
      }
    }
    const start = index;
    while (index < text.length && !/[\s,}\]]/.test(text[index])) index++;
    const token = text.slice(start, index);
    requireValue(token === "true" || token === "false" || token === "null" || /^-?(?:0|[1-9][0-9]*)$/.test(token), "Only integer JSON numeric literals are supported");
    requireValue(token.length <= 79, "JSON integer bound");
  }
  value(0); skip(); same(index, text.length, "JSON trailing bytes");
}

/** Returns only a detached, bounded canonical document; this is not source or RPC attestation. */
export function parsePreservationRootInterludePacket(text) {
  scalarText(text, PRESERVATION_ROOT_INTERLUDE_MAX_PACKET_BYTES);
  scan(text);
  const packet = JSON.parse(text, (_key, value, context) => {
    if (typeof value !== "number") return value;
    requireValue(context && /^-?(?:0|[1-9][0-9]*)$/.test(context.source), "Lossless JSON parsing is required");
    return BigInt(context.source);
  });
  same(canonicalBytes(packet), text, "Exact Python canonical packet bytes");
  requireValue(packet && typeof packet === "object" && !Array.isArray(packet), "Packet object required");
  return freeze(packet);
}

function normalizeManifest(input) {
  exact(input, ["schemaVersion", "chainId", "sourceCommit", "sourceReportSha256", "toolSha256", "castSha256", "bootstrapManifestSha256", "clientPrerequisitePacketSha256", "admissionHash", "registry", "router", "artistSafe"], "Manifest");
  requireValue(input.schemaVersion === 1 || input.schemaVersion === 1n, "Manifest schema");
  const result = { chainId: uint(input.chainId), sourceCommit: input.sourceCommit };
  same(result.sourceCommit, PRESERVATION_ROOT_INTERLUDE_SOURCE_COMMIT, "Source commit");
  for (const [key, expected] of [["sourceReportSha256", PRESERVATION_ROOT_INTERLUDE_SOURCE_REPORT_SHA256], ["toolSha256", PRESERVATION_ROOT_INTERLUDE_TOOL_SHA256], ["castSha256", PRESERVATION_ROOT_INTERLUDE_CAST_SHA256]]) {
    result[key] = shaText(input[key]); same(result[key], expected, key);
  }
  for (const key of ["bootstrapManifestSha256", "clientPrerequisitePacketSha256", "admissionHash"]) result[key] = shaText(input[key]);
  for (const name of ["registry", "router", "artistSafe"]) {
    const p = input[name];
    exact(p, name === "artistSafe" ? ["address", "codeHash", "version", "singleton"] : ["address", "codeHash"], name);
    result[name] = { address: addr(p.address), codeHash: hex(p.codeHash, 32, true) };
    if (name === "artistSafe") {
      requireValue(p.version === "1.3.0" || p.version === "1.4.1", "Unsupported Safe version");
      exact(p.singleton, ["address", "codeHash"], "Safe singleton");
      result[name].version = p.version;
      result[name].singleton = { address: addr(p.singleton.address), codeHash: hex(p.singleton.codeHash, 32, true) };
    }
  }
  return result;
}
function normalizeScope(value, kind) {
  array(value, 4, "Scope");
  const s = [uint(value[0], 8), uint(value[1]), uint(value[2]), hex(value[3], 32)];
  requireValue(s[1] > 0n, "Zero collection");
  requireValue(kind === "collection" ? s[0] === 0n && s[2] === 0n && s[3] === ZeroHash
    : (s[0] === 1n && s[2] > 0n && s[3] === ZeroHash) || ([2n, 3n].includes(s[0]) && s[2] === 0n && s[3] !== ZeroHash), "Unsupported publication scope");
  return s;
}
function normalizePublication(request) {
  const scoped = request.kind === "scoped";
  requireValue(scoped || request.kind === "collection", "Unsupported root kind");
  exact(request, ["kind", "scope", "publication", "outputRecord", "expectedManifest", "expectedRootBinding", "safeTxGas", "deadline", ...(scoped ? ["expectedSnapshotReceipt"] : [])], "Request");
  const scope = normalizeScope(request.scope, request.kind);
  const p = array(request.publication, scoped ? 5 : 4, "Publication");
  const publication = scoped
    ? [normalizeScope(p[0], request.kind), hex(p[1], 32), hex(p[2], 32, true), uint(p[3], 64), scalarText(p[4], 2048)]
    : [uint(p[0]), hex(p[1], 32), hex(p[2], 32, true), scalarText(p[3], 2048)];
  requireValue(publication.at(-1).length > 0, "Empty manifest URI");
  same(canonical(scoped ? publication[0] : publication[0]), canonical(scoped ? scope : scope[1]), "Publication full scope");
  if (scoped) requireValue(publication[3] > 0n, "Zero snapshot revision");
  const output = hex(request.outputRecord, 32, true);
  if (!scoped) same(output, publication[2], "Output record");
  return { kind: request.kind, scope, publication, gas: uint(request.safeTxGas), deadline: uint(request.deadline, 64) };
}
function verifyDocumentaryReads(reads, roles, blockHash) {
  array(reads, undefined, "Reads");
  for (const row of reads) {
    if (Object.hasOwn(row, "transactionHash")) {
      exact(row, ["transactionHash", "transaction", "receipt", "receiptSha256", "receiptBlock"], "Receipt observation");
      hex(row.transactionHash, 32, true);
      same(sha(canonicalBytes(row.receipt)), shaText(row.receiptSha256), "Receipt observation SHA256");
      continue;
    }
    const code = Object.hasOwn(row, "code");
    exact(row, code ? ["role", "target", "code", "codeSha256", "blockHash"]
      : ["role", "target", "calldata", "returndata", "returndataSha256", "blockHash"], "Read observation");
    requireValue(typeof row.role === "string" && Object.hasOwn(roles, row.role), "Unknown observed role");
    same(addr(row.target), roles[row.role].address, "Observed target");
    same(hex(row.blockHash, 32), blockHash, "Observed block");
    if (!code) hex(row.calldata);
    const data = hex(code ? row.code : row.returndata);
    same(sha(Buffer.from(data.slice(2), "hex")), shaText(code ? row.codeSha256 : row.returndataSha256), "Observation SHA256");
  }
}

/** Reconstructs exactly the tool's two phase routes. Hash equality never proves producer execution. */
export function preparePreservationRootInterludePacket(text, manifest, options) {
  exact(options, ["expectedPacketSha256"], "Options");
  const expected = shaText(options.expectedPacketSha256);
  const p = parsePreservationRootInterludePacket(text);
  const packetHash = sha(text);
  same(packetHash, expected, "Packet SHA256");
  const m = normalizeManifest(manifest);
  requireValue(p.phase === "consent" || p.phase === "root", "Only consent/root packets are supported");
  const base = ["schemaVersion", "phase", "sourceReportSha256", "sourceCommit", "castSha256", "admission", "request", "admissionHash", "requestHash", "chainId", "anchor", "rpcBlockId", "reads", "limitations", "unsigned", "toolSha256", "admissionFileSha256", "requestFileSha256"];
  exact(p, [...base, ...(p.phase === "consent" ? ["consent", "authorization", "digest", "aggregateBefore", "currentFamily", "currentContent", "evolution"]
    : ["consentPacketHash", "consentReceiptTxHash", "consentRecord", "newFamily", "aggregateBefore", "priorPacketFileSha256"])], "Packet");
  same(p.schemaVersion, 1n, "Packet schema");
  for (const key of ["sourceCommit", "sourceReportSha256", "toolSha256", "castSha256"]) same(p[key], m[key], key);
  same(uint(p.chainId), m.chainId, "Packet chain");
  for (const key of ["admissionFileSha256", "requestFileSha256"]) shaText(p[key]);
  same(canonical(p.limitations), canonical(LIMITATIONS), "Original limitations");
  const admissionHash = sha(canonicalBytes(p.admission)), requestHash = sha(canonicalBytes(p.request));
  same(admissionHash, shaText(p.admissionHash), "Canonical admission hash");
  same(admissionHash, m.admissionHash, "Reviewed admission hash");
  same(requestHash, shaText(p.requestHash), "Canonical request hash");
  exact(p.admission, ["sourceReportSha256", "sourceCommit", "bootstrapManifestSha256", "clientPrerequisitePacketSha256", "chainId", "roles", "pointers", "suite", "artistBinding", "identityAuthority", "safeOwners", "safeThreshold", "grantRevision"], "Admission");
  for (const key of ["sourceCommit", "sourceReportSha256", "bootstrapManifestSha256", "clientPrerequisitePacketSha256"]) same(p.admission[key], m[key], `Admission ${key}`);
  same(uint(p.admission.chainId), m.chainId, "Admission chain");
  const roleNames = Object.keys(p.admission.roles);
  requireValue(roleNames.length > 0 && roleNames.length <= 64, "Role pin bound");
  const roles = Object.create(null), runtimePins = [], byAddress = new Map();
  const append = pin => {
    if (byAddress.has(pin.address)) same(byAddress.get(pin.address), pin.codeHash, "Conflicting runtime pins");
    else { byAddress.set(pin.address, pin.codeHash); runtimePins.push(pin); }
  };
  for (const name of roleNames) {
    const raw = p.admission.roles[name]; exact(raw, ["address", "codeHash"], "Role pin");
    roles[name] = { address: addr(raw.address), codeHash: hex(raw.codeHash, 32, true) }; append(roles[name]);
  }
  for (const name of ["core", "registry", "coordinator", "identityOwner", "consentOwner", "metadata", "router", "artistSafe", "output"]) requireValue(Object.hasOwn(roles, name), `Missing ${name} pin`);
  for (const name of ["registry", "router", "artistSafe"]) {
    same(roles[name].address, m[name].address, `${name} address`); same(roles[name].codeHash, m[name].codeHash, `${name} runtime`);
  }
  append(m.artistSafe.singleton);
  const r = normalizePublication(p.request);
  if (r.kind === "scoped") requireValue(Object.hasOwn(roles, "snapshot"), "Missing snapshot pin");
  exact(p.anchor, ["number", "hash", "timestamp"], "Anchor");
  const number = uint(p.anchor.number);
  requireValue(number <= BigInt(Number.MAX_SAFE_INTEGER), "Anchor block number bound");
  const anchor = { number: Number(number), hash: hex(p.anchor.hash, 32, true), timestamp: uint(p.anchor.timestamp) };
  exact(p.rpcBlockId, ["blockHash", "requireCanonical"], "RPC block ID");
  same(hex(p.rpcBlockId.blockHash, 32), anchor.hash, "RPC anchor"); same(p.rpcBlockId.requireCanonical, true, "Canonical RPC flag");
  verifyDocumentaryReads(p.reads, roles, anchor.hash);
  array(p.aggregateBefore, 2, "Aggregate"); uint(p.aggregateBefore[0], 64); hex(p.aggregateBefore[1], 32);
  let target, data;
  if (p.phase === "consent") {
    array(p.consent, 4, "Consent"); array(p.authorization, 3, "Authorization");
    const consent = [uint(p.consent[0]), addr(p.consent[1]), hex(p.consent[2], 32), hex(p.consent[3], 32, true)];
    const authorization = [uint(p.authorization[0]), uint(p.authorization[1], 64), hex(p.authorization[2])];
    same(consent[0], r.scope[1], "Consent collection"); same(consent[1], roles.router.address, "Consent Router");
    same(consent[2], id("CONTENT_ROOT"), "Consent family"); same(authorization[1], r.deadline, "Consent deadline");
    same(authorization[2], "0x", "Empty inner authorization signature");
    requireValue(r.deadline > anchor.timestamp, "Expired prepared consent");
    hex(p.digest, 32, true); hex(p.currentFamily, 32, true);
    requireValue(consent[3] !== hex(p.currentFamily, 32), "Unchanged consent state");
    array(p.currentContent, 2, "Current content"); same(addr(p.currentContent[0]), roles.router.address, "Current Router"); hex(p.currentContent[1], 32, true);
    array(p.evolution, 2, "Evolution"); p.evolution.forEach(v => hex(v, 32));
    target = roles.registry.address; data = calls.encodeFunctionData("recordContentConsent", [consent, authorization]);
  } else {
    same(shaText(p.priorPacketFileSha256), shaText(p.consentPacketHash), "Canonical prior consent packet hash");
    hex(p.consentReceiptTxHash, 32, true); hex(p.consentRecord, 32, true); hex(p.newFamily, 32, true);
    target = roles.router.address;
    data = calls.encodeFunctionData(r.kind === "collection" ? "publishVerifiedPreservationPolicyContentRoot" : "publishScopedPreservationPolicyContentRootPublication", [r.publication]);
  }
  exact(p.unsigned, ["safe", "owners", "threshold", "nonce", "transaction", "transactionHash", "inner"], "Unsigned packet");
  const safeAddress = addr(p.unsigned.safe); same(safeAddress, roles.artistSafe.address, "ArtistSafe");
  const owners = array(p.unsigned.owners, undefined, "Safe owners").map(v => addr(v));
  requireValue(new Set(owners).size === owners.length, "Duplicate Safe owner");
  const admittedOwners = array(p.admission.safeOwners, undefined, "Admitted owners").map(v => addr(v));
  same(canonical(owners), canonical(admittedOwners), "Safe owner order");
  const threshold = uint(p.unsigned.threshold), nonce = uint(p.unsigned.nonce);
  same(threshold, uint(p.admission.safeThreshold), "Safe threshold");
  requireValue(threshold > 0n && threshold <= BigInt(owners.length), "Invalid Safe threshold");
  const values = [target, 0n, data, 0n, r.gas, 0n, 0n, ZeroAddress, ZeroAddress, nonce];
  array(p.unsigned.transaction, 10, "Safe transaction");
  const actual = p.unsigned.transaction.map((v, i) => SAFE_FIELDS[i][1] === "address" ? addr(v, false) : SAFE_FIELDS[i][1] === "bytes" ? hex(v) : uint(v, i === 3 ? 8 : 256));
  same(coder.encode(SAFE_FIELDS.map(v => v[1]), actual), coder.encode(SAFE_FIELDS.map(v => v[1]), values), "Exact phase-specific Safe transaction");
  exact(p.unsigned.inner, ["to", "value", "data", "operation"], "Inner call");
  same(addr(p.unsigned.inner.to), target, "Inner target"); same(uint(p.unsigned.inner.value), 0n, "Inner value");
  same(hex(p.unsigned.inner.data), data.toLowerCase(), "Inner calldata"); same(uint(p.unsigned.inner.operation, 8), 0n, "Inner CALL operation");
  const transaction = Object.fromEntries(SAFE_FIELDS.map(([name], i) => [name, values[i]]));
  const expectedSafeTxHash = TypedDataEncoder.hash(
    { chainId: m.chainId, verifyingContract: getAddress(safeAddress) },
    { SafeTx: SAFE_FIELDS.map(([name, type]) => ({ name, type })) }, transaction,
  );
  same(hex(p.unsigned.transactionHash, 32, true), expectedSafeTxHash, "Local Safe EIP712 hash");
  return freeze({ packetHash, phase: p.phase, kind: r.kind, anchor,
    safe: { address: safeAddress, owners, threshold, nonce }, transaction,
    inner: { to: target, value: 0n, data: data.toLowerCase(), operation: 0n }, expectedSafeTxHash,
    runtimePins, sourceCommit: m.sourceCommit, sourceReportSha256: m.sourceReportSha256,
    toolSha256: m.toolSha256, admissionHash, requestHash, originalPacket: p,
    deploymentProvenanceIndependentlyVerified: false, originalProtocolStateIndependentlyVerified: false });
}
