// Preserve the distinct integration capture that includes the concrete paid recorder.
import { createHash } from "node:crypto";
import { readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";
const INPUT_SHA = "c3e27ea0432cbb0548eb191e23243e06f597332045c0f6d96b604f88fc3be159";
const OUTPUT_SHA = "70092a7c16deac5fff64a4e8d7a89b2429d988e556387cbe3263e78f3d38c307";
const sources = {
  "smart-contracts/domains/revenue/StreamPrimarySaleSettlement.sol": "12607affd0163d0f6638a2cf1613bc5e072a43ef56db4dbfb3fe05165f29a9d9",
  "smart-contracts/domains/revenue/StreamSettlementContext.sol": "69184dc59110de732c9a117edf43559423a4e325e1f4c4311f7a2b9fc7026f08",
};
const sha = value => createHash("sha256").update(value).digest("hex");
export function mintFallbackRecorderFixture(inputBytes, outputBytes) {
  if (sha(inputBytes) !== INPUT_SHA || sha(outputBytes) !== OUTPUT_SHA) throw Error("Expected exact integration ABI43 recorder capture");
  const input = JSON.parse(inputBytes), output = JSON.parse(outputBytes);
  if (Object.keys(input.sources ?? {}).length !== 2138 || output.errors?.some(row => row.severity === "error")) throw Error("Expected clean 2138-source capture");
  for (const [path, expected] of Object.entries(sources)) {
    if (typeof input.sources[path]?.content !== "string" || sha(input.sources[path].content) !== expected) throw Error(`Recorder source changed: ${path}`);
  }
  const source = "smart-contracts/domains/revenue/StreamPrimarySaleSettlement.sol", contract = "StreamPrimarySaleSettlement";
  const methods = ["core", "coreCodeHash", "moduleRegistry", "moduleRegistryCodeHash", "supportsInterface"];
  const abi = output.contracts?.[source]?.[contract]?.abi.filter(row => row.type === "function" && methods.includes(row.name));
  if (!abi || abi.length !== methods.length || methods.some(name => abi.filter(row => row.name === name).length !== 1)) throw Error("Incomplete recorder ABI");
  return { schemaVersion: 1, capture: "parallel-feature-batch43-20260920", sourceCheckpoint: "23e45d78", sourceCount: 2138,
    inputSha256: INPUT_SHA, outputSha256: OUTPUT_SHA, sources,
    sourceBinding: "The concrete recorder and its getter-bearing base source are byte-identical to d1a58e4403cfbb80d921e117e0a7ac9b90ff61c7 Git blobs. This is a separate integrated compiler capture; other sources are not asserted identical.",
    qualification: "Selected concrete recorder getters only; no runtime, lifecycle, paid-genesis or release acceptance.",
    source, contract, abi };
}
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [input, output, mode] = process.argv.slice(2);
  if (!input || !output || (mode !== undefined && mode !== "--check")) throw Error("Usage: generate-current-mint-fallback-recorder-fixture.mjs INPUT OUTPUT [--check]");
  const canonical = JSON.stringify(mintFallbackRecorderFixture(await readFile(input), await readFile(output)), null, 2) + "\n";
  const target = new URL("../test/fixtures/current-mint-fallback-recorder-abi.json", import.meta.url);
  if (mode === "--check") {
    if (await readFile(target, "utf8") !== canonical) throw Error("Stale fallback recorder ABI fixture");
  } else await writeFile(target, canonical, "utf8");
}
