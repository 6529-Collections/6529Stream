// Extract a test fixture from an explicitly selected compiler input/output. No retained catalog writes.
import { readFile, writeFile } from "node:fs/promises";
import { createHash } from "node:crypto";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";
const sha = value => createHash("sha256").update(value).digest("hex");
export function secondaryFixture(inputBytes, outputBytes) {
  const input = JSON.parse(inputBytes), output = JSON.parse(outputBytes);
  if (input.language !== "Solidity" || output.errors?.some(x => x.severity === "error")) throw Error("Expected successful Solidity compiler input/output");
  const targets = {
    adapter: ["smart-contracts/domains/mint/StreamPrivateSaleAdapter.sol", "StreamPrivateSaleAdapter"],
    inventory: ["smart-contracts/interfaces/stream/mint/IStreamNativeInventorySale.sol", "IStreamNativeInventorySale"],
    moduleRegistry: ["smart-contracts/interfaces/stream/modules/IStreamModuleRegistry.sol", "IStreamModuleRegistry"],
  };
  const abis = {}, sources = {};
  for (const [name, [source, contract]] of Object.entries(targets)) {
    const literal = input.sources?.[source]?.content, abi = output.contracts?.[source]?.[contract]?.abi;
    if (typeof literal !== "string" || !Array.isArray(abi) || !abi.length) throw Error(`Missing selected compiler target ${name}`);
    abis[name] = abi; sources[source] = sha(literal);
  }
  const hashSource = "smart-contracts/domains/mint/StreamPrivateSaleHash.sol";
  const hashes = input.sources?.[hashSource]?.content;
  if (typeof hashes !== "string") throw Error("Missing original signing source");
  sources[hashSource] = sha(hashes);
  const types = {};
  for (const name of ["SaleAuthorization", "SaleOffer", "SaleCustodyGrant"]) {
    const found = hashes.match(new RegExp('"(' + name + '\\([^"\\n]+\\))"'));
    if (!found) throw Error(`Missing original ${name} type preimage`);
    types[name] = found[1];
  }
  const domain = hashes.match(/keccak256\("(6529Stream Sales)"\)/)?.[1];
  if (!domain) throw Error("Missing original Sales domain");
  return { schemaVersion: 1, qualification: "Explicit compiler-selected ABI and source preimages; no deployment or runtime-test claim",
    inputSha256: sha(inputBytes), outputSha256: sha(outputBytes), sources, domain, version: "1", types, abis };
}
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [input, output, mode] = process.argv.slice(2);
  if (!input || !output || (mode !== undefined && mode !== "--check")) throw Error("Usage: node scripts/generate-current-secondary-fixture.mjs INPUT_JSON OUTPUT_JSON [--check]");
  const file = new URL("../test/fixtures/current-secondary-abi.json", import.meta.url);
  const text = JSON.stringify(secondaryFixture(await readFile(input), await readFile(output)), null, 2) + "\n";
  if (mode === "--check") {
    if (await readFile(file, "utf8") !== text) throw Error("Stale secondary fixture");
  } else await writeFile(file, text, "utf8");
  console.log("Verified compiler-selected secondary ABI fixture; retained catalogs untouched.");
}
