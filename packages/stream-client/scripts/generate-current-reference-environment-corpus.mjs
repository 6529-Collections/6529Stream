// Retain the original environment's scalar fields and hashes; reuse the exact existing file corpus.
import { createHash } from "node:crypto";
import { readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { keccak256 } from "ethers";

const ENVIRONMENT_SHA = "4177e70740caaed5cdbe727891ad485cd7e075f87c3cb3cd735a89ce6db6f452";
const CORPUS_SHA = "dccfe2fc6ca80808b9ebcb9173df238598cccff3ffb9295ea8aa0497946d0564";
const sha = raw => createHash("sha256").update(raw).digest("hex");

export function referenceEnvironmentCorpus(environmentBytes, inventoryCorpus) {
  if (sha(environmentBytes) !== ENVIRONMENT_SHA || environmentBytes.length !== 179418
    || inventoryCorpus.sourceEnvironmentSha256 !== ENVIRONMENT_SHA || inventoryCorpus.sourceFixtureSha256 !== CORPUS_SHA) {
    throw Error("Expected the exact retained canonical environment and inventory corpus");
  }
  const environment = JSON.parse(environmentBytes);
  if (JSON.stringify(environment) !== environmentBytes.toString("utf8")) throw Error("Retained environment is not the exact compact canonical JSON");
  for (const name of ["packageFiles", "platformPrerequisites"]) {
    if (JSON.stringify(environment[name]) !== JSON.stringify(inventoryCorpus.inventories[name].rows)) throw Error(`Original ${name} rows differ`);
  }
  const fields = { objectHash: environment.runtimeObjectHash, manifestHash: keccak256(environmentBytes), manifestBytes: String(environmentBytes.length),
    engineName: environment.engineName, engineVersion: environment.engineVersion, engineExecutableSha256: environment.engineExecutableSha256,
    toolchainName: environment.toolchainName, toolchainVersion: environment.toolchainVersion, toolchainSha256: environment.toolchainSha256,
    engineExecutablePath: environment.engineExecutablePath, toolchainPath: environment.toolchainPath,
    operatingSystem: environment.operatingSystem, operatingSystemVersion: environment.operatingSystemVersion, architecture: environment.architecture,
    viewportWidth: environment.viewportWidth, viewportHeight: environment.viewportHeight, devicePixelRatio: environment.devicePixelRatio,
    colorSpace: environment.colorSpace, softwareRasterization: environment.softwareRasterization,
    captureProfile: environment.captureProfile, licenseNote: environment.licenseNote };
  return { schemaVersion: 1, sourceEnvironmentSha256: ENVIRONMENT_SHA, sourceFixtureSha256: CORPUS_SHA,
    canonicalByteLength: environmentBytes.length, canonicalKeccak256: fields.manifestHash,
    inventoriesFixture: "current-reference-inventory-corpus.json",
    qualification: "Exact scalar fields and canonical hashes from the retained 1048/102-row environment. Coverage is not part of these JSON bytes and is supplied separately in client tests; no live coverage, publication, execution or gas claim.",
    fields };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [environment, mode] = process.argv.slice(2);
  if (!environment || (mode !== undefined && mode !== "--check")) throw Error("Usage: generate-current-reference-environment-corpus.mjs ENVIRONMENT [--check]");
  const inventoryCorpus = JSON.parse(await readFile(new URL("../test/fixtures/current-reference-inventory-corpus.json", import.meta.url), "utf8"));
  const canonical = JSON.stringify(referenceEnvironmentCorpus(await readFile(environment), inventoryCorpus), null, 2) + "\n";
  const target = new URL("../test/fixtures/current-reference-environment-corpus.json", import.meta.url);
  if (mode === "--check") {
    if (await readFile(target, "utf8") !== canonical) throw Error("Stale reference environment corpus");
  } else await writeFile(target, canonical, "utf8");
}
