import test from "node:test";
import assert from "node:assert/strict";
import { AbiCoder, ZeroAddress, ZeroHash, getBytes, hexlify, id, keccak256, toUtf8Bytes, toUtf8String } from "ethers";
import {
  REFERENCE_INVENTORY_MAX_BYTES, REFERENCE_INVENTORY_PART_ROWS,
  normalizeReferenceInventoryRows, prepareReferenceInventory, referenceInventoryCanonicalBytes,
  referenceInventoryContentHash, referenceInventoryId, referenceInventoryPartId, referenceInventoryParts,
} from "../dist/current-reference-inventory.js";

const coder = AbiCoder.defaultAbiCoder();
const chain = (1n << 200n) + 31337n;
const host = "0x0000000000000000000000000000000000000011";
const otherHost = "0x0000000000000000000000000000000000000012";
const digest = `0x${"ab".repeat(32)}`;
const row = (path, byteSize = 0n, sha256Digest = digest) => ({ path, byteSize, sha256Digest });
const rows = count => Array.from({ length: count }, (_, i) => row(`${i.toString().padStart(4, "0")}/file.bin`, BigInt(i)));
const json = input => JSON.stringify(input.map(r => ({ byteSize: r.byteSize.toString(), path: r.path, sha256Digest: r.sha256Digest.toLowerCase() })));
const literalId = (input, relative, domain = "6529STREAM_REFERENCE_FILE_INVENTORY_V1", chainId = chain, publicationHost = host) => keccak256(coder.encode(
  ["bytes32", "uint256", "address", "bool", "tuple(string path,uint64 byteSize,bytes32 sha256Digest)[]"],
  [id(domain), chainId, publicationHost, relative, input],
));

test("original identity binds chain, actual publication host, mode and exact ABI rows independently from content", () => {
  const input = [row("a", 0n, `0x${"AB".repeat(32)}`), row("z", (1n << 64n) - 1n)];
  const expected = `[{"byteSize":"0","path":"a","sha256Digest":"${digest}"},{"byteSize":"18446744073709551615","path":"z","sha256Digest":"${digest}"}]`;
  const saved = prepareReferenceInventory(chain, host, true, input);
  assert.equal(toUtf8String(saved.canonical), expected);
  assert.equal(saved.byteLength, BigInt(Buffer.byteLength(expected)));
  assert.equal(saved.inventoryId, literalId(input, true));
  assert.equal(saved.contentHash, keccak256(toUtf8Bytes(expected)));
  assert.equal(referenceInventoryContentHash(input, true), saved.contentHash);
  assert.equal(referenceInventoryId(chain, host, true, input), saved.inventoryId);
  assert.notEqual(saved.inventoryId, saved.contentHash);
  for (const changed of [prepareReferenceInventory(chain + 1n, host, true, input),
    prepareReferenceInventory(chain, otherHost, true, input), prepareReferenceInventory(chain, host, false, input)]) {
    assert.notEqual(changed.inventoryId, saved.inventoryId);
    assert.equal(changed.contentHash, saved.contentHash);
  }
  assert.notEqual(referenceInventoryId(chain, host, true, [row("a", 1n), input[1]]), saved.inventoryId);
  assert.notEqual(referenceInventoryId(chain, host, true, [row("a", 0n, id("other file")), input[1]]), saved.inventoryId);
});

test("empty monolithic inventories and zero-byte files retain their original semantics", () => {
  for (const relative of [true, false]) {
    const saved = prepareReferenceInventory(chain, host, relative, []);
    assert.equal(saved.canonical, "0x5b5d");
    assert.equal(saved.byteLength, 2n);
    assert.equal(saved.inventoryId, literalId([], relative));
    assert.deepEqual(referenceInventoryParts(saved), []);
    assert.throws(() => referenceInventoryPartId(chain, host, relative, []), /1\.\.64/);
  }
  // The contract does not require the SHA-256 of empty bytes when byteSize is zero.
  assert.equal(prepareReferenceInventory(chain, host, true, [row("empty", 0n, id("any nonzero digest"))]).rows[0].byteSize, 0n);
});

test("platform JSON matches renderer control escaping and preserves Unicode and literal slashes", () => {
  const controls = String.fromCharCode(...Array.from({ length: 32 }, (_, i) => i));
  const path = `${controls}"\\/é\u2028\u2029\u{10000}`;
  const input = [row(path)];
  const canonical = referenceInventoryCanonicalBytes(input, false);
  assert.equal(toUtf8String(canonical), json(input));
  const decoded = toUtf8String(canonical);
  assert.ok(decoded.includes("\\u0000\\u0001\\u0002"));
  assert.ok(decoded.includes("\\b\\t\\n\\u000b\\f\\r"));
  assert.ok(decoded.includes('\\"\\\\/é\u2028\u2029\u{10000}'));
  assert.equal(JSON.parse(decoded)[0].path, path);
  assert.equal(referenceInventoryContentHash(input, false), keccak256(toUtf8Bytes(json(input))));
});

test("ordering is strict UTF-8 bytes across prefixes, word boundaries and Unicode planes", () => {
  const paths = ["a", "aa", "x".repeat(31), `${"x".repeat(31)}a`, `${"x".repeat(31)}b`, "é", "\uE000", "\u{10000}"];
  assert.ok("\u{10000}" < "\uE000", "UTF-16 order deliberately differs from UTF-8 order");
  assert.deepEqual(normalizeReferenceInventoryRows(paths.map(p => row(p)), false).map(r => r.path), paths);
  assert.throws(() => normalizeReferenceInventoryRows([row("\u{10000}"), row("\uE000")], false), /UTF-8 byte order/);
  for (const bad of [[row("a"), row("a")], [row("aa"), row("a")], [row(`${"x".repeat(32)}b`), row(`${"x".repeat(32)}a`)]]) {
    assert.throws(() => normalizeReferenceInventoryRows(bad, false), /strictly increasing/);
  }
  const unicode = [row("e\u0301"), row("é")];
  assert.deepEqual(normalizeReferenceInventoryRows(unicode, false), unicode, "distinct normalization forms are preserved");
});

test("relative paths use the contract ASCII segment rules without extra filesystem restrictions", () => {
  const allowed = [" leading/file", "CON", "a%20b", "a..b/c", "a".repeat(1024)];
  for (const path of allowed) assert.equal(normalizeReferenceInventoryRows([row(path)], true)[0].path, path);
  const forbidden = ["", "/a", "a/", "a//b", ".", "..", "a/.", "a/..", "a.", "a ", "a./b", "a /b",
    "a\\b", "a:b", "a<b", "a>b", 'a"b', "a|b", "a?b", "a*b", "a\u001fb", "a\u007fb", "é", "a".repeat(1025)];
  for (const path of forbidden) assert.throws(() => normalizeReferenceInventoryRows([row(path)], true), undefined, JSON.stringify(path));
});

test("platform path width counts UTF-8 bytes and rejects malformed scalar strings", () => {
  for (const path of ["é".repeat(1024), "\u{10000}".repeat(512), "\u0000", "/a\\b:"]) {
    assert.equal(normalizeReferenceInventoryRows([row(path)], false)[0].path, path);
  }
  for (const path of ["", "é".repeat(1024) + "a", "\u{10000}".repeat(513), "\uD800", "\uDC00", "x\uD800y"]) {
    assert.throws(() => normalizeReferenceInventoryRows([row(path)], false));
  }
});

test("row widths, coordinates and exact schema reject lossy or ambiguous inputs", () => {
  for (const size of [-1n, 1n << 64n, 0, Number.MAX_SAFE_INTEGER, "0", null]) {
    assert.throws(() => normalizeReferenceInventoryRows([row("a", size)], true), /uint64 bigint/);
  }
  for (const hash of [ZeroHash, "0x", "0x01", `0x${"ab".repeat(33)}`, `0x${"zz".repeat(32)}`, null]) {
    assert.throws(() => normalizeReferenceInventoryRows([row("a", 0n, hash)], true), /nonzero bytes32/);
  }
  for (const bad of [null, [], { path: "a", byteSize: 0n }, { ...row("a"), extra: true }, { ...row("a"), path: 7 }]) {
    assert.throws(() => normalizeReferenceInventoryRows([bad], true));
  }
  for (const bad of [undefined, null, {}, "[]"]) assert.throws(() => normalizeReferenceInventoryRows(bad, true), /array/);
  assert.throws(() => normalizeReferenceInventoryRows([], "true"), /boolean/);
  for (const bad of [0n, -1n, 1n << 256n, 31337]) assert.throws(() => prepareReferenceInventory(bad, host, true, []), /uint256 bigint/);
  for (const bad of [ZeroAddress, "host", null]) assert.throws(() => prepareReferenceInventory(chain, bad, true, []));
});

test("review snapshots and parts are deeply copied and frozen before asynchronous use", async () => {
  const input = rows(65), original = structuredClone(input);
  const saved = prepareReferenceInventory(chain, host, true, input);
  const parts = referenceInventoryParts(saved);
  await Promise.resolve();
  input[0].path = "changed"; input[1].byteSize = 99n; input[2].sha256Digest = id("changed"); input.push(row("z"));
  assert.deepEqual(saved.rows, original);
  assert.deepEqual(parts.flatMap(p => p.rows), original);
  assert.equal(saved.inventoryId, literalId(original, true));
  for (const object of [saved, saved.rows, ...saved.rows, parts, ...parts, ...parts.map(p => p.rows), ...parts.flatMap(p => p.rows)]) {
    assert.equal(Object.isFrozen(object), true);
  }
  assert.throws(() => { saved.rows[0].path = "changed"; }, TypeError);
  assert.throws(() => parts.push(parts[0]), TypeError);
  assert.throws(() => { parts[0].rowOffset = 1; }, TypeError);
});

test("actual retained-byte bound includes the closing bracket despite the serializer prefix quirk", () => {
  const input = Array.from({ length: 256 }, (_, i) => row(`${i.toString().padStart(4, "0")}/`));
  let remaining = REFERENCE_INVENTORY_MAX_BYTES - Buffer.byteLength(json(input));
  for (const entry of input) {
    const padding = Math.min(2048 - entry.path.length, remaining);
    entry.path += "a".repeat(padding); remaining -= padding;
  }
  assert.equal(remaining, 0);
  assert.equal(Buffer.byteLength(json(input)), 524288);
  const saved = prepareReferenceInventory(chain, host, false, input);
  assert.equal(saved.byteLength, 524288n);
  assert.equal(getBytes(saved.canonical).length, 524288);
  assert.equal(saved.contentHash, keccak256(toUtf8Bytes(json(input))));
  const tooLarge = structuredClone(input);
  tooLarge.at(-1).path += "a";
  assert.equal(Buffer.byteLength(json(tooLarge)), 524289);
  assert.throws(() => prepareReferenceInventory(chain, host, false, tooLarge), /524288-byte retention limit/);
});

test("staging uses consecutive 64-row groups and the independently encoded disjoint part domain", () => {
  assert.equal(REFERENCE_INVENTORY_PART_ROWS, 64);
  for (const count of [0, 1, 64, 65, 128, 129]) {
    const input = rows(count), saved = prepareReferenceInventory(chain, host, true, input), parts = referenceInventoryParts(saved);
    assert.equal(parts.length, Math.ceil(count / 64));
    assert.deepEqual(parts.flatMap(p => p.rows), input);
    for (const [i, part] of parts.entries()) {
      const expected = input.slice(i * 64, (i + 1) * 64);
      assert.equal(part.index, i); assert.equal(part.rowOffset, i * 64);
      assert.equal(part.rows.length, Math.min(64, count - i * 64));
      assert.equal(part.canonical, hexlify(toUtf8Bytes(json(expected))));
      assert.equal(part.byteLength, BigInt(Buffer.byteLength(json(expected))));
      assert.equal(part.contentHash, keccak256(part.canonical));
      assert.equal(part.partId, literalId(expected, true, "6529STREAM_REFERENCE_FILE_INVENTORY_PART_V1"));
      assert.equal(part.partId, referenceInventoryPartId(chain, host, true, expected));
      assert.notEqual(part.partId, referenceInventoryId(chain, host, true, expected));
    }
    const assembled = `[${parts.map(p => toUtf8String(p.canonical).slice(1, -1)).join(",")}]`;
    assert.equal(assembled, toUtf8String(saved.canonical));
    assert.equal(saved.inventoryId, literalId(input, true));
  }
  assert.throws(() => referenceInventoryPartId(chain, host, true, rows(65)), /1\.\.64/);
  const input = rows(1), partId = referenceInventoryPartId(chain, host, true, input);
  assert.notEqual(referenceInventoryPartId(chain + 1n, host, true, input), partId);
  assert.notEqual(referenceInventoryPartId(chain, otherHost, true, input), partId);
  assert.notEqual(referenceInventoryPartId(chain, host, false, input), partId);
});

test("global ordering is validated before grouping, including duplicates or inversions at row 64", () => {
  for (const boundary of ["0063/file.bin", "0000/file.bin"]) {
    const input = rows(65); input[64].path = boundary;
    assert.throws(() => prepareReferenceInventory(chain, host, true, input), /strictly increasing/);
    const valid = prepareReferenceInventory(chain, host, true, rows(65));
    assert.throws(() => referenceInventoryParts({ ...valid, rows: input }), /strictly increasing/);
  }
});

test("partitioning reconstructs snapshot labels and rejects caller-selected identities or stale rows", () => {
  const saved = prepareReferenceInventory(chain, host, true, rows(65));
  for (const changed of [{ ...saved, canonical: "0x5b5d" }, { ...saved, contentHash: id("forged") },
    { ...saved, inventoryId: id("forged") }, { ...saved, byteLength: saved.byteLength + 1n },
    { ...saved, byteLength: Number(saved.byteLength) }, { ...saved, chainId: chain + 1n },
    { ...saved, publicationHost: otherHost }, { ...saved, relative: false },
    { ...saved, rows: rows(64) }, { ...saved, partIds: [] }, { ...saved, count: 2 }]) {
    assert.throws(() => referenceInventoryParts(changed));
  }
  const missing = { ...saved }; delete missing.canonical;
  assert.throws(() => referenceInventoryParts(missing), /missing or unknown/);
  assert.throws(() => referenceInventoryParts(null), /missing or unknown/);
  // Caller-owned valid snapshots are revalidated and copied, rather than trusted by object identity.
  const plain = structuredClone(saved), parts = referenceInventoryParts(plain);
  plain.rows[0].path = "changed";
  assert.equal(parts[0].rows[0].path, saved.rows[0].path);
});
