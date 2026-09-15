// Extract only selected refund surfaces from explicit compiler input/output; no retained catalog writes.
import { readFile, writeFile } from "node:fs/promises";
import { createHash } from "node:crypto";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";
const sha = v => createHash("sha256").update(v).digest("hex");
export function refundFixture(inputBytes, outputBytes) {
  const input = JSON.parse(inputBytes), output = JSON.parse(outputBytes);
  if (input.language !== "Solidity" || output.errors?.some(x => x.severity === "error")) throw Error("Expected successful compiler input/output");
  const targets = { fixed: "StreamNativeFixedPriceSaleAdapter", dutch: "StreamNativeDutchSale", clearing: "StreamNativeClearingSale", window: "StreamNativeRefundWindowSale" };
  const names = new Set(["refundDelegationConfiguration", "refundDelegationManifest", "refundDelegationManifestHash", "claimRefundFor", "claimRefund", "refundableBalance", "gasParameter"]);
  const abis = {}, sources = {};
  for (const [kind, name] of Object.entries(targets)) {
    const source = `smart-contracts/domains/mint/${name}.sol`, literal = input.sources?.[source]?.content;
    const abi = output.contracts?.[source]?.[name]?.abi;
    if (typeof literal !== "string" || !Array.isArray(abi)) throw Error("Missing selected refund compiler target");
    abis[kind] = abi.filter(x => x.type === "function" && names.has(x.name));
    if (abis[kind].length !== names.size) throw Error("Incomplete compiled refund capability");
    sources[source] = sha(literal);
  }
  return { schemaVersion: 1, qualification: "Compiler-selected refund ABI only; no deployment/runtime claim",
    inputSha256: sha(inputBytes), outputSha256: sha(outputBytes), sources, abis };
}
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [input, output, mode] = process.argv.slice(2);
  if (!input || !output || (mode !== undefined && mode !== "--check")) throw Error("Usage: generate-current-refund-fixture.mjs INPUT OUTPUT [--check]");
  const file = new URL("../test/fixtures/current-refund-abi.json", import.meta.url);
  const text = JSON.stringify(refundFixture(await readFile(input), await readFile(output)), null, 2) + "\n";
  if (mode === "--check") { if (await readFile(file, "utf8") !== text) throw Error("Stale refund ABI fixture"); }
  else await writeFile(file, text, "utf8");
}
