// Project exact retained native file declarations; never extract or execute their files.
import { createHash } from "node:crypto";
import { readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { AbiCoder } from "ethers";

const CORPUS_SHA = "dccfe2fc6ca80808b9ebcb9173df238598cccff3ffb9295ea8aa0497946d0564";
const ENVIRONMENT_SHA = "4177e70740caaed5cdbe727891ad485cd7e075f87c3cb3cd735a89ce6db6f452";
const ROWS = "tuple(string path,uint64 byteSize,bytes32 sha256Digest)[]";
const coder = AbiCoder.defaultAbiCoder();
const sha = raw => createHash("sha256").update(raw).digest("hex");

export function referenceInventoryCorpus(corpusBytes, environmentBytes) {
  if (sha(corpusBytes) !== CORPUS_SHA || sha(environmentBytes) !== ENVIRONMENT_SHA) {
    throw Error("Expected the exact retained combined native corpus and environment");
  }
  const corpus = JSON.parse(corpusBytes), environment = JSON.parse(environmentBytes);
  const inventories = {};
  for (const [name, relative, count, byteLength, digest] of [
    ["packageFiles", true, 1048, 162109, "d64f896c25f56f4f8f5569fa5a409b113ab8f6070e4a322ba7259702fc16b806"],
    ["platformPrerequisites", false, 102, 15583, "053bf4e8fa4ae7af560c64c68d6fd378102bb69da659db85da04ea8f7539dce0"],
  ]) {
    const encoded = corpus[`${name}ABI`], [decoded] = coder.decode([ROWS], encoded);
    if (coder.encode([ROWS], [decoded]) !== encoded) throw Error(`Noncanonical original ${name} ABI`);
    const rows = decoded.map(row => ({ byteSize: row.byteSize.toString(), path: row.path, sha256Digest: row.sha256Digest }));
    const canonical = JSON.stringify(rows);
    if (rows.length !== count || canonical !== JSON.stringify(environment[name])
      || Buffer.byteLength(canonical) !== byteLength || sha(canonical) !== digest) {
      throw Error(`Original ABI and canonical environment ${name} differ`);
    }
    inventories[name] = { relative, rowCount: count, byteLength, canonicalSha256: digest, rows };
  }
  return { schemaVersion: 1, sourceFixtureCommit: "9cb5a32af45779f018f9b56f7ee0e57af4c6358a",
    sourceFixtureSha256: CORPUS_SHA, sourceEnvironmentSha256: ENVIRONMENT_SHA,
    qualification: "Genuine combined native runtime declarations and exact canonical environment arrays; typed test boundaries, not an RPC anchor, full dossier capture or execution/gas acceptance.",
    inventories };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [corpus, environment, mode] = process.argv.slice(2);
  if (!corpus || !environment || (mode !== undefined && mode !== "--check")) {
    throw Error("Usage: generate-current-reference-inventory-corpus.mjs CORPUS ENVIRONMENT [--check]");
  }
  const canonical = JSON.stringify(referenceInventoryCorpus(await readFile(corpus), await readFile(environment)), null, 2) + "\n";
  const target = new URL("../test/fixtures/current-reference-inventory-corpus.json", import.meta.url);
  if (mode === "--check") {
    if (await readFile(target, "utf8") !== canonical) throw Error("Stale reference inventory corpus");
  } else await writeFile(target, canonical, "utf8");
}
