// Extract only the current Artist replay reads from explicit compiler input/output.
import { createHash } from "node:crypto";
import { readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

const source = "smart-contracts/domains/artist/StreamArtistOnboardingRegistry.sol";
const contract = "StreamArtistOnboardingRegistry";
const methods = ["artistAuthorizationState", "collaboratorRegistrationNonceState"];
const sha = value => createHash("sha256").update(value).digest("hex");

export function artistCeremonyFixture(inputBytes, outputBytes, sourceCommit) {
  if (typeof sourceCommit !== "string" || !/^[0-9a-f]{8,40}$/.test(sourceCommit)) throw Error("Expected lowercase source commit");
  const input = JSON.parse(inputBytes), output = JSON.parse(outputBytes);
  if (input.language !== "Solidity" || output.errors?.some(item => item.severity === "error")) throw Error("Expected successful Solidity compiler input/output");
  const literal = input.sources?.[source]?.content, fullAbi = output.contracts?.[source]?.[contract]?.abi;
  if (typeof literal !== "string" || !Array.isArray(fullAbi)) throw Error("Missing current Artist compiler target");
  const abi = fullAbi.filter(item => item.type === "function" && methods.includes(item.name));
  if (abi.length !== methods.length || methods.some((name, index) => abi[index]?.name !== name)) throw Error("Incomplete or reordered current Artist replay reads");
  return {
    source,
    sourceCommit,
    compilerVersion: "0.8.19",
    scope: "Selected current Artist authorization-state reads; no runtime or write-path acceptance",
    provenance: { sourceSha256: sha(literal), compilerInputSha256: sha(inputBytes), compilerOutputSha256: sha(outputBytes) },
    abi,
  };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [input, output, sourceCommit, mode] = process.argv.slice(2);
  if (!input || !output || !sourceCommit || (mode !== undefined && mode !== "--check")) {
    throw Error("Usage: generate-current-artist-ceremony-fixture.mjs INPUT OUTPUT SOURCE_COMMIT [--check]");
  }
  const file = new URL("../test/fixtures/current-artist-ceremony-abi.json", import.meta.url);
  const rendered = JSON.stringify(artistCeremonyFixture(await readFile(input), await readFile(output), sourceCommit), null, 2) + "\n";
  if (mode === "--check") {
    if (await readFile(file, "utf8") !== rendered) throw Error("Stale current Artist ceremony ABI fixture");
  } else await writeFile(file, rendered, "utf8");
}
